extends RefCounted
## Seasonal guest preferences, not a second economy or a guest spawner.
## Existing route planning is solely responsible for open/staffed venues,
## capacity, real pedestrian access, actual visits and recorded revenue.
## Device-local calendar dates are passed in by the caller; no save fields,
## random draws, network calls or location permission are needed.
const Calendar=preload("res://src/core/annual_festival.gd")
const Habits=preload("res://src/core/guest_habits_042.gd")
const SHOPS:=["souvenir","craftshop","watchmaker"]
const MEALS:=["restaurant","pizzeria","schmarrn"]
const SNACKS:=["cocoa","kiosk"]

static func event_for(date:Dictionary)->String:
	if not Calendar.valid_date(date) or int(date.month)!=12:return ""
	match int(date.day):
		6:return "nikolaus"
		24:return "christmas_eve"
		25:return "christmas_day"
		26:return "boxing_day"
	return ""

static func _recent(guest:Dictionary,kinds:Array,minutes:int)->bool:
	var history:Dictionary=guest.get("service_history",{})
	var age:int=int(guest.get("age",0))
	for kind in kinds:
		if age-int(history.get(kind,-100000))<minutes:return true
	return false

static func _family(guest:Dictionary)->bool:
	return int(guest.get("group_size",1))>1 or guest.has("family") or str(guest.get("agenda",{}).get("kind",""))=="family"

## Only a bounded change in attraction score. Every additional paid visit
## still has to pass the unchanged routing, staff, offer and budget machinery.
static func bonus(guest:Dictionary,kind:String,minute:int,event:String)->float:
	if event not in ["nikolaus","christmas_eve","christmas_day","boxing_day"]:return 0.0
	if not Habits.allowed(guest,kind):return 0.0
	if guest.get("heading_home",false) or guest.get("hotel_night",false) or guest.get("night_out",false):return 0.0
	if guest.get("assisted",false) or int(guest.get("incident",-1))>=0:return 0.0
	var state:Dictionary=guest.get("needs",{})
	if float(state.get("energy",100.0))<25.0:return 0.0
	var clock:int=posmod(minute,1440)
	var family_factor:float=1.20 if _family(guest) else 1.0
	if kind in SNACKS and event=="nikolaus":
		if clock<600 or clock>=1020 or _recent(guest,MEALS+SNACKS,75):return 0.0
		if float(state.get("hunger",0.0))<24.0 and float(state.get("warmth",100.0))>=60.0:return 0.0
		return 18.0*family_factor if kind=="cocoa" else 8.0*family_factor
	if kind in MEALS and event in ["christmas_eve","christmas_day","boxing_day"]:
		var start:int=720 if event=="christmas_eve" else 690
		var end:int=1140 if event=="christmas_eve" else 1020
		if clock<start or clock>=end or float(state.get("hunger",0.0))<32.0:return 0.0
		if _recent(guest,MEALS+SNACKS,90) and float(state.get("hunger",0.0))<85.0:return 0.0
		return (24.0 if event=="christmas_eve" else 20.0)*family_factor
	if kind in SHOPS:
		if clock<600 or clock>=1080 or _recent(guest,SHOPS,120):return 0.0
		if event=="nikolaus" and clock<660:return 0.0
		# Encourage ordinary reachable local shops; the party identity keeps
		# the preference stable for a whole family and across reloads.
		var identity:int=hash(str(guest.get("party_id",guest.get("id",0)))) & 0x7fffffff
		var preferred:String=SHOPS[posmod(identity,SHOPS.size())]
		return (19.0 if kind==preferred else 10.0)*family_factor
	return 0.0
