extends SceneTree
## v0.34.2 regressions: sandbox, historical JSON, older piste network.
## All fixtures use an isolated, disposable user data directory.
const Resort = preload("res://src/core/resort.gd")
const Progression = preload("res://src/core/progression.gd")
const Saves = preload("res://src/core/save_store.gd")
const Traffic = preload("res://src/core/guest_traffic.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error("FAIL "+label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Only disposable skizones-test homes are allowed.")
		quit(1)
		return
	var sandbox := Resort.new()
	sandbox.new_game(false,20261105,"sonnenhang")
	check(sandbox.campaign.mode=="free" and sandbox.money==Resort.FREE_CASH,"New free resort has finite JSON-safe unlimited budget")
	var cash: float=sandbox.money
	check(sandbox._spend(700000000.0) and sandbox.money==cash,"Construction costs never consume free-play cash")
	check(Progression.RESEARCH.keys().all(func(id):return Progression.access_message(sandbox,"hotel",false)==""),"Free build skips research construction gates without applying career revenue bonuses")
	check(Progression.access_message(sandbox,"grand_hotel",false)=="","Free-play hotels are never research locked")
	check(Progression.access_message(sandbox,"gondola",true)=="","Free-play gondolas are never research locked")
	sandbox.money=0.0 # older free-play slot with empty wallet
	sandbox.advance_minute(false)
	check(sandbox.money==Resort.FREE_CASH,"Legacy free-build saves regain unlimited budget during gameplay")
	var sandbox_snapshot: Dictionary=JSON.parse_string(JSON.stringify(sandbox.snapshot()))
	var sandbox_loaded := Resort.new()
	check(sandbox_loaded.restore(sandbox_snapshot).ok and sandbox_loaded.campaign.mode=="free","Free-mode state and large finite balance survive JSON save/restore")
	var starter := Resort.new()
	starter.new_game(true,20261105,"sonnenhang")
	check(starter.pistes.size()>0 and starter.lifts.size()>0,"Existing saved starter has old lift and slope")
	var old_piste: Dictionary=starter.pistes[0]
	var old_start: Vector2=Terrain.unpack(old_piste.points[0])
	var near_miss: Dictionary=old_piste.duplicate(true)
	near_miss.id=starter.next_id
	near_miss.number=old_piste.number+1
	near_miss.name="Historische Piste mit ungenauem Anschluss"
	near_miss.points[0]=Terrain.pack(old_start+Vector2(4.9,0))
	starter.next_id += 1
	starter.pistes.append(near_miss)
	starter._invalidate()
	var graph: Dictionary=starter._geometry_graph(2)
	var old_node: String="p%ds" % int(old_piste.id)
	var new_node: String="p%ds" % int(near_miss.id)
	var connected: bool=graph.edges[old_node].any(func(edge):return edge.kind=="walk" and str(edge.to)==new_node)
	check(connected,"Older 4.9m-rounded piste endpoints receive a real walk connection")
	check(graph.edges[new_node].any(func(edge):return edge.kind=="walk" and str(edge.to)==old_node),"Legacy connector can be walked in both directions")
	check(Traffic.lane_count({"width":20.0})==4,"Standard 20m ski slopes support four overtaking lanes")
	check(Traffic.lane_count({"width":36.0})==8,"Broad 36m slopes support eight independent snow lanes")
	# Read unwrapped pre-checksum JSON without replacing or rewriting the original.
	var raw_path: String="user://skizones-test-raw-v1-0342.json"
	var old: Dictionary=sandbox_snapshot.duplicate(true)
	old.version=1
	old.money=87500.0
	old.erase("campaign")
	var raw: String=JSON.stringify(old,"",true,true)
	var file: FileAccess=FileAccess.open(raw_path,FileAccess.WRITE)
	check(file!=null,"Legacy fixture is written to an isolated test directory")
	if file != null:
		file.store_string(raw)
		file.close()
		var sha: String=FileAccess.get_sha256(raw_path)
		var read: Dictionary=Saves._read(raw_path)
		check(read.ok and read.get("legacy_raw",false) and int(read.data.version)==1,"Raw pre-checksum v1 format is identified")
		var resumed := Resort.new()
		var result: Dictionary=Saves.load_game(resumed,raw_path)
		check(result.ok and resumed.day==int(old.day) and is_equal_approx(resumed.money,87500.0),"Old raw resort opens without losing budget or day")
		check(FileAccess.get_sha256(raw_path)==sha,"Rescue never edits the source of a pre-checksum save")
		var modern: Dictionary=old.duplicate(true)
		modern.version=16
		var modern_path: String="user://skizones-test-unsigned-v16-0342.json"
		var modern_file: FileAccess=FileAccess.open(modern_path,FileAccess.WRITE)
		modern_file.store_string(JSON.stringify(modern))
		modern_file.close()
		check(not Saves._read(modern_path).ok,"Current modern raw JSON cannot bypass the checksum envelope")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(modern_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(raw_path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
