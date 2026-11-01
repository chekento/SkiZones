extends SceneTree
## Families must book rooms as one reservation and actually spend the night.
const Resort = preload("res://src/core/resort.gd")
const Lodging = preload("res://src/core/guest_lodging.gd")
const Ops = preload("res://src/core/operations.gd")
const Parties = preload("res://src/core/guest_parties.gd")
var passed := 0
var failed := 0

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func _init() -> void:
	call_deferred("run")

func fixture() -> RefCounted:
	var model := Resort.new()
	model.new_game(true, 20261027, "braunlage")
	for lift in model.lifts:
		lift.fault = ""
	for lift in model.lifts.slice(0, mini(4, model.lifts.size())):
		Ops.fill_stations(model, int(lift.id), true)
	Ops.refresh_duty(model)
	model._operational_change()
	model.enable_runtime_rules()
	return model

func sleeping(people: Array) -> bool:
	return people.size() == 5 and people.all(func(g): return g.phase == "waiting" and g.get("waiting_reason", "") == "hotel")

func run() -> void:
	var model := fixture()
	check(model.admit_guest(0, "family", 5), "Real scenario admits a five-person hotel holiday")
	var family: Array = model.guests.duplicate()
	check(family.size() == 5 and model.parties.size() == 1, "Holiday uses five independent people and their real guardians")
	if family.size() != 5:
		finish()
		return
	var hotel_id: int = int(family[0].get("lodging_id", 0))
	check(hotel_id > 0 and family.all(func(g): return int(g.get("lodging_id", 0)) == hotel_id), "Parents and children share one booked hotel")
	if hotel_id <= 0:
		finish()
		return
	check(Lodging.rooms_used(model, hotel_id) == 3, "Five people reserve exactly three rooms after party expansion")
	var hotel: Dictionary = model.asset(hotel_id)
	var initial_revenue: float = float(hotel.revenue)
	var identities: Array = family.map(func(g): return int(g.id))
	var arrivals: int = int(model.total_guests)
	model.minute = 1000
	model._duty_cache.clear()
	# Real movement, lift boarding, care waits and visit completion are used.
	# No actor is moved directly into the hotel by the test.
	for step in range(7200):
		model.advance_minute(false)
		if sleeping(family): break
	check(sleeping(family), "All five independently travel to their hotel and fall asleep")
	if not sleeping(family):
		for person in family:
			print("FAMILY_DIAG ", person.id, " ", person.phase, " ", person.get("waiting_reason", ""), " night=", person.get("hotel_night", false), " leg=", person.leg)
		finish()
		return
	check(is_equal_approx(float(hotel.revenue) - initial_revenue, 3.0 * float(model.operations.room_price)), "The family's night bills three rooms rather than five duplicate charges")
	# Even an overdue meal appointment must not wake sleeping children.
	model.parties[0].meeting_at = Parties.now(model)
	for step in range(10): Parties.tick(model)
	check(sleeping(family), "Overdue group meetings leave sleeping residents inside their hotel")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy := Resort.new()
	check(copy.restore(snapshot).ok, "Sleeping family and guardian relationships pass the save validator")
	if copy.guests.size() == 5:
		check(sleeping(copy.guests) and copy.guests.map(func(g): return int(g.id)) == identities and Lodging.rooms_used(copy, hotel_id) == 3, "Restoration preserves every resident, hotel reservation and sleeping state")
	var forged: Dictionary = snapshot.duplicate(true)
	for person in forged.guests:
		if person.get("waiting_reason", "") == "hotel":
			person.lodging_id = model.buildings.filter(func(b): return b.kind == "hotel" and int(b.id) != hotel_id)[0].id
			break
	check(not copy.restore(forged).ok, "A sleeper claiming a different hotel from their actual visit is rejected")
	if model.day == 1: Ops.midnight(model)
	check(model.guests.map(func(g): return int(g.id)) == identities and model.total_guests == arrivals, "Midnight retains the original family without new check-ins")
	model.minute = 480
	model._duty_cache.clear()
	Ops.refresh_duty(model)
	for person in family: Lodging.wake(model, person)
	check(family.all(func(g): return g.phase == "moving" and not g.get("hotel_night", false)), "The same family resumes its holiday after the hotel night")
	check(family.filter(func(g): return g.has("guardian_id")).all(func(g): return g.route == Parties.actor(model, int(g.guardian_id)).route), "Children leave on their guardian's real route from the hotel")
	var morning_copy := Resort.new()
	check(morning_copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "The family's resumed morning routes remain valid saved itineraries")
	check_capacity()
	finish()

func check_capacity() -> void:
	var model := fixture()
	var hotels: Array = model.buildings.filter(func(b): return b.kind == "hotel")
	for hotel in hotels.slice(1): hotel.enabled = false
	model._operational_change()
	var admitted := true
	for index in range(8):
		admitted = model.admit_guest(0, "family", 5) and admitted
	check(admitted and Lodging.rooms_used(model, int(hotels[0].id)) == 24, "Eight five-person families fill 24 rooms without overbooking after expansion")
	var before: int = model.guests.size()
	var accepted: bool = model.admit_guest(0, "family", 5)
	check(accepted and model.guests.slice(before).all(func(g): return not g.has("lodging_id")) and Lodging.rooms_used(model, int(hotels[0].id)) == 24, "A full hotel admits another family only as day visitors")

func finish() -> void:
	print("FAMILY HOLIDAYS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
