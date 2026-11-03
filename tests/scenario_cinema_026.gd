extends SceneTree
## Regression coverage for the return of saved scenarios, camera tours, medals
## and the build-to-unlock achievement newspaper.
const Resort=preload("res://src/core/resort.gd")
const Geo=preload("res://src/core/real_resorts.gd")
const Ops=preload("res://src/core/operations.gd")
const Maps=preload("res://src/core/maps.gd")
const Tour=preload("res://src/world/cinematic_tour.gd")
const Annual=preload("res://src/core/annual_festival.gd")
const Medals=preload("res://src/core/scenario_medals.gd")
const News=preload("res://src/core/newspaper.gd")
const Terrain=preload("res://src/core/terrain.gd")
var passed:=0
var failed:=0

func check(value: bool, label: String) -> void:
	if value: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Maps.SCENARIOS_ENABLED and Maps.MAPS.size()==Maps.FANTASY_MAPS.size()+4,"Four optional real-world scenarios are restored alongside eight normal maps")
	var fixture:=Resort.new()
	fixture.new_game(false)
	check(Ops.group_size(fixture)==1,"Normal resort demand remains unchanged")
	for id in Geo.IDS:
		var model:=Resort.new()
		model.new_game(true,20261027,id)
		var source: Dictionary=Geo.baked(id)
		var piste_source: Array=source.get("pistes",[])
		var open_count: int=piste_source.filter(func(p):return p.get("enabled",false)).size()
		print("SCENARIO_DIAGNOSTIC ",id," pistes=",model.pistes.size()," imported_open=",open_count," of ",piste_source.size()," lifts=",model.lifts.size())
		check(model.operations.scenario==id and model.lifts.size()>=6 and model.pistes.size()>=15,id+" detailed OSM resort data and objective state are preserved")
		var normal_size: int=Ops.group_size(model)
		check(Ops.set_scenario_difficulty(model,"relaxed") and Ops.group_size(model)<=normal_size,id+" calmer intensity lowers grouped visitor volume")
		check(Ops.set_scenario_difficulty(model,"expert") and Ops.group_size(model)>=normal_size,id+" expert intensity raises grouped visitor volume")
		var snapshot: Dictionary=model.snapshot()
		var resumed:=Resort.new()
		check(resumed.restore(JSON.parse_string(JSON.stringify(snapshot))).ok,id+" challenge settings survive real-resort save migration")
		if resumed.operations.get("scenario_difficulty","normal")!="expert":
			check(false,id+" retained difficulty setting after round-trip")
		else: check(true,id+" retained difficulty setting after round-trip")
		var points: Array=Tour.build_hotspots(model)
		check(points.size()>2 and points.size()<=Tour.MAX_HOTSPOTS,id+" automated camera tour traverses actual lift/piste hotspots within bounds")
	var archive:=Medals.new()
	archive.path="user://medals_026_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive.path))
	check(archive.record("braunlage","normal") and archive.record("braunlage","expert"),"Scenario medal progression upgrades to gold")
	check(archive.records().get("braunlage",0)==3 and archive.medals().size()==1,"Medal survives separate archive without duplicates")
	check(archive.record("braunlage","relaxed") and archive.records().get("braunlage",0)==3,"Replay on easier intensity cannot downgrade a medal")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive.path))
	var holiday_medals: Array=Annual.annual_medals({"claims":{"2026":[1,6,24],"2027":[1]},"new_years":[2026,2027]})
	check(holiday_medals.size()==4 and holiday_medals.count(holiday_medals[0])==1,"Annual Christmas and New Year's medals retain each year's identity")
	check(not News.press_available(fixture) and News.latest(fixture).is_empty(),"ExtraBlatt stays locked until a print office exists")
	fixture.buildings.append({"id":111,"kind":"printing_press","enabled":true})
	fixture.buildings.append({"id":112,"kind":"newsstand","enabled":true,"visits":9,"revenue":45.0})
	fixture.achievements=[4,5,8,12,13,17]
	var articles: Array=News.latest(fixture,5)
	check(articles.size()==5 and articles[0].id==17 and articles[4].id==5,"Paper contains exactly the five latest earned achievements, newest first")
	check(News.statistics(fixture).sold==9 and absf(float(News.statistics(fixture).revenue)-45)<0.01,"Newspaper sales come from actual guest purchases, not invented circulation")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

