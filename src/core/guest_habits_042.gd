extends RefCounted
## Stable personal tastes derived from existing identity/age; no new save RNG.
const Needs=preload("res://src/core/guest_needs.gd")
const SHOPS:=["souvenir","watchmaker","craftshop"]
static func years(guest:Dictionary)->int:
	# Match the existing guest profile's age, including historical solo guests.
	return int(guest.get("years",guest.family[-1].years if guest.has("family") and not guest.family.is_empty() else 18+posmod(int(guest.id)*17,58)))
static func allowed(guest:Dictionary,kind:String)->bool:
	var youngest:=years(guest)
	for member in guest.get("family",[]):youngest=mini(youngest,int(member.years))
	return kind not in ["bar","disco"] or youngest>=18
static func bonus(guest:Dictionary,kind:String,minute:int)->float:
	if not allowed(guest,kind) or not Needs.SERVICES.has(kind):return 0.0
	if guest.get("heading_home",false) or guest.get("hotel_night",false):return 0.0
	if int(guest.age)-int(guest.get("service_history",{}).get(kind,-10000))<120:return 0.0
	var age:=years(guest)
	var id:=int(guest.id)
	var clock:=posmod(minute,1440)
	var runs:=int(guest.get("runs",0))
	# Keep skiing central; optional visits become attractive at personal breaks.
	if kind=="newsstand" and clock>=480 and clock<660 and age>=25:return 13.0+float(id%7)
	if kind=="printing_press" and age>=25 and clock>=660 and clock<960 and id%7==0:return 15.0
	if kind=="town_hall" and clock>=900 and clock<1080 and id%6==0:return 15.0
	if kind in SHOPS and clock>=840 and clock<1140 and kind==SHOPS[posmod(id,SHOPS.size())]:return 22.0 if age>=18 else 14.0
	if kind in ["viewpoint","shelter","lodge"] and runs>0 and clock>=600 and clock<1020:return 18.0 if age>=60 else 7.0
	if kind=="pool" and clock>=900 and clock<1320:return 25.0 if age<18 or id%4==0 else 0.0
	if kind=="spa" and age>=35 and clock>=960 and clock<1320:return 23.0 if id%3==0 else 0.0
	if kind=="fitness" and age>=16 and age<65 and clock>=900 and clock<1200:return 20.0 if id%5==0 else 0.0
	if kind=="bar" and clock>=1020 and clock<1380:return 20.0 if id%3==1 else 0.0
	if kind=="disco" and age>=18 and age<45 and clock>=1140:return 24.0 if id%3==2 else 0.0
	return 0.0
