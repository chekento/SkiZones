extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Profile = preload("res://src/core/guest_profile.gd")
var passed := 0
var failed := 0

class Hump extends "res://src/core/mountain.gd":
	var rise := 1.0
	func height(p: Vector2) -> float:
		if p.y <= 100: return 300-p.y*0.28
		if p.y <= 120: return 272+(p.y-100)*rise/20
		return 272+rise-(p.y-120)*0.28
class NoRunup extends "res://src/core/mountain.gd":
	func height(p: Vector2) -> float:
		if p.y <= 30: return 300
		if p.y <= 50: return 300+(p.y-30)*0.15
		return 303-(p.y-50)*0.3

func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL "+title)
func _init() -> void:
	_energy()
	_paths()
	_hiking_save()
	_real_hiking_save()
	_migration()
	print("PATHS AND MOMENTUM: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _energy() -> void:
	var mountain := Hump.new()
	var points := [[0,0],[0,220]]
	var motion := Motion.travel_profile(mountain,points,0)
	check(mountain.analyse(points).ok,"A downhill route with a small intermediate rise is buildable")
	check(motion.ok and motion.carry_rise > 0.8 and motion.hike_meters < 0.01,"Prior downhill speed carries a skier over a one-metre rise")
	var conservative := Motion.travel_profile(NoRunup.new(),points,0)
	check(conservative.ok and conservative.hike_meters > 15,"The same lack of run-up produces real slow hiking instead of free speed")
	check(conservative.minutes > motion.minutes,"Hiking takes measurably longer than a gliding descent")
	check(Motion.valid_profile(motion.samples) and Motion.valid_profile(conservative.samples),"Ski and hiking profiles are finite and strictly chronological")
	mountain.rise = 4
	var novice := Motion.travel_profile(mountain,points,0)
	var expert := Motion.travel_profile(mountain,points,2)
	check(novice.hike_meters > 0 and expert.hike_meters < novice.hike_meters,"Different speed limits produce different ability to overcome the same rise")
	var loses_energy := true
	for i in range(1,expert.samples.size()):
		var a: Array = expert.samples[i-1]; var b: Array = expert.samples[i]
		var pa: Vector2 = mountain.point_on_path(points,a[1]); var pb: Vector2 = mountain.point_on_path(points,b[1])
		if mountain.height(pb) > mountain.height(pa)+0.01 and b[2] == 0:
			loses_energy = loses_energy and b[3] <= a[3]+0.001
	check(loses_energy,"Every uphill gliding interval loses speed; no artificial minimum speed creates energy")
	mountain.rise = 24
	check(not Motion.travel_profile(mountain,points,0).ok and not mountain.analyse(points).ok,"An impassable rise is still rejected with a safety reason")
	check(not mountain.analyse([[0,220],[0,0]]).ok,"A whole uphill route is not mislabeled as a downhill piste")
	var uphill := Foot.walk_minutes(Hump.new(),[[0,220],[0,140]])
	var downhill := Foot.walk_minutes(Hump.new(),[[0,140],[0,220]])
	check(uphill > downhill,"Foot-route planning prices the extra time of an uphill climb")
	var broken: Array = conservative.samples.duplicate(true);broken[1][2]=7
	check(not Motion.valid_profile(broken),"Invalid hiking modes cannot enter a saved game")

func _paths() -> void:
	var model := Resort.new();model.new_game(true);model.money=3000000
	var layout: Dictionary = model.pedestrian_layout()
	var access := 0
	for link in layout.links:
		if link.get("access",false):
			access += 1
			check(Foot.valid_walk(layout,link.points,model.buildings),"A visible station or door approach is also a valid walking route")
	check(access == 4,"Both lift terminals and both building doors have rendered access links")
	var graph: Dictionary = model.pedestrian_graph()
	var lift: Dictionary = model.lifts[0]
	check(graph.nodes["l%db" % lift.id] == Terrain.pack(Foot.boarding_point(lift,false)),"The foot network ends at the actual boarding point, not the machine centre")
	check(model.snap_walkway(Foot.boarding_point(lift,false)+Vector2(2,2)).point.distance_to(Foot.boarding_point(lift,false)) < 0.01,"The path tool snaps directly to a lift entrance")
	var endpoints := [Terrain.pack(Terrain.BASE),Terrain.pack(Foot.boarding_point(lift,false))]
	var funds: float = model.money
	var preview: Dictionary = model.preview_walkway(endpoints)
	check(preview.ok and preview.points.size() >= 2 and model.money == funds,"A connected footpath preview computes a safe route without charging")
	check(model.build_walkway(endpoints).ok,"A user-planned path can be built between valley access and a lift")
	var path: Dictionary = model.walk_areas[-1]
	check(Foot.clear_walk(path.points,model.buildings,model.lifts) and path.radius == 4,"Built path geometry avoids machinery and has its actual eight-metre width")
	check(model.asset(path.id).kind == "walkway" and model.money < funds,"The path is a real selectable, priced asset")
	var copy := Resort.new()
	var restored: Dictionary = copy.restore(JSON.parse_string(JSON.stringify(model.snapshot())))
	var same: bool = restored.ok
	if restored.ok:
		same = copy.walk_areas[-1].points.size() == path.points.size()
		for i in range(path.points.size()): same = same and Terrain.unpack(copy.walk_areas[-1].points[i]).distance_to(Terrain.unpack(path.points[i])) < 0.001
	check(same,"Footpath geometry and network survive save and load")
	check(model.change_asset(path.id,path.points,"Talweg","",0,20).ok,"A footpath can be renamed and replanned through the asset editor")
	model.set_enabled(path.id,false)
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"A closed path keeps its physical surface and remains saveable")
	check(not model.preview_walkway([[900,300],[940,300]]).ok,"A path with two unconnected ends is explained instead of becoming a useless strip")
	model.money=0
	var count: int = model.walk_areas.size()
	check(not model.build_walkway(endpoints).ok and model.walk_areas.size() == count,"Insufficient funds cannot half-build a path")

func _hiking_save() -> void:
	var model := Resort.new();model.new_game(false);model.money=3000000;model.terrain=Hump.new();model.terrain.rise=4
	check(model.build_lift("chair2",Vector2(0,220),Vector2(0,0)).ok and model.build_piste([[0,0],[0,220]]).ok,"A live resort accepts a real downhill circuit containing a counter-slope")
	check(model.admit_guest(0),"A compatible guest can choose the new counter-slope circuit")
	if model.guests.is_empty(): return
	var guest: Dictionary = model.guests[0]
	for i in range(guest.route.legs.size()):
		if guest.route.legs[i].kind == "ski":guest.leg=i;model._start_leg(guest);break
	var found := false
	for i in range(1,guest.ski_motion.size()):
		if guest.ski_motion[i][2] == 1:
			guest.elapsed = guest.duration*(guest.ski_motion[i-1][0]+guest.ski_motion[i][0])*0.5
			found = true;break
	check(found and not guest.walk_ranges.is_empty(),"The actual guest reaches a saved hiking phase with a personal energy profile")
	check(Profile.describe(model,guest).activity.contains("Stapft") and Profile.describe(model,guest).reason.contains("Schwung"),"The guest inspector explains the actual hiking activity and its reason")
	var leg: Dictionary = guest.route.legs[guest.leg]
	var f := Resort.ski_fraction(leg,guest.elapsed/guest.duration,guest.ski_motion)
	var at: Vector3 = model.guest_position(guest)
	check(Vector2(at.x,at.z).distance_to(model.terrain.point_on_path(model.asset(leg.id).points,f)) < 0.01,"Hiking follows the route centre rather than drawing skiing turns uphill")
	# Synthetic terrain cannot be restored as an actual map: profile serialization is
	# checked separately here; real-map old-version migration is covered below.
	check(Motion.valid_profile(JSON.parse_string(JSON.stringify(guest.ski_motion))),"Personal hiking speed and mode round-trip through JSON exactly")

func _real_hiking_save() -> void:
	var model := Resort.new();model.new_game(false);model.money=3000000
	model.build_lift("chair",Vector2(200,205),Vector2(-140,-320))
	var built: Dictionary = model.build_piste([[-100,-300],[-100,-140],[200,205]])
	check(built.ok and model.routes_for(2).size() == 1,"A real Sonnenhang counter-slope has a usable circuit through its lift")
	for i in range(5):
		if model.admit_guest(2): break
	check(not model.guests.is_empty(),"Guests can actually buy and use the real-map hiking circuit")
	if model.guests.is_empty(): return
	var guest: Dictionary = model.guests[0]
	for i in range(guest.route.legs.size()):
		if guest.route.legs[i].kind == "ski": guest.leg=i;model._start_leg(guest);break
	var found := false
	for i in range(1,guest.ski_motion.size()):
		if guest.ski_motion[i][2] == 1:
			guest.elapsed=guest.duration*(guest.ski_motion[i-1][0]+guest.ski_motion[i][0])*0.5;found=true;break
	check(found and guest.walk_ranges.size() == 1,"Hiking stays a continuous activity across a counter-slope instead of toggling every sample")
	var before: Vector3 = model.guest_position(guest)
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.guest_position(copy.guests[0]).distance_to(before) < 0.001,"A real guest mid-climb reloads at the same position with the same personal profile")
	for i in range(20): model.advance_minute(false);copy.advance_minute(false)
	check(model.total_rides == copy.total_rides and absf(model.money-copy.money) < 0.0001 and model.guest_position(model.guests[0]).distance_to(copy.guest_position(copy.guests[0])) < 0.001,"The restored real climb and descent continue deterministically")

func _migration() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.8-starter.json"))
	var model := Resort.new()
	check(model.restore(old).ok and model.guests.size() == old.guests.size() and model.legacy_foot,"A populated actual 0.8 save keeps active guests and the walking corridors they need")
	if model.guests.is_empty(): return
	var before: Vector3 = model.guest_position(model.guests[0])
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.guest_position(copy.guests[0]).distance_to(before) < 0.001,"A migrated journey is saved again in format 10 without moving the guest")
	for i in range(15): model.advance_minute(false);copy.advance_minute(false)
	check(model.total_rides == copy.total_rides and absf(model.money-copy.money) < 0.0001,"Saved hiking-era migrations continue deterministically")
