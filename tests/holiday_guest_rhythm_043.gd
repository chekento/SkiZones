extends SceneTree
## Deterministic calendar-gated NPC preferences; no simulation mutation.
const Holiday=preload("res://src/core/holiday_guest_rhythm_043.gd")
var passed:=0
var failed:=0

func check(ok:bool,description:String)->void:
	if ok:passed+=1;print("PASS ",description)
	else:failed+=1;push_error("FAIL "+description)

func guest(family:bool=true)->Dictionary:
	return {"id":42,"age":350,"group_size":4 if family else 1,
		"years":37,"agenda":{"kind":"family" if family else "blue"},
		"needs":{"hunger":50.0,"warmth":48.0,"energy":78.0,"joy":60.0},
		"service_history":{}}

func _init()->void:
	call_deferred("run")

func run()->void:
	var date:Dictionary={"year":2026,"month":12,"day":6}
	check(Holiday.event_for(date)=="nikolaus","December 6 activates Nikolaus guest preferences")
	date.day=24
	check(Holiday.event_for(date)=="christmas_eve","December 24 activates Christmas Eve")
	date.day=25
	check(Holiday.event_for(date)=="christmas_day","December 25 activates Christmas Day")
	date.day=26
	check(Holiday.event_for(date)=="boxing_day","December 26 activates Boxing Day")
	date.day=27
	check(Holiday.event_for(date)=="" and Holiday.event_for({"year":2026,"month":11,"day":30})=="","No phantom holiday visitors on ordinary dates")
	check(Holiday.event_for({"year":2026,"month":12,"day":32})=="","Invalid calendar dates cannot activate holiday preference")
	var g:Dictionary=guest()
	var baseline:Dictionary=g.duplicate(true)
	check(Holiday.bonus(g,"cocoa",680,"nikolaus")>0 and Holiday.bonus(g,"kiosk",680,"nikolaus")>0,"Nikolaus encourages a real cocoa or snack stop")
	check(Holiday.bonus(g,"cocoa",680,"nikolaus")>Holiday.bonus(guest(false),"cocoa",680,"nikolaus"),"Families prefer Nikolaus refreshments more strongly")
	check(Holiday.bonus(g,"cocoa",560,"nikolaus")==0 and Holiday.bonus(g,"cocoa",1070,"nikolaus")==0,"Nikolaus snacks do not create overnight demand")
	check(Holiday.bonus(g,"restaurant",850,"nikolaus")==0,"Nikolaus does not fake a Christmas dinner")
	check(Holiday.bonus(g,"restaurant",1000,"christmas_eve")>0 and Holiday.bonus(g,"restaurant",750,"christmas_day")>0 and Holiday.bonus(g,"pizzeria",750,"boxing_day")>0,"Three Christmas dates favour real served meals")
	check(Holiday.bonus(g,"restaurant",630,"christmas_eve")==0 and Holiday.bonus(g,"restaurant",1150,"christmas_eve")==0,"Christmas dinner has a bounded service window")
	check(Holiday.bonus(g,"craftshop",780,"nikolaus")>0 and Holiday.bonus(g,"souvenir",950,"boxing_day")>0,"Holiday gift buying uses existing shop kinds")
	g.service_history={"souvenir":330}
	check(Holiday.bonus(g,"craftshop",850,"christmas_day")==0 and Holiday.bonus(g,"watchmaker",850,"christmas_eve")==0,"A previous shop purchase prevents shop-chain farming")
	g=guest();g.service_history={"cocoa":300}
	check(Holiday.bonus(g,"restaurant",750,"christmas_day")==0,"A recent snack blocks a second unearned seasonal meal")
	g.needs.hunger=90.0
	check(Holiday.bonus(g,"restaurant",750,"christmas_day")>0,"Genuine urgent hunger can still seek a complete meal")
	g=guest();g.needs.energy=20.0
	check(Holiday.bonus(g,"souvenir",780,"nikolaus")==0 and Holiday.bonus(g,"restaurant",780,"christmas_day")==0,"Exhausted guests cannot be lured into holiday shopping")
	g=guest();g.heading_home=true
	check(Holiday.bonus(g,"cocoa",700,"nikolaus")==0,"Guests already heading home are never redirected")
	g=guest();g.incident=7
	check(Holiday.bonus(g,"cocoa",700,"nikolaus")==0,"An active rescue always takes precedence")
	g=guest()
	check(Holiday.bonus(g,"disco",1140,"christmas_eve")==0,"Festive family routines never create nightclub demand")
	for event in ["nikolaus","christmas_eve","christmas_day","boxing_day"]:
		for kind in ["cocoa","kiosk","restaurant","pizzeria","schmarrn","souvenir","craftshop","watchmaker"]:
			Holiday.bonus(g,kind,780,event)
	check(g==baseline,"Holiday preferences are pure and add no save, money, guest or RNG fields")
	print("HOLIDAY GUEST RHYTHM: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
