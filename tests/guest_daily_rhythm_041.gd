extends SceneTree
## No new fields are written to JSON saves; all preferences are derived from
## the existing clock, need bars, age and family/party information.
const Rhythm=preload("res://src/core/guest_daily_rhythm.gd")
const Resort=preload("res://src/core/resort.gd")
var passed:=0
var failed:=0
func check(ok: bool, title: String)->void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init()->void:call_deferred("run")
func _guest(hunger: float=46.0,family: bool=false)->Dictionary:
	return {"age":280,"group_size":4 if family else 1,"needs":{"hunger":hunger,"warmth":80.0,"energy":85.0,"joy":80.0},"service_history":{},"agenda":{"kind":"family" if family else "blue"}}
func run()->void:
	var guest: Dictionary=_guest()
	check(Rhythm.utility_bonus(guest,"restaurant",780)>0 and Rhythm.utility_bonus(guest,"restaurant",780)>Rhythm.utility_bonus(guest,"restaurant",695),"Lunch is most appealing from noon to 2 p.m.")
	check(Rhythm.utility_bonus(guest,"restaurant",670)==0 and Rhythm.utility_bonus(guest,"restaurant",915)==0,"No manufactured lunch reservation before 11:30 or late afternoon")
	check(Rhythm.utility_bonus(guest,"cocoa",650)>0 and Rhythm.utility_bonus(guest,"cocoa",930)>0 and Rhythm.utility_bonus(guest,"cocoa",790)==0,"Cocoa is a morning or afternoon pause, not a competing midday meal")
	check(Rhythm.utility_bonus(guest,"restaurant",790)>Rhythm.utility_bonus(guest,"cocoa",790),"A complete meal outranks a snack at lunchtime")
	guest.needs.hunger=8
	check(Rhythm.utility_bonus(guest,"restaurant",785)==0 and Rhythm.utility_bonus(guest,"kiosk",920)==0,"Comfortably fed guests retain the whole ski day")
	guest=_guest(49.0,true)
	check(Rhythm.utility_bonus(guest,"restaurant",780)>Rhythm.utility_bonus(_guest(49.0), "restaurant",780),"Family lunch gets a small coordinated bonus")
	guest.needs.hunger=8;guest.family=[{"needs":{"hunger":66.0}}]
	check(Rhythm.utility_bonus(guest,"restaurant",790)>0,"A hungry child triggers a family food stop even when guardian is not hungry")
	guest=_guest(47.0)
	guest.service_history={"cocoa":245}
	check(Rhythm.utility_bonus(guest,"restaurant",790)==0,"A recent cocoa visit prevents back-to-back food purchases")
	guest.needs.hunger=93
	check(Rhythm.utility_bonus(guest,"restaurant",790)>0,"Genuinely urgent hunger overrides meal cadence")
	guest=_guest(56.0)
	guest.heading_home=true
	check(Rhythm.utility_bonus(guest,"restaurant",785)==0,"A guest already leaving never gets redirected by a timed meal")
	check(Rhythm.utility_bonus(guest,"snowpark",785)==0 and Rhythm.utility_bonus(guest,"disco",785)==0,"No change to sport, shelter, toilet or nightlife utilities")
	var model:=Resort.new();model.new_game(true)
	var before: Dictionary=model.snapshot()
	guest=_guest(44.0)
	for t in [540,660,735,840,930]:
		for kind in ["restaurant","cocoa","kiosk","pizzeria"]:
			Rhythm.utility_bonus(guest,kind,t)
	check(model.snapshot()==before,"Pure daily-rhythm scoring never changes any active resort save data")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
