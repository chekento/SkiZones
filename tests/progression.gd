extends SceneTree

const Resort = preload("res://src/core/resort.gd")
const Progression = preload("res://src/core/progression.gd")
var passed := 0
var failed := 0

func _init() -> void:
	_research()
	_upgrades()
	_contracts()
	_saves()
	_seasons()
	_long_career()
	print("CAREER RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func fresh():
	var model := Resort.new()
	model.new_game(true)
	return model

func close_day(model: RefCounted) -> void:
	while not model.day_finished():
		model.advance_minute(false)

func _research() -> void:
	var model = fresh()
	check(model.campaign.mode == "career" and model.campaign.offers.size() == 3 and model.campaign.points == 6, "Career starts with research points and three offers")
	check(model.build_access_message("gondola", true) != "" and model.build_access_message("hotel", false) != "", "Advanced construction needs the appropriate research")
	var funds: float = model.money
	check(not model.start_research("not-a-project").ok and model.money == funds, "Unknown research cannot consume funds")
	check(not model.start_research("gondola").ok, "Research prerequisites cannot be skipped")
	check(model.start_research("snowcraft").ok and model.money == funds - 18000 and model.campaign.points == 3, "Starting research charges the published money and points exactly once")
	check(not model.start_research("meteo").ok and not Progression.has(model, "snowcraft"), "Only one project runs and its effect is not premature")
	var forecast := Progression.weather_for_day(model.rng.seed, 2)
	close_day(model)
	check(not Progression.has(model, "snowcraft"), "Research is still in progress at the end of its start day")
	model.next_day()
	check(Progression.has(model, "snowcraft") and model.campaign.project.is_empty(), "A one-day project completes on the next morning")
	check(model.weather_index == forecast, "The weather forecast matches the next actual operating day")
	check(model.build_access_message("maintenance", false) == "", "Completed snow research unlocks the garage")
	var free := Resort.new()
	free.new_game(false)
	check(free.build_access_message("gondola", true) == "" and free.build_access_message("hotel", false) == "", "Free construction retains immediate access to all asset types")

func _upgrades() -> void:
	var model = fresh()
	var id: int = model.lifts[0].id
	var balance: float = model.money
	check(not model.upgrade_asset(id).ok and model.money == balance, "Locked upgrades cannot spend money")
	model.campaign.research.append("lifttech")
	var quoted: Dictionary = model.upgrade_check(id)
	check(model.upgrade_asset(id).ok and model.money == balance - quoted.cost and model.lifts[0].level == 2, "Lift upgrade charges its quote and advances one level")
	check(model.lift_capacity(model.lifts[0]) == 525 and model.lift_speed(model.lifts[0]) > 90, "Lift upgrades increase real capacity and speed")
	check(not model.upgrade_asset(id).ok, "Level three needs master research")
	model.campaign.research.append("mastercraft")
	check(model.upgrade_asset(id).ok and model.lift_capacity(model.lifts[0]) == 630, "Master research allows the third lift level")
	balance = model.money
	check(not model.upgrade_asset(id).ok and model.money == balance, "Upgrades stop at level three without charging")
	var original = fresh()
	var upgraded = fresh()
	upgraded.campaign.mode = "free"
	upgraded.upgrade_asset(upgraded.pistes[0].id)
	original.admit_guest(0)
	upgraded.admit_guest(0)
	var elapsed := 0
	while (original.total_rides == 0 or upgraded.total_rides == 0) and elapsed < 500:
		original.advance_minute(false)
		upgraded.advance_minute(false)
		elapsed += 1
	check(original.total_rides == upgraded.total_rides and upgraded.pistes[0].condition > original.pistes[0].condition, "Piste upgrades reduce wear under the same skier traffic")
	var rental: Dictionary = upgraded.buildings[1]
	var costs: float = upgraded.operating_costs()
	upgraded.upgrade_asset(rental.id)
	check(upgraded.operating_costs() > costs, "Higher building levels also increase operating costs")
	upgraded.campaign.research.append("efficient_snow")
	var without_loan: float = upgraded.operating_costs()
	upgraded.take_loan()
	check(is_equal_approx(upgraded.operating_costs() - without_loan, 450.0), "Research does not discount the stated loan interest")

func offer(id: String, kind: String = "visitors", target: int = 2) -> Dictionary:
	return {"id": id, "kind": kind, "target": target, "reward": 1000, "points": 3, "deadline": 3}

func _contracts() -> void:
	var model = fresh()
	model.campaign.offers = [offer("1-demo")]
	check(model.accept_contract("1-demo").ok and not model.accept_contract("1-demo").ok, "One offer cannot be accepted twice")
	model.admit_guest(0)
	Progression.refresh(model)
	check(model.campaign.contracts[0].status == "active", "Contracts count progress after acceptance")
	model.admit_guest(0)
	Progression.refresh(model)
	check(model.campaign.contracts[0].status == "ready", "Meeting the real visitor target completes the contract")
	var balance: float = model.money
	var points: int = model.campaign.points
	check(model.claim_contract("1-demo").ok and model.money == balance + 1000 and model.campaign.points == points + 3, "Contract rewards pay their stated amount and points")
	balance = model.money
	check(not model.claim_contract("1-demo").ok and not model.accept_contract("1-demo").ok and model.money == balance, "A claimed contract cannot be farmed repeatedly")
	var limits = fresh()
	limits.campaign.offers = [offer("1-a", "rides", 10000), offer("1-b", "rides", 10000), offer("1-c", "rides", 10000)]
	check(limits.accept_contract("1-a").ok and limits.accept_contract("1-b").ok and not limits.accept_contract("1-c").ok, "At most two new contracts can be accepted on one day")
	limits.day = 2
	Progression.begin_day(limits)
	limits.campaign.offers = [offer("2-a", "rides", 10000), offer("2-b", "rides", 10000)]
	check(limits.accept_contract("2-a").ok and not limits.accept_contract("2-b").ok, "At most three unfinished contracts can be held")
	limits.day = 4
	Progression.refresh(limits)
	check(limits.campaign.contracts[0].status == "failed", "Missing a multi-day deadline fails the contract")
	var network = fresh()
	network.campaign.offers = [offer("1-network", "variety", 2)]
	network.accept_contract("1-network")
	network.money = 1000000
	network.build_piste([[-170, -235], [-160, -50], [-80, 90], [100, 190]], 2)
	Progression.refresh(network)
	check(network.campaign.contracts[0].status == "active", "Disconnected descents do not satisfy a variety contract")
	network.build_piste([[245, -130], [305, 0], [200, 205]], 1)
	Progression.refresh(network)
	check(network.campaign.contracts[0].status == "ready", "A new reachable descent advances variety goals")
	network.campaign.xp = 1000.0
	Progression.refresh(network)
	balance = network.money
	check(network.campaign.rank == 2, "Experience and usable infrastructure unlock a resort star")
	Progression.refresh(network)
	check(network.money == balance, "Resort star bonuses are paid once")

func _saves() -> void:
	var model = fresh()
	model.start_research("service")
	model.campaign.offers = [offer("1-persist", "rides", 500)]
	model.accept_contract("1-persist")
	for i in range(160):
		model.advance_minute()
	var data: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy := Resort.new()
	check(copy.restore(data).ok and copy.campaign.project.id == "service" and copy.campaign.contracts.size() == 1, "Mid-day saves preserve research, contracts and an active resort")
	for i in range(12):
		model.advance_minute()
		copy.advance_minute()
	check(copy.total_rides == model.total_rides and copy.campaign.xp == model.campaign.xp and copy.money == model.money, "Career simulation remains deterministic after loading")
	var corrupt := model.snapshot()
	corrupt.campaign.points = -1
	var balance: float = copy.money
	check(not copy.restore(corrupt).ok and copy.money == balance, "Invalid career data cannot partially overwrite a resort")
	corrupt = model.snapshot()
	corrupt.lifts[0].level = 4
	check(not copy.restore(corrupt).ok, "Unsupported asset levels are rejected")
	var legacy = fresh().snapshot()
	legacy.version = 1
	legacy.erase("campaign")
	for collection in [legacy.pistes, legacy.lifts, legacy.buildings]:
		for item in collection:
			item.erase("level")
			item.erase("upgrade_total")
	legacy.report.erase("investments")
	check(copy.restore(legacy).ok and copy.campaign.mode == "free" and copy.lifts[0].level == 1, "Version 0.1.x saves migrate without locking formerly available construction")
	var leaving = fresh()
	leaving.admit_guest(0)
	leaving.guests[0].phase = "leaving"
	leaving.guests[0].leg = leaving.guests[0].route.legs.size()
	check(copy.restore(JSON.parse_string(JSON.stringify(leaving.snapshot()))).ok, "A guest leaving at the end of an itinerary can be saved and loaded")
	copy.advance_minute(false)
	check(copy.guests.is_empty(), "Restored departing guests leave without an invalid route index")

func _seasons() -> void:
	var model = fresh()
	model.day = 28
	model.report.day = 28
	model.minute = model.CLOSING - 1
	model.advance_minute(false)
	var balance: float = model.money
	var research: Array = model.campaign.research.duplicate()
	check(model.campaign.season_reward_day == 28 and model.campaign.history.size() == 1, "Winter day 28 awards a season bonus and records the result")
	Progression.finish_day(model)
	check(model.money == balance, "Season awards cannot be paid twice")
	model.next_day()
	check(Progression.season_number(model) == 2 and Progression.season_day(model) == 1 and model.pistes.size() == 1 and model.campaign.research == research, "A new winter preserves the resort and its progress")
	check(Progression.event(model).name == "Regulärer Betriebstag", "The event calendar repeats predictably across winters")

func _long_career() -> void:
	# Two whole winters with real arrivals, wear, weather, investment and saves.
	var model = fresh()
	var valid := true
	var retained := true
	var unique_contracts: Dictionary = {}
	for operating_day in range(1, 57):
		for offer_value in model.campaign.offers.duplicate(true):
			model.accept_contract(offer_value.id)
		for research_id in Progression.RESEARCH:
			if model.start_research(research_id).ok:
				break
		if operating_day == 2:
			model.build_piste([[245, -130], [305, 0], [200, 205]], 1)
		if operating_day == 8:
			model.build_building("school", Vector2(75, 292))
			model.build_building("restaurant", Vector2(285, 240))
		if operating_day == 18:
			model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235))
			model.build_piste([[-170, -235], [-160, -50], [-80, 90], [100, 190]], 2)
		if operating_day == 30:
			model.build_building("hotel", Vector2(80, 235))
		for lift in model.lifts:
			model.upgrade_asset(lift.id)
		while not model.day_finished():
			model.advance_minute()
			if operating_day in [14, 35] and model.minute == 720:
				var copy := Resort.new()
				var loaded: Dictionary = copy.restore(JSON.parse_string(JSON.stringify(model.snapshot())))
				retained = retained and loaded.ok
				if not loaded.ok:
					print("LONG SAVE DIAGNOSTIC day=", operating_day, " ", loaded.message)
				else:
					retained = retained and model.guests.size() == copy.guests.size()
					for i in range(20):
						model.advance_minute()
						copy.advance_minute()
					# JSON round-trips finite decimal values to less than a fraction of a cent.
					retained = retained and model.total_rides == copy.total_rides and absf(model.money - copy.money) < 0.0001 and absf(model.campaign.xp - copy.campaign.xp) < 0.0001
		for contract in model.campaign.contracts.duplicate(true):
			if model.claim_contract(contract.id).ok:
				valid = valid and not unique_contracts.has(contract.id)
				unique_contracts[contract.id] = true
		valid = valid and is_finite(model.money) and model.guests.is_empty() and model.report.day == operating_day and model.campaign.finalized_day == operating_day
		model.next_day()
	check(valid and model.day == 57, "A real career completes 56 operating days without invalid balances, repeated rewards or stranded guests")
	check(retained, "Mid-day save continuations remain deterministic in both winters")
	check(model.campaign.research.size() == Progression.RESEARCH.size(), "The full research tree can be completed through normal career income and points")
	check(model.campaign.history.size() == 28 and model.campaign.history[0].day == 29 and model.campaign.history[-1].day == 56, "Financial history rolls over to the most recent winter")
	check(model.campaign.season_reward_day == 56 and Progression.season_number(model) == 3 and model.campaign.completed > 6, "Repeated winters retain development and offer fresh completable contracts")
	print("LONG CAREER: guests=%d rides=%d contracts=%d research=%d funds=%.0f" % [model.total_guests, model.total_rides, model.campaign.completed, model.campaign.research.size(), model.money])
