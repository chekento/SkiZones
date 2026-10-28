extends SceneTree
## Read the actual rendered vehicle and passenger transforms, not a dummy renderer.
const Fleet = preload("res://src/core/lift_fleet.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(false)
	game.paused = true
	var widths: Dictionary = {}
	for kind in ["drag", "chair1", "chair2", "chair", "chair8", "gondola"]:
		game.model.new_game(false)
		game.model.money = 3000000
		game.model.build_lift(kind, Vector2(200, 205), Vector2(245, -130))
		game.model.build_piste([[245, -130], [275, -30], [255, 95], [200, 205]])
		var lift: Dictionary = game.model.lifts[0]
		var schedule: Dictionary = game.model.fleet_layout(lift)
		for visitor in range(40):
			game.model.admit_guest(0)
		for guest in game.model.guests:
			for index in range(guest.route.legs.size()):
				if guest.route.legs[index].kind == "lift":
					guest.leg = index
					break
			game.model._start_leg(guest)
		for i in range(ceili(schedule.interval * 2) + 1):
			game.model.advance_minute(false)
		game.view.simulation_fraction = 0
		game.view.rebuild()
		game.view.home()
		game.view._process(0)
		await process_frame
		var actual_cars: MultiMesh = game.view._vehicles[kind].multimesh
		check(game.view.chairs.size() == schedule.count and actual_cars.visible_instance_count == schedule.count, "%s renders its complete physical fleet" % kind)
		widths[kind] = actual_cars.mesh.get_aabb().size.x
		var people: MultiMesh = game.view._cabin_riders.multimesh if kind == "gondola" else (game.view.visitor_mesh.multimesh if kind == "drag" else game.view._riders.multimesh)
		var riders: Array = []
		for guest in game.model.guests:
			if guest.phase == "moving" and guest.route.legs[guest.leg].kind == "lift":
				riders.append(guest)
		check(people.visible_instance_count == riders.size() and riders.size() == schedule.seats * 2, "%s renders exactly the actually boarded passengers" % kind)
		var attached := true
		var carriers: Dictionary = {}
		for index in range(riders.size()):
			var guest: Dictionary = riders[index]
			var actual_person := people.get_instance_transform(index)
			var metadata: Dictionary = {}
			for car in game.view.chairs:
				if car.id == lift.id and car.carrier == guest.ride_car:
					metadata = car
			var actual_car := actual_cars.get_instance_transform(metadata.index)
			if kind == "drag":
				var p := Vector2(actual_person.origin.x, actual_person.origin.z)
				attached = attached and absf(actual_person.origin.y - game.model.terrain.height(p) - 0.15) < 0.002 and Vector2(actual_car.origin.x, actual_car.origin.z).distance_to(p) < 0.002
			else:
				var local := actual_car.affine_inverse() * actual_person.origin
				attached = attached and local.distance_to(Fleet.seat_offset(lift, guest.ride_seat)) < 0.002
			var key: int = guest.ride_car
			carriers[key] = carriers.get(key, 0) + 1
		for count in carriers.values():
			attached = attached and count <= schedule.seats
		check(attached, "%s passengers occupy real, bounded seats or remain on the tow track" % kind)
		game.view.simulation_fraction = 0.5
		game.view._process(0)
		var same_attachment := true
		for index in range(riders.size()):
			var guest: Dictionary = riders[index]
			same_attachment = same_attachment and people.get_instance_transform(index).origin.distance_to(game.model.rider_pose(guest, 0.5).transform.origin) < 0.002
		check(same_attachment, "%s passengers stay attached between simulation ticks" % kind)
		check(game.view._queue_labels[lift.id].text.begins_with(str(game.model.queue_size(lift.id))) and game.view._walkers.multimesh.visible_instance_count == game.model.queue_size(lift.id), "%s displays the actual queue length in people and its station label" % kind)
		if kind == "drag":
			check(game.view._tow_lines.multimesh.visible_instance_count == schedule.count, "Drag carriers use separate, terrain-following tow ropes instead of chairs")
		if kind == "gondola":
			check(game.view._vehicle_glass.has(kind) and game.view._vehicle_glass[kind].multimesh.visible_instance_count == schedule.count, "Gondolas have cabin walls and windows around their actual passengers")
		game.view.simulation_fraction = 0
	check(widths.chair1 < widths.chair2 and widths.chair2 < widths.chair and widths.chair < widths.chair8, "Rendered chair widths and padded seats distinguish every seating variant")
	check(game.view.foot_mesh != null and game.view.foot_mesh.mesh.get_surface_count() == 1 and game.view.foot_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].y > 0, "Station plazas are actual terrain-following geometry")
	var clear := true
	for area in game.model.pedestrian_layout().areas:
		clear = clear and not game.view._clear_ground(area.center, 0)
	check(clear, "Forests do not grow across the prepared pedestrian plazas")
	var piste: Dictionary = game.model.pistes[0]
	var lift: Dictionary = game.model.lifts[0]
	check(Terrain.unpack(piste.points[0]).distance_to(Terrain.unpack(lift.top)) > Foot.machine_radius(lift) and Terrain.unpack(piste.points[-1]).distance_to(Terrain.unpack(lift.bottom)) > Foot.machine_radius(lift), "Visible piste ends stop in the plaza outside the station machinery")
	var end_height: float = game.model.Snow.base_height(piste, 1)
	check(absf(end_height - 0.37) < 0.001, "The piste snow tapers into the pedestrian plaza at its exit")
	game.hud.palette.select_category("lifts")
	game.hud.refresh()
	await process_frame
	var visible_card := game.hud.palette.cards[1].button as Button
	check(visible_card.size.y >= 100, "Lift cards provide room for their distinct icons, speed and length limits")
	game.queue_free()
	await process_frame
	await process_frame
	print("LIFT SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
