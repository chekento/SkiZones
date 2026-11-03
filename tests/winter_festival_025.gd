extends SceneTree
const Calendar = preload("res://src/core/annual_festival.gd")
const Complex = preload("res://src/core/hotel_complex.gd")
const Resort = preload("res://src/core/resort.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Activities = preload("res://src/core/building_activities.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("PASS ",description)
	else: failed+=1; push_error("FAIL "+description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var cal:=Calendar.new()
	cal.path="user://winter_festival_025_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cal.path))
	var dec6: Dictionary={"year":2026,"month":12,"day":6,"hour":12,"minute":0,"second":0}
	var dec24: Dictionary={"year":2026,"month":12,"day":24,"hour":15,"minute":0,"second":0}
	var dec31: Dictionary={"year":2026,"month":12,"day":31,"hour":23,"minute":59,"second":57}
	check(Calendar.season({"year":2026,"month":11,"day":30})=="" and Calendar.season({"year":2027,"month":1,"day":2})=="","Winter event stays disabled outside its annual dates")
	check(Calendar.season(dec6)=="advent" and Calendar.unlocked(dec6,6) and not Calendar.unlocked(dec6,7),"Advent unlocks daily by device-local calendar day")
	check(Calendar.reward(6)>Calendar.reward(5) and Calendar.reward(24)>Calendar.reward(6),"Nikolaus and Christmas Eve provide distinctive larger gifts")
	check(cal.claim(6,dec6).ok and not cal.claim(6,dec6).ok,"The same yearly Advent door pays exactly once")
	check(not cal.claim(24,dec6).ok and cal.claim(24,dec24).ok,"December 24 cannot be accessed before its date")
	var saved:=Calendar.new()
	saved.path=cal.path
	check(saved.overview(dec24).claimed.has(24) and saved.overview(dec24).claimed.has(6),"Annual claims survive fresh instances and cannot be reset by game saves")
	check(saved.claim(6,{"year":2027,"month":12,"day":6,"hour":12,"minute":0,"second":0}).ok,"A new calendar year opens the same Advent door again")
	check(Calendar.countdown(dec31)==3 and Calendar.season(dec31)=="new_year_eve","New Year's countdown uses real local seconds, not game minutes")
	check(not saved.celebrate_new_year({"year":2026,"month":12,"day":31,"hour":22,"minute":0,"second":0}).ok,"Early New Year's celebration is refused")
	var first_party=saved.celebrate_new_year({"year":2027,"month":1,"day":1,"hour":0,"minute":0,"second":1})
	check(first_party.ok and not saved.celebrate_new_year({"year":2027,"month":1,"day":1,"hour":0,"minute":12,"second":0}).ok,"New Year party happens once for a yearly event")
	check(saved.celebrate_new_year({"year":2028,"month":1,"day":1,"hour":0,"minute":15,"second":0}).ok,"A separate year may hold the annual party again")
	var currency_before: int=int(saved.overview(dec24).coins)
	var bought=saved.buy_decoration("star")
	check(bought.ok and saved.overview(dec24).owned.has("star") and saved.overview(dec24).coins<currency_before,"Decorations persist and consume hard-capped earned winter tokens")
	check(not saved.buy_decoration("star").ok,"One decoration cannot be bought twice")
	for kind in ["fitness","souvenir","watchmaker","craftshop"]:
		check(Catalog.BUILDINGS.has(kind) and Needs.SERVICES.has(kind) and not Activities.spec(kind).is_empty(),"New village trade is a playable, service-capable business: "+kind)
	var model:=Resort.new()
	model.new_game(false)
	model.money=50000
	model.buildings=[
		{"id":1001,"kind":"hotel","point":Terrain.pack(Vector2(110,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1002,"kind":"fitness","point":Terrain.pack(Vector2(154,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1003,"kind":"spa","point":Terrain.pack(Vector2(198,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1004,"kind":"souvenir","point":Terrain.pack(Vector2(245,240)),"rotation":0,"enabled":true,"level":1}]
	model._invalidate()
	check(Complex.valid_all(model.buildings),"Legacy standalone hotel buildings are valid without new fields")
	var first=Complex.attach(model,1001,1002)
	check(first.ok and int(model.asset(1002).hotel_attachment.slot)==1 and int(model.money)==45500,"Adjacent fitness club docks as linear hotel module for one connector payment")
	check(not Complex.attach(model,1001,1004).ok,"A nonadjacent service cannot skip the end of the linear hotel")
	check(Complex.attach(model,1001,1003).ok and Complex.ordered(model.buildings,1001).size()==2,"A spa can extend the modular hotel line")
	check(Complex.valid_all(model.buildings),"A fully connected two-module hotel passes persistent schema checks")
	check(not Complex.detach(model,1001,1002).ok and Complex.detach(model,1001,1003).ok,"Removing a middle module cannot orphan the remaining chain")
	var invalid=model.buildings.duplicate(true)
	invalid[1].hotel_attachment.after_id=99999
	check(not Complex.valid_all(invalid),"Broken or forged attachment references fail safe validation")
	check(model.demolish(1001).get("ok",false)==false,"Hotel demolition is prevented until its attached businesses are detached")
	check(Complex.detach(model,1001,1002).ok and Complex.valid_all(model.buildings),"Module detach does not demolish the operating business")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cal.path))
	print("ANNUAL FESTIVAL AND HOTEL MODULES: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
