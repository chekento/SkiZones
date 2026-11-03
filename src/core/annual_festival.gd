extends RefCounted
## Annual local-time holidays. Entirely device-local; no GPS or network calls.
## The separate archive prevents a saved career from resetting previous doors.
const PATH := "user://skizones_annual_festival.cfg"
const DECORATIONS := {
	"lanterns":{"name":"Winter-Laternen","price":6},
	"star":{"name":"Holzsterne","price":8},
	"gifts":{"name":"Geschenkestapel","price":12},
	"tree":{"name":"Festlicher Dorfbaum","price":20},
	"garlands":{"name":"Tannengirlanden","price":10},
	"clock":{"name":"Neujahrs-Countdown-Schild","price":16}
}
var path := PATH

static func device_now() -> Dictionary:
	return Time.get_datetime_dict_from_system(false)

static func valid_date(date: Dictionary) -> bool:
	for key in ["year","month","day"]:
		if not date.get(key) is int: return false
	var year: int=int(date.year)
	var month: int=int(date.month)
	var day: int=int(date.day)
	if year < 2025 or year > 9999 or month < 1 or month > 12: return false
	var days := [31,28 + int(year%4==0 and (year%100!=0 or year%400==0)),31,30,31,30,31,31,30,31,30,31]
	return day >= 1 and day <= int(days[month-1])

static func season(date: Dictionary) -> String:
	if not valid_date(date): return ""
	if int(date.month)==12:
		return "advent" if int(date.day)<=24 else "christmas" if int(date.day)<=30 else "new_year_eve"
	if int(date.month)==1 and int(date.day)==1: return "new_year"
	return ""

static func visible(date: Dictionary) -> bool:
	return season(date)!=""

static func unlocked(date: Dictionary, door: int) -> bool:
	return valid_date(date) and int(date.month)==12 and door>=1 and door<=24 and int(date.day)>=door

static func festive_year(date: Dictionary) -> int:
	return int(date.year)-1 if valid_date(date) and int(date.month)==1 else int(date.get("year",0))

static func reward(door: int) -> int:
	# Advent 6 (Nikolaus) and 24 are extra-generous, repeatable NEXT year.
	return 24 if door==24 else 12 if door==6 else 3 + door%3

func _state() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path)!=OK: return {"claims":{},"coins":0,"owned":[],"new_years":[]}
	var claims: Dictionary = {}
	for section in config.get_sections():
		if not section.begins_with("advent_"): continue
		var year_text := section.trim_prefix("advent_")
		if not year_text.is_valid_int(): continue
		var year := int(year_text)
		if year<2025 or year>9999: continue
		var values: Variant=config.get_value(section,"doors",[])
		if not values is Array: continue
		var unique := {}
		for item in values:
			if item is int and item>=1 and item<=24: unique[item]=true
		claims[str(year)]=unique.keys()
	var coins: Variant=config.get_value("account","winter_coins",0)
	var owned: Variant=config.get_value("account","decorations",[])
	var new_years: Variant=config.get_value("account","new_years",[])
	var owned_unique := {}
	if owned is Array:
		for item in owned:
			if item is String and DECORATIONS.has(item): owned_unique[item]=true
	var years_unique := {}
	if new_years is Array:
		for item in new_years:
			if item is int and item>=2025 and item<=9999: years_unique[item]=true
	return {"claims":claims,"coins":clampi(int(coins) if coins is int else 0,0,100000),"owned":owned_unique.keys(),"new_years":years_unique.keys()}

func _save(state: Dictionary) -> Error:
	var config := ConfigFile.new()
	for year in state.claims:
		config.set_value("advent_"+str(year),"doors",state.claims[year])
	config.set_value("account","winter_coins",int(state.coins))
	config.set_value("account","decorations",state.owned)
	config.set_value("account","new_years",state.new_years)
	var target := ProjectSettings.globalize_path(path)
	var temp := target+".tmp"
	var error := config.save(temp)
	if error!=OK: return error
	# Atomic replacement on supported filesystems; never remove previous state first.
	error=DirAccess.rename_absolute(temp,target)
	if error!=OK: DirAccess.remove_absolute(temp)
	return error

func overview(date: Dictionary = {}) -> Dictionary:
	var now: Dictionary = device_now() if date.is_empty() else date
	var state := _state()
	var year := festive_year(now)
	var claimed: Array=state.claims.get(str(year),[])
	return {"season":season(now),"year":year,"claimed":claimed.duplicate(),"coins":int(state.coins),"owned":state.owned.duplicate(),"new_year_done":state.new_years.has(year)}

func claim(door: int, date: Dictionary = {}) -> Dictionary:
	var now: Dictionary=device_now() if date.is_empty() else date
	if not unlocked(now,door): return {"ok":false,"message":"Dieses Adventstürchen wird erst am entsprechenden Dezembertag geöffnet."}
	var state := _state()
	var key:=str(now.year)
	var doors: Array=state.claims.get(key,[])
	if doors.has(door): return {"ok":false,"message":"Dieses Türchen wurde in diesem Jahr bereits geöffnet."}
	if state.coins + reward(door)>100000: return {"ok":false,"message":"Maximaler Wintertaler-Vorrat erreicht."}
	doors.append(door)
	doors.sort()
	state.claims[key]=doors
	state.coins+=reward(door)
	if _save(state)!=OK: return {"ok":false,"message":"Kalender konnte nicht sicher gespeichert werden."}
	return {"ok":true,"coins":reward(door),"message":"Türchen %d geöffnet · +%d Wintertaler!" % [door,reward(door)]}

func buy_decoration(kind: String) -> Dictionary:
	var state := _state()
	if not DECORATIONS.has(kind): return {"ok":false,"message":"Unbekannte Winterdekoration."}
	if state.owned.has(kind): return {"ok":false,"message":"Dekoration bereits freigeschaltet."}
	if int(state.coins)<int(DECORATIONS[kind].price): return {"ok":false,"message":"Für diese Dekoration fehlen Wintertaler."}
	state.coins-=int(DECORATIONS[kind].price)
	state.owned.append(kind)
	if _save(state)!=OK: return {"ok":false,"message":"Dekoration konnte nicht sicher gespeichert werden."}
	return {"ok":true,"message":"Dekoration dauerhaft freigeschaltet: "+str(DECORATIONS[kind].name)}

static func countdown(date: Dictionary) -> int:
	if not valid_date(date) or int(date.month)!=12 or int(date.day)!=31: return -1
	for key in ["hour","minute","second"]:
		if not date.get(key) is int: return -1
	var seconds:=int(date.hour)*3600+int(date.minute)*60+int(date.second)
	if seconds<0 or seconds>=86400: return -1
	return 86400-seconds

func celebrate_new_year(date: Dictionary = {}) -> Dictionary:
	var now: Dictionary=device_now() if date.is_empty() else date
	var year:=festive_year(now)
	if not valid_date(now): return {"ok":false,"message":"Ungültiges Systemdatum."}
	var allowed: bool=(int(now.month)==12 and int(now.day)==31 and int(now.get("hour",0))==23 and int(now.get("minute",0))>=55) or (int(now.month)==1 and int(now.day)==1 and int(now.get("hour",0))==0)
	if not allowed: return {"ok":false,"message":"Jahreswechsel ab 23:55 Uhr bis 01:00 Uhr verfügbar."}
	var state:=_state()
	if state.new_years.has(year): return {"ok":false,"message":"Die Silvesterfeier wurde in diesem Jahr bereits gestartet."}
	state.new_years.append(year)
	state.coins=mini(100000,int(state.coins)+18)
	if _save(state)!=OK: return {"ok":false,"message":"Feier konnte nicht sicher gespeichert werden."}
	return {"ok":true,"message":"Ein frohes neues Jahr! +18 Wintertaler für dein Bergdorf."}
