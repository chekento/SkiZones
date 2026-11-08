extends SceneTree
const Calendar = preload("res://src/core/annual_festival.gd")
const Complex = preload("res://src/core/hotel_complex.gd")
const Resort = preload("res://src/core/resort.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Activities = preload("res://src/core/building_activities.gd")
const Terrain = preload("res://src/core/terrain.gd")
const L = preload("res://src/core/i18n.gd")
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
	# Posters have a deliberately broader campaign than Advent doors.
	for day in [1,15,30]:
		check(Calendar.poster_campaign({"year":2026,"month":11,"day":day})=="christmas","November %d shows Christmas posters" % day)
	for day in [1,24,25,26]:
		check(Calendar.poster_campaign({"year":2026,"month":12,"day":day})=="christmas","December %d still shows Christmas posters" % day)
	for day in [27,28,29,30,31]:
		check(Calendar.poster_campaign({"year":2026,"month":12,"day":day})=="new_year","December %d shows New Year posters" % day)
	check(Calendar.poster_campaign({"year":2027,"month":1,"day":1})=="new_year","January 1 still shows New Year posters across the year boundary")
	check(Calendar.poster_campaign({"year":2027,"month":1,"day":2})=="" and Calendar.poster_campaign({"year":2026,"month":10,"day":31})=="","Poster campaigns end on January 1 and begin November 1")
	check(Calendar.poster_campaign({"year":2026,"month":2,"day":30})=="","Invalid leap dates never activate billboards")
	var Posters=preload("res://src/core/seasonal_billboards_040.gd")
	var used: Dictionary={}
	for idx in range(4):used[int(Posters.info({"year":2026,"month":11,"day":8},idx).variant)]=true
	check(used.size()==4,"Four distinct Christmas poster designs rotate across billboard sites")
	check(int(Posters.info({"year":2027,"month":1,"day":1},0).year)==2027,"New Year poster copies reflect the real rollover year")
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
	check(Calendar.can_celebrate({"year":2026,"month":12,"day":31,"hour":23,"minute":55,"second":0}) and not Calendar.can_celebrate({"year":2027,"month":1,"day":1,"hour":1,"minute":0,"second":0}),"The same celebration window opens at 23:55 and closes at 01:00")
	check(not Calendar.can_celebrate({"year":2026,"month":12,"day":31,"hour":23,"minute":99,"second":0}),"Invalid clock fields cannot claim a yearly celebration")
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
	model.campaign.mode="career" # exact connector charge is a career rule
	model.money=50000
	model.buildings=[
		{"id":1001,"kind":"hotel","point":Terrain.pack(Vector2(110,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1002,"kind":"fitness","point":Terrain.pack(Vector2(154,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1003,"kind":"spa","point":Terrain.pack(Vector2(198,240)),"rotation":0,"enabled":true,"level":1},
		{"id":1004,"kind":"souvenir","point":Terrain.pack(Vector2(245,240)),"rotation":0,"enabled":true,"level":1}]
	model._invalidate()
	check(Complex.valid_all(model.buildings),"Legacy standalone hotel buildings are valid without new fields")
	L.configure("en")
	var first=Complex.attach(model,1001,1002)
	check(first.ok and int(model.asset(1002).hotel_attachment.slot)==1 and int(model.money)==45500,"Adjacent fitness club docks as linear hotel module for one connector payment")
	check(first.message=="Independent business is now module 1 of the hotel complex.","A numbered hotel-module confirmation uses the selected language")
	L.configure("de")
	check(not Complex.attach(model,1001,1004).ok,"A nonadjacent service cannot skip the end of the linear hotel")
	check(Complex.attach(model,1001,1003).ok and Complex.ordered(model.buildings,1001).size()==2,"A spa can extend the modular hotel line")
	check(Complex.valid_all(model.buildings),"A fully connected two-module hotel passes persistent schema checks")
	check(not Complex.detach(model,1001,1002).ok and Complex.detach(model,1001,1003).ok,"Removing a middle module cannot orphan the remaining chain")
	var invalid=model.buildings.duplicate(true)
	invalid[1].hotel_attachment.after_id=99999
	check(not Complex.valid_all(invalid),"Broken or forged attachment references fail safe validation")
	check(model.demolish(1001).get("ok",false)==false,"Hotel demolition is prevented until its attached businesses are detached")
	check(Complex.detach(model,1001,1002).ok and Complex.valid_all(model.buildings),"Module detach does not demolish the operating business")
	model.campaign.mode="free"
	model.money=0
	check(Complex.attach(model,1001,1002).ok and model.money==0,"A real free-build hotel connector works without research or money even while paused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cal.path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
