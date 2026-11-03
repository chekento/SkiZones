extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
const Activities = preload("res://src/core/building_activities.gd")
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS ", message)
	else: failed += 1; push_error("FAIL " + message)

func place(model: RefCounted, kind: String) -> Dictionary:
	for z in range(160, 420, 34):
		for x in range(70, 430, 34):
			if model.build_building(kind, Vector2(x, z)).ok: return model.buildings[-1]
	return {}

func perfect(model: RefCounted, id: int) -> Dictionary:
	var session := Activities.start(model, id)
	if not session.get("ok", false): return session
	var result := {}
	for index in range(5):
		var task := Activities.challenge(model, session)
		var input: Variant = task.toppings if task.mode == "pizza" else float(task.target) if task.mode == "timing" else int(task.answer)
		result = Activities.answer(model, session, input)
	return result

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var model := Resort.new()
	model.new_game(true, 20261027, "sonnenhang")
	model.campaign.mode = "free"
	model.money = 10000000.0
	for kind in model.Catalog.BUILDINGS:
		check(not Activities.spec(kind).is_empty(), "Every constructed building has an interactive activity: " + kind)
	var pizza := place(model, "pizzeria")
	var cabin := place(model, "cabin")
	var apartment := place(model, "apartment")
	var hotel := place(model, "hotel")
	check(not pizza.is_empty() and not cabin.is_empty() and not apartment.is_empty() and not hotel.is_empty(), "New accommodation and pizzeria use real build-site and walkway checks")
	if pizza.is_empty() or cabin.is_empty() or hotel.is_empty() or apartment.is_empty():
		print("RESULT: %d passed; %d failed" % [passed, failed]); quit(1); return
	Ops.enable(model)
	Ops.refresh_duty(model)
	check(model.Lodging.room_count(cabin) == 2 and model.Lodging.room_count(apartment) == 4 and model.Lodging.room_count(hotel) == 24, "Different property types supply different actual overnight capacities")
	check(is_equal_approx(Hospitality.service_multiplier(model, pizza), 1.0), "An uncustomised pizzeria earns its base tariff without an automatic menu bonus")
	var recipes := Hospitality.menu(pizza)
	recipes[0] = {"name":"KoSch Spezial", "toppings":["cheese", "tomato", "mushroom", "pepper", "olive"]}
	check(Hospitality.set_menu(model, int(pizza.id), recipes).ok and Hospitality.menu(pizza)[0].name == "KoSch Spezial", "Three custom named pizzas retain the player's toppings")
	check(Hospitality.service_multiplier(model, pizza) > 1.0, "Only a saved custom pizza menu earns the variety bonus")
	check(not Hospitality.set_menu(model, int(pizza.id), recipes.slice(0, 2)).ok, "A two-pizza menu cannot replace the required three recipes")
	var malicious := recipes.duplicate(true); malicious[0].toppings.append("unknown")
	check(not Hospitality.set_menu(model, int(pizza.id), malicious).ok, "Unknown ingredients are rejected")
	var result := perfect(model, int(pizza.id))
	check(result.get("score", 0) == 100 and result.get("reward", 0) == 250 and int(pizza.activity.bonus) == 20, "Pizza input is evaluated against actual recipes and rewards a completed shift")
	perfect(model, int(pizza.id)); perfect(model, int(pizza.id))
	var money: float = model.money
	check(perfect(model, int(pizza.id)).get("reward", -1) == 0 and model.money == money, "Fourth daily shift remains playable without unlimited money farming")
	model.day += 1
	check(perfect(model, int(pizza.id)).get("reward", 0) == 250, "A new resort day restores the three rewarded shifts")
	check(Hospitality.configure(model, int(hotel.id), {"price":165, "chain":"KoSch Alpine"}).ok and Hospitality.configure(model, int(apartment.id), {"chain":"KoSch Alpine"}).ok, "Separate accommodation types join a named hotel chain")
	check(Hospitality.chain_members(model, hotel).size() == 2 and Hospitality.room_price(model, hotel) == 165, "Chain members retain individual nightly prices")
	check(not Hospitality.configure(model, int(hotel.id), {"family_share":80, "premium_share":80}).ok, "Room mix cannot allocate more than the available inventory")
	var story := Activities.start(model,int(hotel.id))
	var first_chapter := Activities.challenge(model,story)
	check(first_chapter.mode == "hotel_story" and first_chapter.scene == "arrival" and first_chapter.choices.size() == 3, "Hotel offers independent guest-driven chapters instead of generic question list")
	var rooms_before: int = int(Hospitality.dashboard(model,hotel).occupied)
	var hotel_reward := perfect(model,int(hotel.id))
	check(hotel_reward.score == 100 and hotel_reward.reward == 250 and int(hotel.activity.hotel_story_xp) == 100, "Five thoughtful hotel decisions grant bounded rewards and persistent story experience")
	check(Hospitality.dashboard(model,hotel).occupied == rooms_before, "Illustrated hotel activity cannot invent or double-book overnight guests")
	var story_saved := model.snapshot()
	var story_copy := Resort.new()
	check(story_copy.restore(story_saved).ok and int(story_copy.asset(int(hotel.id)).activity.hotel_story_xp) == 100, "Hotel story progression survives exact save/load")

	var cost_before := model.operating_costs()
	check(Hospitality.configure(model, int(hotel.id), {"marketing":3}).ok and model.operating_costs() > cost_before, "Marketing and hotel services have real running costs")
	model.minute = 480
	Ops.refresh_duty(model)
	check(model.admit_guest(0, "blue"), "Normal-mode guest enters a real staffed circuit")
	var guest: Dictionary = model.guests[-1] if not model.guests.is_empty() else {}
	check(guest.has("lodging_id") and guest.stay >= model.Lodging.MIN_HOLIDAY_MINUTES, "Normal-mode tourists book a reachable overnight property for several days")
	if guest.has("lodging_id"):
		var property: Dictionary = model.asset(int(guest.lodging_id))
		guest.hotel_night = true
		var first := Hospitality.night_charge(model, property, guest)
		check(first > 0 and Hospitality.night_charge(model, property, guest) == 0, "A hotel night is billed once even if arrival handling repeats")
		guest.erase("hotel_night")
	hotel.hotel.cleanliness = 60.0
	var old_minute: int = model.minute
	model.minute = 1440
	Ops.refresh_duty(model)
	Hospitality.daily(model)
	check(float(hotel.hotel.cleanliness) > 60.0, "Automatic cleaning uses the real planned team even at the 24:00 closing boundary")
	model.minute = old_minute
	Ops.refresh_duty(model)
	var offer := Hospitality.weekly_offer(model)
	model.operations.weekly_enabled = true
	model.report.guests = 800
	offer = Hospitality.weekly_offer(model)
	check(offer.available and offer.price < offer.full and offer.price >= offer.floor, "Weekly offer saves money while retaining its operating-cost floor")
	var vacation := {"id":9999, "stay":10080, "group_size":2, "lodging_id":hotel.id}
	var sale := Hospitality.ticket_sale(model, vacation)
	check(vacation.ticket_type == "week" and vacation.ticket_until_day == model.day + 6 and sale == int(offer.price) * 2, "Weekly ticket covers exactly seven calendar days and bills the actual party once")
	model.day += 1
	money = model.money
	Hospitality.renew_day_ticket(model, vacation)
	check(model.money == money, "Weekly holiday visitor does not pay another day ticket the following morning")
	var morning := {"id":8888, "age":1440, "stay":6000, "ticket_until_day":model.day - 1, "group_size":1, "ticket_paid":42.0, "spending":42.0, "agenda":{"kind":"blue"}}
	money = model.money
	Hospitality.renew_day_ticket(model, morning); Hospitality.renew_day_ticket(model, morning)
	check(model.money == money + model.ticket_price, "Multi-day guest with a day ticket pays once for the next ski day")
	var dashboard := Hospitality.dashboard(model, hotel)
	check(dashboard.cost > 0 and dashboard.break_even > 0, "Hotel dashboard includes planned staff, infrastructure and service costs")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(Resort.new().restore(saved).ok, "Menus, hotel chains, activities and occupied normal-mode lodging survive JSON save/load")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	for building in bad.buildings:
		if int(building.id) == int(hotel.id): building.hotel.cleanliness = INF
	check(not Resort.new().restore(bad).ok, "Non-finite hotel settings are rejected without altering the active save")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
