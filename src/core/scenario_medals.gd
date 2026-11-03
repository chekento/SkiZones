extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Permanent scenario medals: separate from overwritten maps and career slots.
## Grades may improve on replay, never regress or duplicate.
const Geo = preload("res://src/core/real_resorts.gd")
const PATH := "user://skizones_scenario_medals.cfg"
const DIFFICULTIES := {"relaxed":1,"normal":2,"expert":3}
var path := PATH

func records() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path)!=OK: return {}
	var found: Dictionary={}
	for id in Geo.IDS:
		var rank: Variant=config.get_value("scenarios",id,0)
		if rank is int and rank>=1 and rank<=3: found[id]=rank
	return found

func record(id: String, difficulty: String) -> bool:
	if id not in Geo.IDS or not DIFFICULTIES.has(difficulty): return false
	var old:=records()
	var current: int=int(old.get(id,0))
	var next_value: int=int(DIFFICULTIES[difficulty])
	if current>=next_value: return true
	var config:=ConfigFile.new()
	for key in old: config.set_value("scenarios",key,old[key])
	config.set_value("scenarios",id,next_value)
	var target:=ProjectSettings.globalize_path(path)
	var temp:=target+".tmp"
	var error:=config.save(temp)
	if error!=OK: return false
	error=DirAccess.rename_absolute(temp,target)
	if error!=OK: DirAccess.remove_absolute(temp)
	return error==OK

func medals() -> Array:
	var result: Array=[]
	var values:=records()
	for id in Geo.IDS:
		if not values.has(id): continue
		var rank: int=int(values[id])
		result.append({"event":"scenario","id":id,"year":0,"rank":rank,"title":str(Geo.map_spec(id).name)+" · "+L.text(["Bronze","Silber","Gold"][rank-1])})
	return result

