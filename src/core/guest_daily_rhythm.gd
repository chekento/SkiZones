extends RefCounted
## SkiZones 0.41: clock-aware, needs-driven meal preferences.
## Pure utility modifier: never changes guest state, save schema, routing or
## RNG, and never grants a meal without a reachable, open, staffed venue.
const FULL_MEALS := ["restaurant","pizzeria","schmarrn"]
const SNACKS := ["cocoa","kiosk"]
const EARLY_LUNCH_START := 690 # 11:30
const LUNCH_START := 720 # 12:00
const LUNCH_END := 840 # 14:00
const LATE_SNACK_START := 840
const LATE_SNACK_END := 1020 # 17:00

static func minute_of_day(minute: int) -> int:
	return posmod(minute,1440)

static func _meal_guest(guest: Dictionary) -> bool:
	return guest.get("night_out",false)==false and guest.get("heading_home",false)==false

static func _last_food_minutes(guest: Dictionary) -> int:
	var history: Dictionary=guest.get("service_history",{})
	var last: int=-100000
	for kind in FULL_MEALS+SNACKS:
		last=maxi(last,int(history.get(kind,-100000)))
	return last

static func _hunger(guest: Dictionary) -> float:
	var hunger: float=float(guest.get("needs",{}).get("hunger",0.0))
	for member in guest.get("family",[]):
		hunger=maxf(hunger,float(member.get("needs",{}).get("hunger",0.0)))
	return clampf(hunger,0,100)

static func _family(guest: Dictionary) -> bool:
	return int(guest.get("group_size",1))>1 or guest.get("agenda",{}).get("kind","")=="family" or guest.has("family") or guest.has("party_id")

## Personal rhythm: sufficiently fed guests continue using pistes. Hungry
## families get a gentle lunch preference, small snacks only when appropriate.
## The existing Needs.utility emergency thresholds always take precedence.
static func utility_bonus(guest: Dictionary, kind: String, minute: int) -> float:
	if not _meal_guest(guest):return 0.0
	if kind not in FULL_MEALS and kind not in SNACKS:return 0.0
	var hunger: float=_hunger(guest)
	var clock: int=minute_of_day(minute)
	var family: bool=_family(guest)
	var last_food: int=_last_food_minutes(guest)
	var age: int=int(guest.get("age",0))
	# Do not chain cocoa / restaurant / kiosk visits every circuit.
	if age-last_food<75 and hunger<85.0:return 0.0
	if kind in FULL_MEALS:
		if clock<EARLY_LUNCH_START or clock>=900:return 0.0
		if hunger<28.0:return 0.0
		var peak: float=1.0 if clock>=LUNCH_START and clock<LUNCH_END else 0.45
		return minf(34.0,(hunger-24.0)*0.55)*peak*(1.20 if family else 1.0)
	# Hot cocoa and waffles are complements to skiing, not mandatory stops.
	var snack_window: bool=(clock>=600 and clock<LUNCH_START) or (clock>=LATE_SNACK_START and clock<LATE_SNACK_END)
	if not snack_window or hunger<24.0:return 0.0
	return minf(19.0,(hunger-22.0)*0.37)*(1.10 if family else 1.0)
