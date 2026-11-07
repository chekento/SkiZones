extends SceneTree
## Regression for the player's "2 checksum-verified, 0 loadable" incident:
## a broken-but-checksummed primary must never erase the last good backup.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
var passed:=0
var failed:=0

func _init() -> void: call_deferred("run")

func check(ok:bool,title:String) -> void:
	if ok: passed+=1;print("PASS ",title)
	else: failed+=1;push_error("FAIL "+title)

func write_envelope(path:String,data:Dictionary) -> void:
	var payload:String=JSON.stringify(data,"",true,true)
	var f:FileAccess=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text(),"payload":payload}))
	f.close()

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-0391-backup-guard"):
		push_error("Refusing to write to a non-test save directory")
		quit(1);return
	var path:String=Saves.path_for_map("sonnenhang",3)
	var world:=Resort.new()
	world.new_game(true,20261107,"sonnenhang")
	for target in [path,path+".bak"]:
		if FileAccess.file_exists(target):DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	check(Saves.save_game(world,path).ok,"Save the original playable resort")
	var first_hash:String=FileAccess.get_sha256(path)
	world.day=3
	check(Saves.save_game(world,path).ok,"A second playable save succeeds")
	check(FileAccess.file_exists(path+".bak") and FileAccess.get_sha256(path+".bak")==first_hash,"Backup contains the preceding playable checkpoint")
	var safe_backup:String=FileAccess.get_sha256(path+".bak")
	var damaged:Dictionary=world.snapshot().duplicate(true)
	check(not damaged.pistes.is_empty(),"Fixture has persistent authored pistes")
	if damaged.pistes.is_empty():
		print("RESULT: %d passed; %d failed" % [passed,failed])
		quit(1);return
	damaged.pistes[0].points[0]=[99999999,99999999]
	write_envelope(path,damaged)
	var invalid_hash:String=FileAccess.get_sha256(path)
	var readable:Dictionary=Saves._read(path)
	var exact:=Resort.new()
	check(readable.ok and not exact.restore(readable.data.duplicate(true)).ok,"Broken primary has a valid checksum but cannot restore")
	# The actual previous implementation overwrote .bak with this invalid
	# primary solely because Saves._read(path).ok was true.
	check(Saves.save_game(world,path).ok,"Normal next save succeeds despite existing unloadable primary")
	check(FileAccess.get_sha256(path+".bak")==safe_backup,"LAST GOOD backup is byte-exact and never overwritten by broken primary")
	var recovered:=Resort.new()
	check(Saves.load_game(recovered,path).ok and recovered.day==world.day,"New primary still loads normally")
	var folder:DirAccess=DirAccess.open("user://save-recovery")
	var archived:=false
	if folder!=null:
		for file in folder.get_files():
			if file.begins_with(path.get_file()+"-") and file.ends_with(".broken"):
				if FileAccess.get_sha256("user://save-recovery/"+file)==invalid_hash:archived=true
	check(archived,"Checksum-valid yet unloadable original archived byte-for-byte")
	var before:String=FileAccess.get_sha256(path)
	world.day=4
	check(Saves.save_game(world,path).ok,"Normal next valid checkpoint still saves")
	check(FileAccess.get_sha256(path+".bak")==before,"Valid previous primary safely becomes new backup")
	var intact:=Resort.new()
	check(Saves.load_game(intact,path+".bak").ok and intact.day==3,"Backup after rotation is a semantically playable resort")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
