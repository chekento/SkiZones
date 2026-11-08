extends SceneTree
## A damaged primary must still be exportable byte-for-byte with a good .bak.
const Saves = preload("res://src/core/save_store.gd")
const Bundle = preload("res://src/core/save_bundle_040.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var slot := 4
	var path := Saves.path_for_map("sonnenhang", slot)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var model := Resort.new()
	model.new_game(false)
	model.campaign.mode = "career"
	check(Saves.save_game(model, path).ok, "Support export test stores a real, restorable career")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) == OK, "Existing backup can be inspected without changes")
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{\"broken\":"); bad.close()
	var original_hash := FileAccess.get_sha256(path)
	var backup_hash := FileAccess.get_sha256(path + ".bak")
	var bundle := Bundle.export_slot("sonnenhang", slot)
	check(bundle.ok, "Broken JSON with a healthy backup remains exportable")
	if bundle.ok:
		var zip := ZIPReader.new()
		check(zip.open(bundle.path) == OK, "Support bundle is a valid ZIP file")
		var listing: PackedStringArray = zip.get_files()
		check(listing.has("diagnostic.json") and listing.has("files/00-" + path.get_file()) and listing.has("files/01-" + (path + ".bak").get_file()), "Both exact originals and diagnostic report are packaged")
		var report: Variant = JSON.parse_string(zip.read_file("diagnostic.json").get_string_from_utf8())
		check(report is Dictionary and report.files.size() >= 2 and report.files[0].code == "invalid_json", "Export identifies malformed JSON without including save content in diagnostic JSON")
		check(zip.read_file("files/00-" + path.get_file()).get_string_from_utf8() == "{\"broken\":", "Damaged original is exported without interpretation or repair")
		zip.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(bundle.path)))
	check(FileAccess.get_sha256(path) == original_hash and FileAccess.get_sha256(path + ".bak") == backup_hash, "Export does not alter either damaged primary or the only good backup")
	# A broken backup must not silently disappear during an unrelated save.
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(path+".bak"),ProjectSettings.globalize_path(path))==OK,"Restore a valid primary only inside isolated test fixture")
	var previous_good_hash:String=FileAccess.get_sha256(path)
	var broken_backup:=FileAccess.open(path+".bak",FileAccess.WRITE)
	broken_backup.store_string("{bad backup");broken_backup.close()
	var bad_backup_hash:String=FileAccess.get_sha256(path+".bak")
	model.money+=11
	check(Saves.save_game(model,path).ok,"Normal save tolerates and archives an unreadable older backup")
	check(FileAccess.get_sha256(path+".bak")==previous_good_hash,"Rotated backup contains the fully validated previous primary")
	var found_broken:=false
	var recovery:DirAccess=DirAccess.open("user://save-recovery")
	if recovery!=null:
		for filename in recovery.get_files():
			if filename.begins_with((path+".bak").get_file()+"-") and filename.ends_with(".before-backup"):
				found_broken=found_broken or FileAccess.get_sha256("user://save-recovery/"+filename)==bad_backup_hash
	check(found_broken,"Unrecoverable former backup is separately archived byte-for-byte")
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
