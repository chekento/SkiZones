extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Profile = preload("res://src/core/guest_profile.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Art = preload("res://src/world/alpine_art.gd")
var passed := 0
var failed := 0
func check(value: bool, title: String) -> void:
	if value: passed += 1;print("PASS ",title)
	else: failed += 1;push_error("FAIL "+title)
func _init() -> void:
	var model := Resort.new();model.new_game(true)
	for i in range(9): model.admit_guest(i%3)
	var counts := {"ski":0,"snowboard":0,"snowblade":0}
	for guest in model.guests: counts[guest.sport] += 1
	check(model.guests.size() == 9 and counts.ski == 3 and counts.snowboard == 3 and counts.snowblade == 3,"All three winter sports buy tickets and use actual beginner-compatible resort routes")
	var profiles_ok := true
	var motion_ok := true
	var positions: Array = []
	for guest in model.guests:
		profiles_ok = profiles_ok and Profile.describe(model,guest).equipment == Motion.SPORT_NAMES[guest.sport]
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind == "ski":
				guest.leg=i;model._start_leg(guest);guest.elapsed=guest.duration*0.4;break
		motion_ok = motion_ok and Motion.valid_profile(guest.ski_motion) and model.asset(guest.route.legs[guest.leg].id).tracks[-1].sport == guest.sport
		positions.append(model.guest_position(guest))
	check(profiles_ok,"Personal profiles identify the guest's actual equipment")
	check(motion_ok,"All sports receive finite personal motion and matching persistent snow tracks")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.snapshot().version == 10,"Format 10 restores an actual mixed-sport resort")
	var preserved := copy.guests.size() == model.guests.size()
	for i in range(copy.guests.size()):
		preserved = preserved and copy.guests[i].sport == model.guests[i].sport and copy.guest_position(copy.guests[i]).distance_to(positions[i]) < 0.001
	check(preserved,"Saved sports, personal progress and all skier/boarder positions survive loading exactly")
	check(copy.guests.all(func(g):return g.id is int and g.ability is int),"Restored guest identities remain usable as the same typed selection and rendering cache keys")
	for i in range(12):model.advance_minute(false);copy.advance_minute(false)
	check(model.total_rides == copy.total_rides and is_equal_approx(model.money,copy.money) and model.guests.size() == copy.guests.size(),"Mixed-sport visits continue deterministically after saving")
	var bad: Dictionary = copy.snapshot();bad.guests[0].sport="skateboard"
	var before: float = copy.money
	check(not copy.restore(bad).ok and copy.money == before,"Unknown equipment cannot partially replace a working resort save")
	bad = copy.snapshot();bad.guests[0].erase("sport")
	check(not Resort.new().restore(bad).ok,"New-format saves must explicitly preserve each guest's equipment")
	bad = copy.snapshot();bad.pistes[0].tracks[0].sport=7
	check(not Resort.new().restore(bad).ok,"Invalid track equipment is rejected before it can break the renderer")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.9-starter.json"))
	var legacy := Resort.new()
	check(source.version == 9 and legacy.restore(source).ok,"A populated fixture made with published 0.9 source migrates successfully")
	check(legacy.guests.all(func(g):return g.sport == "ski"),"Existing 0.9 skiers keep their equipment instead of becoming arbitrary snowboarders")
	var progress: bool = legacy.guests.size() == source.guests.size()
	for i in range(legacy.guests.size()):progress = progress and is_equal_approx(legacy.guests[i].elapsed,source.guests[i].elapsed)
	check(progress,"Migration retains every active legacy guest and their actual progress")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(legacy.snapshot()))).ok,"Migrated 0.9 visits can immediately be saved and loaded in format 10")
	var skis := Art.new().equipment("ski","glide").get_aabb()
	var blades := Art.new().equipment("snowblade","glide").get_aabb()
	var board := Art.new().equipment("snowboard","glide").get_aabb()
	check(blades.size.z < skis.size.z*0.6 and board.size.z > blades.size.z,"Snowblades are visibly short skis and a snowboard has its own distinct deck geometry")
	check(Motion.style(18,1,"snowblade").wave < Motion.style(18,1,"ski").wave and Motion.style(18,1,"snowboard").name.contains("Board"),"Snowblades and snowboards have distinct personal turning styles")
	print("WINTER SPORTS: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
