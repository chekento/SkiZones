extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const WC=preload("res://src/core/public_wc.gd")
const Development=preload("res://src/core/wc_development.gd")
const Catalog=preload("res://src/core/catalog.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Assets=preload("res://src/world/style_assets.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func run() -> void:
	check(Catalog.building_order().filter(func(kind):return WC.is_public(kind))==["wc_dixi"],"Exactly one public toilet can be bought")
	check(Catalog.BUILDINGS.wc_dixi.name=="Portable Toilet","Portable Toilet replaces the branded default name")
	check(Development.PROJECTS.size()==100 and Development.GROUPS.size()==10,"One hundred actual developments in ten branches")
	var covered:Array=[]
	for group in Development.GROUPS:covered.append_array(group.nodes)
	check(covered.size()==100 and covered.all(func(id):return covered.count(id)==1 and Development.PROJECTS.has(id)),"Each development occurs exactly once in its branch")
	var model:=Resort.new();model.new_game(true)
	model.campaign.mode="free";model.money=10000000
	check(model.build_building("wc_dixi",Vector2(155,300)).ok,"The small start model is buildable")
	var item:Dictionary=model.buildings[-1]
	for legacy in ["wc_cabin","wc_module","wc_house","wc_luxury"]:
		check(not model.build_building(legacy,Vector2(155,300)).ok,"Direct purchase of obsolete separate type is blocked: "+legacy)
	model.campaign.mode="career";model.campaign.points=1000
	check(not model.upgrade_check(int(item.id)).ok,"Career expansion waits for its own technology")
	var finished:Array=[]
	var effects:Dictionary={"volume":"volume","hygiene":"hygiene_use","service":"service_factor","aging":"aging_factor","minutes":"minutes","cleaning":"clean_factor","emptying":"empty_factor","upkeep":"upkeep","frost":"frost_factor"}
	for id in Development.PROJECTS:
		var spec:Dictionary=Development.PROJECTS[id]
		check(spec.requires.all(func(required):return finished.has(required)),"Reachable prerequisites: "+id)
		var before:Dictionary=WC.specification(item,model)
		var cash:float=model.money;var points:int=int(model.campaign.points)
		var construction_before:float=float(Development.modifiers(model.campaign.research).construction)
		var quote_before:int=int(model.upgrade_check(int(item.id)).get("cost",0))
		var result:Dictionary=model.start_research(id)
		check(result.ok and model.money==cash-float(spec.cost) and int(model.campaign.points)==points-int(spec.points),"Real research charges published money and points: "+id)
		if not result.ok:continue
		if id=="wc_logistics":
			var pending:=Resort.new()
			check(pending.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and pending.campaign.project.id==id,"An active development and due date survive saving")
		for day in range(int(spec.days)):
			model.minute=Resort.CLOSING-1
			while not model.day_finished():model.advance_minute(false)
			model.next_day()
		check(model.Progression.has(model,id) and model.campaign.project.is_empty(),"Research completes through actual operating-day transitions: "+id)
		finished.append(id)
		if effects.has(spec.modifier):
			var after:Dictionary=WC.specification(item,model)
			var field:String=effects[spec.modifier]
			check(not is_equal_approx(float(before[field]),float(after[field])),"Development changes a live operating parameter: "+id)
		elif spec.modifier=="construction":
			check(float(Development.modifiers(model.campaign.research).construction)<construction_before and int(model.upgrade_check(int(item.id)).get("cost",0))<quote_before,"Construction development reduces the actual quoted upgrade cost: "+id)
	check(finished.size()==100,"All one hundred developments finish without a dead end")
	var previous_width:float=0
	for level in range(1,6):
		check(int(item.level)==level and model.service_capacity(item)==int(pow(2,level-1)),"Actual capacity follows the built stage: %d" % level)
		var mesh:ArrayMesh=Assets.building("wc_dixi",level,Color("278fc6"),"alpine")
		check(mesh.get_aabb().size.x>previous_width,"The actual world mesh visibly grows at stage %d" % level)
		previous_width=mesh.get_aabb().size.x
		check(Foot.base_building_size(item)==Vector2(Development.STAGES[level-1].footprint[0],Development.STAGES[level-1].footprint[1]),"Navigation and occupied footprint follow the same stage")
		if level==5:break
		var quote:Dictionary=model.upgrade_check(int(item.id));var cash:float=model.money
		check(quote.ok and model.upgrade_asset(int(item.id)).ok and model.money==cash-float(quote.cost),"Expansion charges the checked quote and retains the same building ID")
	check(not model.upgrade_asset(int(item.id)).ok,"Stage five is the final building stage")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored:=Resort.new()
	check(restored.restore(saved.duplicate(true)).ok and restored.campaign.research.size()==100 and restored.asset(int(item.id)).level==5,"Completed tree, public hygiene and expanded facility survive a normal save round trip")
	for kind in ["wc_cabin","wc_module","wc_house","wc_luxury"]:
		var old:Dictionary=saved.duplicate(true)
		old.campaign.research=["wc_logistics","sanitation","wc_winter","wc_hygiene","wc_comfort"]
		old.campaign.project={}
		for building in old.buildings:
			if int(building.id)==int(item.id):building.kind=kind;building.level=3;building.name=Catalog.BUILDINGS[kind].name
		var legacy:=Resort.new()
		check(legacy.restore(old).ok and legacy.asset(int(item.id)).kind==kind and int(WC.specification(legacy.asset(int(item.id))).units)==int(WC.PLACES[kind])*3,"Former standalone WC type retains identity and capacity: "+kind)
	var blocked_safely:=false
	for dx in [-24,-20,-16,16,20,24]:
		for dz in [-20,-12,0,12,20]:
			var blocked:=Resort.new();blocked.new_game(true);blocked.campaign.mode="free"
			if not blocked.build_building("wc_dixi",Vector2(155,300)).ok:continue
			var narrow:Dictionary=blocked.buildings[-1]
			if not blocked.build_building("wc_dixi",Vector2(155+dx,300+dz)).ok:continue
			blocked.campaign.mode="career";blocked.money=1000000
			blocked.campaign.research=["wc_logistics","sanitation","wc_hygiene","wc_comfort"]
			for level in range(1,5):
				var quote:Dictionary=blocked.upgrade_check(int(narrow.id))
				if not quote.ok:
					var unchanged:float=blocked.money
					blocked_safely=not blocked.upgrade_asset(int(narrow.id)).ok and blocked.money==unchanged and int(narrow.level)==level
					break
				blocked.upgrade_asset(int(narrow.id))
			if blocked_safely:break
		if blocked_safely:break
	check(blocked_safely,"A blocked larger footprint cannot charge money or expand into its neighbour")
	var free:=Resort.new();free.new_game(false)
	check(float(WC.specification(item,free).service_factor)==0.8,"Free construction bypasses access gates without inventing economic research bonuses")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
