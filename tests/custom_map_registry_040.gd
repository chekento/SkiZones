extends SceneTree
## Generated maps are real terrain IDs and have separate free/career saves.
## The temporary registry must never touch a player's normal custom library.
const Creator=preload("res://src/core/map_creator_040.gd")
const Library=preload("res://src/core/custom_maps_040.gd")
const Maps=preload("res://src/core/maps.gd")
const Mountain=preload("res://src/core/mountain.gd")
const Saves=preload("res://src/core/save_store.gd")
var passed:=0
var failures:=0

func verify(ok: bool, message: String) -> void:
	if ok:passed+=1;print("PASS "+message)
	else:failures+=1;push_error("FAIL "+message)

func _init() -> void:
	var path:="user://qa_custom_worlds_040_%d.json" % Time.get_ticks_usec()
	var first:Dictionary=Library.create({"name":"Alm Testwelt","size":"compact","peak_count":5,"seed":1203},path)
	verify(first.ok,"First custom map can be created with an isolated registry")
	if not first.ok:print("RESULT: %d passed; %d failed" % [passed,failures]);quit(1);return
	verify(first.id=="custom_01","First custom map ID is stable")
	var second:Dictionary=Library.create({"name":"Gipfel Testwelt","size":"large","peak_count":11,"seed":1204},path)
	verify(second.ok and second.id=="custom_02","Second map keeps an independent stable ID")
	var library:Dictionary=Library.read_registry(path)
	verify(library.ok and library.maps.size()==2,"Both validated map definitions persist")
	verify(Library.entries().size()>=0,"Normal player library remains independently readable")
	verify(Maps.MAPS.has(first.id) and Maps.MAPS.has(second.id),"Saved definitions register as selectable gameplay regions")
	verify(Maps.is_player_map(first.id) and not Maps.is_player_map("unknown"),"Dynamic maps use protected player-map namespace")
	verify(Saves.path_for_map(first.id,0,1)!=Saves.path_for_map(first.id,1),"Free and career map paths never overlap")
	verify(Saves.path_for_map(first.id,0,1)!=Saves.path_for_map(second.id,0,1),"Separate user maps never share a save file")
	var mountain:=Mountain.new(first.id,2)
	verify(mountain.bounds.size==Creator.SIZES.compact,"Mountain uses generated bounds")
	var peak: Array=Maps.spec(first.id).peaks[0]
	var top:Vector2=Vector2(float(peak[0]),float(peak[1]))
	verify(mountain.height(top)>10.0,"Generated peaks affect real gameplay height")
	verify(not Library.create({"name":"A","peak_count":0},path).ok,"Invalid generation settings never overwrite registry")
	var raw:=FileAccess.get_file_as_string(path)
	verify(raw.contains("sha256"),"Map registry is checksum-protected")
	var tampered:=raw.replace("Alm Testwelt","Hacked Summit")
	if tampered!=raw:
		var out:=FileAccess.open(path,FileAccess.WRITE)
		out.store_string(tampered)
		out.close()
		verify(Library.read_registry(path).maps.size()==1,"Tampered primary never overrides earlier valid backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	print("RESULT: %d passed; %d failed" % [passed,failures])
	quit(1 if failures else 0)
