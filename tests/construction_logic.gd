extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
var passed := 0
var failed := 0
class Gentle extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float: return 300 - point.y * 0.10
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func fresh() -> RefCounted:
	var model := Resort.new()
	model.new_game(false)
	model.terrain = Gentle.new()
	model.money = 3000000
	return model
func _init() -> void:
	var model := fresh()
	check(not model.preview_building("repair_office", Terrain.BASE).ok, "a building must never block the valley arrival point")
	check(model.build_building("kiosk", Vector2(100, 300), 2).ok, "place an attached kiosk")
	check(model.preview_building("kiosk", Vector2(128, 300), 2).ok, "compact sites use actual walls and entrances rather than an arbitrary centre distance")
	check(not model.preview_building("hotel", model.terrain.bounds.end - Vector2(5, 5)).ok, "the entire footprint and entrance must fit in the map")
	var funds: float = model.money
	var count: int = model.buildings.size()
	var site: Dictionary = model.suggest_building("kiosk", Vector2(100, 300))
	check(site.ok and Terrain.unpack(site.point).distance_to(Vector2(100, 300)) <= 48.1, "a blocked tap produces a nearby valid alternative")
	check(model.money == funds and model.buildings.size() == count, "site suggestions do not spend money or move live assets")
	if site.ok:
		check(model.preview_building("kiosk", Terrain.unpack(site.point), int(site.rotation)).ok, "the suggested orientation has a usable entrance")
	check(model.build_walkway([[185,230],[185,420]]).ok, "build a long village footpath")
	check(not model.preview_building("restaurant", Vector2(185, 360)).ok, "buildings cannot erase a manually built footpath")
	var blocked: Dictionary = model.suggest_building("restaurant", Vector2(185,360))
	check(blocked.ok and model.preview_building("restaurant", Terrain.unpack(blocked.point), int(blocked.rotation)).ok, "the site helper finds a lot beside a protected path")
	model = fresh()
	check(model.build_walkway([[185,230],[185,420]]).ok, "first crossing road")
	check(model.build_walkway([[100,355],[270,355]]).ok, "a path that crosses an existing road can connect through its middle")
	var graph: Dictionary = model.pedestrian_graph()
	var layout: Dictionary = model.pedestrian_layout()
	var join := ""
	for key in graph.nodes:
		if str(key).begins_with("pathjoin:") and Terrain.unpack(graph.nodes[key]).distance_to(Vector2(185,355)) < 0.01: join = key
	check(join != "" and graph.edges[join].size() >= 4, "the geometric crossing has an actual shared graph junction")
	check(model._shortest(graph,"w%dv0" % int(model.walk_areas[1].id),"w%dv1" % int(model.walk_areas[0].id)).ok, "guests can turn between the intersecting footpaths")
	var preview: Dictionary = model.piste_connections([[100,100],[185,332]],2)
	check(preview.exit, "piste planning recognises an exit in the middle of a footpath")
	var anchor: Dictionary = model.snap_anchor(Vector2(188,332),10)
	check(not anchor.is_empty() and anchor.point.distance_to(Vector2(185,332)) < 0.01, "piste ends snap to the visible path surface")
	check(model.build_piste([[100,100],[185,332]]).ok, "a piste can end directly on a manual footpath")
	graph = model._routing_graph(2)
	check(model._shortest(graph,"p%de" % int(model.pistes[-1].id),"base").ok, "the built piste exit follows the same road graph back to the valley")
	check(model.build_walkway([[185,300],[185,450]]).ok, "an overlapping path can extend an existing road")
	graph = model.pedestrian_graph()
	check(model._shortest(graph,"w%dv1" % int(model.walk_areas[-1].id),"base").ok, "collinear road overlaps retain an actual usable connection")
	var suggestion: Dictionary = model.Planner.suggest_walk(model, [[185,230],[270,355]])
	check(suggestion.ok and Foot.gentle(model.terrain,suggestion.points) and Foot.clear_walk(suggestion.points,model.buildings,model.lifts), "walkway assistance produces a physically valid route")
	var guest := {"id": 1, "ability": 0}
	model.minute = 480
	var route := {"legs":[{"kind":"walk","minutes":600.0}]}
	check(model.route_before_lift_closure(route,guest), "a final descent or walk may finish after lift closure")
	model.new_game(true)
	check(not model.preview_building("kiosk", Foot.boarding_point(model.lifts[0], false)).ok, "a building must preserve the actual lift boarding point")
	route = {"legs":[{"kind":"walk","minutes":550.0},{"kind":"lift","id":model.lifts[0].id,"minutes":20.0}]}
	check(not model.route_before_lift_closure(route,guest), "planning rejects a lift reached after its closing time")
	print("PLANNING: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
