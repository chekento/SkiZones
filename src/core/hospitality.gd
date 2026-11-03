extends RefCounted
## Owned accommodation, menu design and holiday tickets share the real ledger.
const L = preload("res://src/core/i18n.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const TOPPINGS := {"tomato":"Tomate", "cheese":"Käse", "mushroom":"Pilze", "pepper":"Paprika", "olive":"Oliven", "ham":"Schinken", "salami":"Salami", "pineapple":"Ananas", "spinach":"Spinat", "onion":"Zwiebeln"}
const DEFAULT_PIZZAS := [{"name":"Margherita", "toppings":["tomato", "cheese"]}, {"name":"Alpengarten", "toppings":["tomato", "cheese", "mushroom", "pepper"]}, {"name":"Gipfelpizza", "toppings":["tomato", "cheese", "ham", "onion"]}]
const HOTEL_DEFAULTS := {"price":0, "family_share":30, "premium_share":20, "comfort":1, "breakfast":true, "auto_clean":true, "cleanliness":100.0, "rating":3.5, "marketing":0, "chain":"", "nights":0, "last_review_day":0}

static func lodging(kind: String) -> bool:
	return Catalog.LODGING.has(kind)

static func config(building: Dictionary) -> Dictionary:
	var result := HOTEL_DEFAULTS.duplicate(true)
	result.merge(building.get("hotel", {}), true)
	return result

static func menu(building: Dictionary) -> Array:
	return building.get("pizza_menu", DEFAULT_PIZZAS).duplicate(true)

static func set_menu(model: RefCounted, id: int, recipes: Array) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if building.get("kind", "") != "pizzeria" or not valid_menu(recipes): return model._result(false, L.text("Genau drei Pizzen mit Namen und zwei bis sechs verschiedenen Zutaten anlegen."))
	building.pizza_menu = recipes.duplicate(true)
	return model._result(true, L.text("Deine drei Pizzen stehen jetzt auf der Karte."))

static func valid_menu(recipes: Variant) -> bool:
	if not recipes is Array or recipes.size() != 3: return false
	for recipe in recipes:
		if not recipe is Dictionary or not recipe.get("name") is String or recipe.name.strip_edges().is_empty() or recipe.name.length() > 32: return false
		if not recipe.get("toppings") is Array or recipe.toppings.size() < 2 or recipe.toppings.size() > 6: return false
		var seen := {}
		for topping in recipe.toppings:
			if not topping is String or not TOPPINGS.has(topping) or seen.has(topping): return false
			seen[topping] = true
	return true

static func configure(model: RefCounted, id: int, changes: Dictionary) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if not lodging(str(building.get("kind", ""))): return model._result(false, L.text("Eine eigene Unterkunft wählen."))
	var proposed := config(building)
	for key in changes:
		if key not in ["price", "family_share", "premium_share", "breakfast", "auto_clean", "marketing", "chain"]: return model._result(false, L.text("Diese Hoteleinstellung ist ungültig."))
		proposed[key] = changes[key]
	if not valid_hotel(proposed): return model._result(false, L.text("Diese Hoteleinstellung ist ungültig."))
	building.hotel = proposed
	model._audience_offer.clear()
	return model._result(true, L.text("Unterkunft und Hotelverbund aktualisiert."))

static func valid_hotel(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not HOTEL_DEFAULTS.has(key): return false
	for key in HOTEL_DEFAULTS:
		if not value.has(key): return false
	for key in ["price", "family_share", "premium_share", "comfort", "marketing", "nights", "last_review_day"]:
		if not Terrain.number(value[key]) or value[key] != floorf(value[key]) or value[key] < 0 or value[key] > 100000000: return false
	if value.price != 0 and (value.price < 45 or value.price > 350): return false
	if value.family_share > 80 or value.premium_share > 80 or value.family_share + value.premium_share > 90: return false
	if value.comfort < 1 or value.comfort > 5 or value.marketing > 3: return false
	if not value.breakfast is bool or not value.auto_clean is bool: return false
	if not value.chain is String or value.chain.length() > 40 or "\n" in value.chain: return false
	return Terrain.number(value.cleanliness) and value.cleanliness >= 0 and value.cleanliness <= 100 and Terrain.number(value.rating) and value.rating >= 1 and value.rating <= 5

static func valid_building(building: Dictionary) -> bool:
	if building.has("hotel") and (not lodging(str(building.kind)) or not valid_hotel(building.hotel)): return false
	if building.has("pizza_menu") and (building.kind != "pizzeria" or not valid_menu(building.pizza_menu)): return false
	if building.has("activity"):
		var state: Variant = building.activity
		if not state is Dictionary: return false
		for key in ["day", "plays", "best", "bonus", "rounds"]:
			if not Terrain.number(state.get(key)) or state[key] < 0 or state[key] > 100000000 or state[key] != floorf(state[key]): return false
		if state.plays > 3 or state.best > 100 or state.bonus > 20: return false
	return true

static func chain_members(model: RefCounted, building: Dictionary) -> Array:
	var name_value: String = config(building).chain
	if name_value.strip_edges().is_empty(): return []
	return model.buildings.filter(func(b): return lodging(str(b.kind)) and b.enabled and config(b).chain == name_value)

static func room_price(model: RefCounted, building: Dictionary) -> float:
	var settings := config(building)
	if int(settings.price) > 0: return float(settings.price)
	return float(model.operations.get("room_price", 140)) if building.kind == "hotel" else float(Catalog.LODGING[building.kind].price)

static func nightly_price(model: RefCounted, building: Dictionary, guest: Dictionary) -> float:
	var settings := config(building)
	var family: bool = guest.has("family") or guest.has("party_id") or int(guest.get("group_size", 1)) > 1
	# Room mix affects the achievable rate, with a family-friendly allocation.
	var premium: bool = not family and posmod(int(guest.id) * 17, 100) < int(settings.premium_share)
	var multiplier := 1.30 if premium else 0.95 if family and int(settings.family_share) > 0 else 1.0
	return snappedf(room_price(model, building) * multiplier, 0.01)

static func extra_upkeep(building: Dictionary) -> float:
	if not lodging(str(building.kind)) or not building.enabled: return 0.0
	var settings := config(building)
	var rooms: int = int(Catalog.LODGING[building.kind].rooms) * int(building.get("level", 1))
	return rooms * ((1.8 if settings.auto_clean else 0.0) + (2.2 if settings.breakfast else 0.0) + (int(settings.comfort) - 1) * 1.2) + int(settings.marketing) * 65.0

static func planned_cost(model: RefCounted, building: Dictionary) -> float:
	var wages := 0.0
	for person in model.operations.staff:
		if person.assignment != "building:%d" % int(building.id): continue
		var times: Array = model.Ops.SHIFTS[person.shift]
		wages += float(person.wage) * posmod(int(times[1]) - int(times[0]), 1440) / 60.0
	# Include the required team even when the player has not hired it yet.
	for row in model.Ops.building_team(model, building):
		var times: Array = model.Ops.SHIFTS[row.shift]
		wages += int(row.missing) * float(model.Ops.ROLES[row.role].wage) * posmod(int(times[1]) - int(times[0]), 1440) / 60.0
	return wages + float(Catalog.BUILDINGS[building.kind].upkeep) * (1.0 + 0.2 * (int(building.get("level", 1)) - 1)) + 35 + extra_upkeep(building)

static func dashboard(model: RefCounted, building: Dictionary) -> Dictionary:
	var capacity: int = model.Lodging.room_count(building)
	var occupied: int = model.Lodging.rooms_used(model, int(building.id))
	var price := room_price(model, building)
	var cost := planned_cost(model, building)
	return {"capacity":capacity, "occupied":occupied, "vacant":maxi(0, capacity - occupied), "occupancy":float(occupied) / maxi(1, capacity), "price":price, "cost":cost, "break_even":ceili(cost / maxf(1, price * 0.95)), "forecast":occupied * price * 0.95 - cost, "chain":chain_members(model, building).size()}

static func upgrade(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if not lodging(str(building.get("kind", ""))): return model._result(false, L.text("Eine eigene Unterkunft wählen."))
	var settings := config(building)
	var cost: int = 1600 * int(Catalog.LODGING[building.kind].rooms) * int(settings.comfort)
	if int(settings.comfort) >= 5 or not model._spend(cost): return model._result(false, L.text("Für diesen Komfortausbau reicht das Budget oder die Ausbaustufe nicht."))
	settings.comfort = int(settings.comfort) + 1
	building.hotel = settings
	model._audience_offer.clear()
	return model._result(true, L.text("Zimmerkomfort verbessert. Gäste bewerten Ausstattung und Sauberkeit."))

static func housekeeping(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if not lodging(str(building.get("kind", ""))): return model._result(false, L.text("Eine eigene Unterkunft wählen."))
	var cost: float = 8.0 * model.Lodging.room_count(building)
	if not model.Ops._expense(model, cost, "building:%d" % id): return model._result(false, L.text("Das Budget reicht für die Zimmerreinigung noch nicht."))
	var settings := config(building)
	settings.cleanliness = 100.0
	building.hotel = settings
	return model._result(true, L.text("Zimmer gereinigt und für die Gäste vorbereitet."))

static func daily(model: RefCounted) -> void:
	for building in model.buildings:
		if not lodging(str(building.kind)) or not building.enabled: continue
		var settings := config(building)
		if int(settings.last_review_day) >= int(model.day): continue
		var used: int = model.Lodging.rooms_used(model, int(building.id))
		var ratio: float = float(used) / maxi(1, model.Lodging.room_count(building))
		# The closing clock is 1440 until Ops.midnight normalises it.
		# Use the planned daily team here; on-duty queries at 24:00 are empty.
		var cleaning_team: bool = not model.Ops.active(model) or model.Ops.building_team(model, building).all(func(row): return int(row.missing) == 0)
		settings.cleanliness = clampf(float(settings.cleanliness) - ratio * 16.0 + (22.0 if settings.auto_clean and cleaning_team else 0.0), 0, 100)
		if used > 0:
			var value: float = clampf(2.2 + int(settings.comfort) * 0.32 + float(settings.cleanliness) * 0.015 + (0.2 if settings.breakfast else 0.0) - maxf(0, room_price(model, building) / float(Catalog.LODGING[building.kind].price) - 1.25) * 0.8, 1, 5)
			settings.rating = snappedf(lerpf(float(settings.rating), value, 0.2), 0.01)
		settings.last_review_day = model.day
		building.hotel = settings

static func attraction(model: RefCounted, building: Dictionary, guest: Dictionary) -> float:
	var settings := config(building)
	var family: bool = int(guest.get("group_size", 1)) > 1 or guest.has("party_id")
	var chain := maxi(0, chain_members(model, building).size() - 1)
	return float(settings.rating) * 2.0 + float(settings.cleanliness) * 0.03 + int(settings.marketing) * 0.6 + mini(chain, 4) * 0.35 + (float(settings.family_share) * 0.02 if family else 0.0) - room_price(model, building) / 45.0

static func night_charge(model: RefCounted, building: Dictionary, guest: Dictionary) -> float:
	if not guest.get("hotel_night", false) or int(guest.get("lodging_id", 0)) != int(building.id): return float(Catalog.BUILDINGS[building.kind].income) * int(guest.get("group_size", 1))
	var night := maxi(0, floori(float(model.Ops.clock(model) - 420) / 1440.0))
	if int(guest.get("lodging_billed_night", -1)) == night: return 0.0
	guest.lodging_billed_night = night
	var settings := config(building)
	settings.nights = int(settings.nights) + 1
	building.hotel = settings
	return nightly_price(model, building, guest) * model.Lodging.billable_rooms(model, guest)

static func service_multiplier(model: RefCounted, building: Dictionary) -> float:
	var activity: Dictionary = building.get("activity", {})
	var bonus: float = float(activity.get("bonus", 0)) / 100.0 if int(activity.get("day", 0)) == int(model.day) else 0.0
	var menu_bonus := 0.0
	if building.kind == "pizzeria" and building.has("pizza_menu"):
		var unique := {}
		for pizza in menu(building):
			for topping in pizza.toppings: unique[topping] = true
		menu_bonus = minf(0.12, unique.size() * 0.012)
	return 1.0 + bonus + menu_bonus

static func weekly_offer(model: RefCounted) -> Dictionary:
	var discount: int = int(model.operations.get("weekly_discount", 12))
	var full: float = model.ticket_price * 7.0
	var expected_guests := maxi(60, maxi(int(model.report.guests), int(model.last_report.get("guests", 0))))
	var daily_share: float = model.operating_costs() / float(expected_guests)
	var floor_price: float = ceilf(daily_share * 7.0 * 1.20)
	var price: int = ceili(maxf(full * (1.0 - discount / 100.0), floor_price))
	return {"enabled":model.operations.get("weekly_enabled", false), "price":price, "full":full, "discount":maxf(0, 100.0 * (1.0 - price / full)), "available":price < full, "floor":floor_price}

static func ticket_sale(model: RefCounted, guest: Dictionary) -> float:
	var count := int(guest.get("group_size", 1))
	var offer := weekly_offer(model)
	var weekly: bool = offer.enabled and offer.available and guest.has("lodging_id") and int(guest.stay) >= 6 * 1440
	guest.ticket_type = "week" if weekly else "day"
	guest.ticket_until_day = model.day + (6 if weekly else 0)
	var amount: float = (float(offer.price) if weekly else float(model.ticket_price)) * count
	guest.ticket_paid = amount
	guest.spending = amount
	return amount

static func renew_day_ticket(model: RefCounted, guest: Dictionary) -> void:
	if guest.get("evening", false) or int(guest.get("ticket_until_day", model.day - 1)) >= int(model.day) or int(guest.age) >= int(guest.stay): return
	var amount: float = model.ticket_price * int(guest.get("group_size", 1))
	guest.ticket_type = "day"
	guest.ticket_until_day = model.day
	guest.ticket_paid = float(guest.get("ticket_paid", 0)) + amount
	guest.spending = float(guest.get("spending", 0)) + amount
	model.money += amount
	model.report.tickets += amount
	model.campaign.turnover += amount
	model.audience.segments[guest.agenda.kind].tickets += amount

static func valid_ticket(guest: Dictionary) -> bool:
	if guest.has("ticket_type") and guest.ticket_type not in ["day", "week"]: return false
	for key in ["ticket_until_day", "lodging_billed_night"]:
		if guest.has(key) and (not Terrain.number(guest[key]) or guest[key] < 0 or guest[key] > 100007 or guest[key] != floorf(guest[key])): return false
	return true
