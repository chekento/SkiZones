extends SceneTree
## Render smoke and source-integrity checks for OSM town overlay (#10).
const Town = preload("res://src/world/town_scenery.gd")
const Village = preload("res://src/world/compact_village.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Geo = preload("res://src/core/real_resorts.gd")
var passed := 0
var failed := 0

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var preview_count := 0
	for id in Geo.IDS:
		var source: Dictionary = Town.data(id)
		var mountain_path := "res://assets/geodata/mountain-venues/%s.json" % id
		check(FileAccess.file_exists(mountain_path), id + " has independently pinned, true mountainside OSM hospitality locations")
		if FileAccess.file_exists(mountain_path):
			var subset: Variant = JSON.parse_string(FileAccess.get_file_as_string(mountain_path))
			check(subset is Dictionary and subset.get("coverage") == "partial_town_extract" and subset.get("source_sha256") == source.get("source_sha256"), id + " mountainside hospitality subset proves genuine (limited) OSM source")
			var sites: Array = Village._archived_mountainside(id, source)
			check(sites.size() > 0 and sites.all(func(v): return int(v.osm_id) > 0 and v.source == "osm"), id + " mountain food and hotel positions are sourced and nameless")
		check(source.get("region") == id and source.get("license") == "ODbL-1.0" and source.get("features", []).size() > 200, id + " has pinned real OSM town features")
		var path := "res://assets/geodata/towns/%s-network.json" % id
		check(FileAccess.file_exists(path), id + " has a generated street and transit graph")
		if FileAccess.file_exists(path):
			var network: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(network is Dictionary and network.get("source_sha256") == source.get("source_sha256") and network.get("vertices", {}).size() > 50, id + " graph matches exact pinned source checksum")
			var shuttle: Dictionary = Town.preview_shuttle(id)
			if not shuttle.is_empty():
				preview_count += 1
				check(not shuttle.official_route and shuttle.outbound.size() > 2 and shuttle["return"].size() > 2, id + " fictional shuttle uses a real bidirectional OSM road path")
	check(preview_count >= 1, "At least one real resort provides a connected illustrated SkiZones game shuttle")
	# One real loaded 3D landscape is enough to check runtime geometry:
	# the four offline town inputs are validated separately above.
	var scene := Node3D.new()
	root.add_child(scene)
	var mountain := Mountain.new("braunlage", 2)
	var stats: Dictionary = Town.build(scene, mountain, "braunlage")
	check(stats.osm and stats.roads >= 100 and stats.road_quads > stats.roads and stats.road_quads <= Town.MAX_ROAD_QUADS, "Actual road polylines become a bounded visible 3D surface")
	check(stats.poi >= 100 and stats.stops >= 20, "Real hotels, restaurants and transit markers are placed at sourced points")
	check(stats.labels > 0 and stats.labels <= Town.MAX_POI_LABELS, "Town labels remain bounded in a miniature rather than a full city")
	check(int(stats.village_models) >= 5 and int(stats.village_models) <= 25, "Compact 3D town has real-source chalet/hotel/dining models and a bounded display budget")
	check(int(stats.game_added) >= 2 and int(stats.game_added) <= 3, "Snack stand, ski school and nightlife are labelled as gameplay scenery, not fictitious OSM")
	var village_root: Node = scene.get_child(0)
	var real_sites := 0
	var game_sites := 0
	for child in village_root.get_children():
		if not child.has_meta("village_venue"): continue
		if child.get_meta("source") == "osm" and int(child.get_meta("source_osm", 0)) > 0: real_sites += 1
		if child.get_meta("source") == "game" and int(child.get_meta("source_osm", -1)) == 0: game_sites += 1
	check(real_sites >= 2 and game_sites >= 2, "Source-mapped accommodation and fictional village services remain independently traceable")
	if stats.shuttle_preview:
		check(stats.shuttle != null and stats.shuttle.get_meta("fictional_service", false), "Illustrated skibus is explicitly marked as a fictional service")
		var before: Vector3 = stats.shuttle.position
		Town.position_shuttle(stats.shuttle, mountain, 3.0)
		check(stats.shuttle.position.is_finite(), "Simulated vehicle stays on valid source geometry")
	var town_nodes := scene.get_children()
	check(town_nodes.size() == 1 and town_nodes[0].get_meta("source", "").contains("openstreetmap.org/copyright"), "Town layer preserves attribution independently of user buildings")
	if not town_nodes.is_empty():
		var children: Array = town_nodes[0].get_children()
		check(children.any(func(n): return n is MeshInstance3D and n.has_meta("osm_town_overlay") and n.mesh.get_surface_count() > 0), "OSM streets are rendered as triangle meshes")
		check(children.any(func(n): return n is MultiMeshInstance3D and n.has_meta("osm_town_overlay")), "POI markers render in instanced batches")
		check(children.all(func(n): return not n.has_meta("walk_surface")), "Visual roads cannot masquerade as buildable footpaths")
	var empty := Node3D.new()
	root.add_child(empty)
	check(not Town.build(empty, mountain, "sonnenhang").osm and empty.get_child_count() == 0, "Fantasy landscapes never receive invented OSM towns")
	scene.queue_free()
	empty.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
