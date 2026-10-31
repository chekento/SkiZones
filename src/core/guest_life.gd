extends RefCounted
## Calendar-based hospitality and personal movement, persisted without render RNG.
const L=preload("res://src/core/i18n.gd")
const Terrain=preload("res://src/core/terrain.gd")
const STAYS={"cocoa":[10,15],"schmarrn":[20,25],"pizzeria":[30,45],"restaurant":[75,105],"pub":[180,240],"kiosk":[8,15],"lodge":[25,50]}
static func ensure(guest: Dictionary) -> void:
	if guest.has("life"):return
	var id:=int(guest.id)
	guest.life={"version":1,"stance":"goofy" if posmod(id*17,5)<2 else "regular","curiosity":0.35+posmod(id*37,61)/100.0,"sociability":posmod(id*43,101)/100.0,"leisure":0.8+posmod(id*29,41)/100.0,"wallet":float(90+posmod(id*83,420)),"skill_xp":0.0,"tuition_minutes":0,"lesson_count":0,"recent_pistes":[],"switch_runs":0,"practice":0.0}
static func valid(guest: Dictionary) -> bool:
	if not guest.get("life") is Dictionary:return false
	var state: Dictionary=guest.life
	if state.get("version")!=1 or state.get("stance") not in ["regular","goofy"]:return false
	for key in ["curiosity","sociability","leisure","wallet","skill_xp","tuition_minutes","lesson_count","switch_runs","practice"]:
		if not Terrain.number(state.get(key)) or state[key]<0 or state[key]>1000000:return false
	if state.curiosity>1 or state.sociability>1 or state.leisure>1.3 or state.skill_xp>100:return false
	if not state.get("recent_pistes") is Array or state.recent_pistes.size()>8:return false
	for id in state.recent_pistes:
		if not Terrain.number(id) or id<1 or id!=floorf(id):return false
	return true
static func visit_minutes(guest: Dictionary, building: Dictionary) -> float:
	ensure(guest)
	if not STAYS.has(building.kind):return -1
	var range_value: Array=STAYS[building.kind]
	var seed_value:=posmod(int(guest.id)*71+int(building.id)*31+int(guest.get("runs",0))*13+int(guest.get("service_history",{}).get(building.kind,0)),1000)
	var amount:=lerpf(range_value[0],range_value[1],seed_value/999.0)
	# Same venue, different people: sociable guests linger, cold guests drink first.
	if building.kind=="restaurant":amount=clampf(amount*(0.9+guest.life.sociability*0.2),60,120)
	if building.kind=="pub":amount=clampf(amount*(0.95+guest.life.sociability*0.1),180,240)
	return amount
static func route_weight(guest: Dictionary, target: int) -> float:
	ensure(guest)
	var visits: int=guest.life.recent_pistes.count(target)
	return 1.0+float(guest.life.curiosity)*1.8 if visits==0 else 1.0/(1.0+visits*(0.8+float(guest.life.curiosity)))
static func descent(guest: Dictionary, id: int) -> void:
	ensure(guest)
	guest.life.recent_pistes.append(id)
	if guest.life.recent_pistes.size()>8:guest.life.recent_pistes.pop_front()
	if int(guest.ability)<2:
		guest.life.practice+=0.8
		if guest.life.practice>=4:learn(guest,0.6);guest.life.practice=0.0
static func learn(guest: Dictionary, amount: float) -> void:
	ensure(guest)
	if int(guest.ability)>=2:return
	guest.life.skill_xp+=maxf(0,amount)
	if guest.life.skill_xp>=100:
		guest.life.skill_xp-=100;guest.ability=int(guest.ability)+1
		# A personal blue-only preference is retained after technical progress.
		if guest.get("agenda",{}).get("kind","") not in ["blue","family"]:guest.agenda.comfort=int(guest.ability)
static func pose(guest: Dictionary, piste: Dictionary, fraction: float, hiking: bool) -> Dictionary:
	var result: Dictionary={"yaw":0.0,"switch":false,"stance":"regular","gesture":0.0}
	if not guest.has("life"):return result
	result.stance=guest.life.stance
	if hiking or guest.phase!="moving" or int(guest.ability)<1 or float(piste.get("grade",100))>30 or fraction<0.12 or fraction>0.88:return result
	var slot:=posmod(int(guest.id)*11+int(guest.get("loops",0))*7,11)
	var start:=0.23+posmod(int(guest.id)*13,27)/100.0
	var finish:=start+0.16+posmod(int(guest.id),9)/100.0
	var allowed: bool=slot<3 and fraction>start and fraction<finish and guest.needs.energy>45
	if allowed:
		var blend:=smoothstep(start,start+0.035,fraction)*(1-smoothstep(finish-0.035,finish,fraction))
		result.yaw=PI*blend;result.switch=blend>0.5
	result.gesture=sin(fraction*TAU*3+int(guest.id))*0.035*(0.5+float(guest.life.sociability))
	return result
static func description(guest: Dictionary) -> String:
	if not guest.has("life"):return ""
	var state: Dictionary=guest.life
	return L.text("Technikstufe %d · Lernfortschritt %.0f %% · %d Unterrichtsminuten") % [int(guest.ability)+1,float(state.skill_xp),int(state.tuition_minutes)]+("\n"+L.text("Bevorzugter Vorderfuß: ")+ (L.text("rechts · Goofy") if state.stance=="goofy" else L.text("links · Regular")) if guest.get("sport")=="snowboard" else "")
