extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Features=preload("res://src/core/piste_features.gd")
const Modules=preload("res://src/core/park_modules_042.gd")
const Art=preload("res://src/world/alpine_art.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var model:=Resort.new();model.new_game(true);model.money=5000000
	model.campaign.mode="career";model.campaign.research=["snowcraft"]
	var piste:Dictionary=model.pistes[0]
	var original:Array=piste.points.duplicate(true)
	var meshes:Dictionary={}
	check(Features.KINDS.size()>=15 and Features.KINDS.size()==Features.NAMES.size() and Features.NAMES.size()==Features.COSTS.size(),"At least fifteen complete named and priced module definitions are available")
	for kind in Features.KINDS:
		piste.features=[]
		var built:=false
		for fraction in [0.40,0.45,0.50,0.55,0.60]:
			if Features.install(model,int(piste.id),str(kind),fraction,0).ok:built=true;break
		check(built,"Actual installation succeeds for "+str(kind))
		if not built:continue
		check(Features.valid(piste) and piste.points==original,"Module preserves the authored piste and passes validation: "+str(kind))
		var restored:=Resort.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Module survives a checked JSON save: "+str(kind))
		var mesh:ArrayMesh=Art.new().piste_feature(str(kind))
		check(mesh.get_surface_count()==1,"One baked mesh surface for "+str(kind))
		var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var signature:int=hash(vertices)
		check(not meshes.has(signature),"Actual geometry differs from every previous module: "+str(kind))
		meshes[signature]=kind
		check(vertices.size()>0 and vertices.size()<8000,"Bounded geometry vertex budget for "+str(kind))
		var spec:Dictionary=Modules.spec(str(kind))
		var peak:=0.0
		var finite:=true
		for z in range(41):
			for x in [-0.35,0.0,0.35]:
				var height_value:float=Modules.ride_height(str(kind),float(spec.length)*(float(z)/40.0-0.5),float(spec.width)*x)
				finite=finite and is_finite(height_value) and height_value>=0
				peak=maxf(peak,height_value)
		check(finite and peak>0.1,"A finite, genuinely raised riding surface exists for "+str(kind))
		check(Features.height_offset(piste,float(piste.features[0].fraction),0,0)==0.0,"Beginners do not ride the unsuitable raised module: "+str(kind))
		if not Modules.legacy(str(kind)):
			var bounds:=mesh.get_aabb()
			check(bounds.size.x<=float(spec.width)+0.05 and bounds.size.z<=float(spec.length)+0.05,"Mesh fits the placement footprint: "+str(kind))
	check(meshes.size()==Features.KINDS.size(),"Every one of the twenty module types has distinct geometry")
	piste.features=[]
	check(Features.install(model,int(piste.id),"ramp",0.45,0).ok,"Legacy cheap ramp can still be built")
	var cash:float=model.money
	check(Features.install(model,int(piste.id),"kicker_pro",0.45,0,0).ok and model.money<cash-120.0,"Changing a cheap module into a pro module pays the actual upgrade difference")
	var base:Dictionary=model.snapshot()
	for options in [{"scale":2.0},{"rotation":NAN},{"rotation":46.0},{"scale":-1.0}]:
		cash=model.money
		check(not Features.install(model,int(piste.id),"box",0.45,0,0,options).ok and model.money==cash,"Invalid size or rotation is rejected before spending")
	var broken:Dictionary=base.duplicate(true);broken.pistes[0].features[0].condition=-1
	check(not Resort.new().restore(broken).ok,"Invalid saved wear cannot replace a working resort")
	piste.features=[]
	check(not Features.install(model,int(piste.id),"kicker_pro",1.0-18.5/float(piste.length),0).ok,"Long jumps require a complete landing zone beyond the old fixed 18-metre margin")
	check(not Features.install(model,int(piste.id),"halfpipe",0.45,7.0).ok,"A wide module cannot obstruct the piste edge")
	check(Features.install(model,int(piste.id),"kicker_medium",0.45,0,-1,{"rotation":10.0,"scale":1.1}).ok,"Rotation and size are real validated placement parameters")
	var saved:=Resort.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and saved.pistes[0].features[0].rotation==10.0,"Rotation and size survive a checked save")
	var advanced:Dictionary={"kind":"kicker_pro","fraction":0.5,"lateral":0.0,"condition":100.0}
	var test_piste:Dictionary=piste.duplicate(true);test_piste.features=[advanced]
	check(absf(Features.safe_lateral(test_piste,0.5,0,1))>4.0 and Features.height_offset(test_piste,0.5,0,1)==0.0,"Intermediate skiers take a real bypass around a pro obstacle")
	advanced.condition=10.0
	check(absf(Features.safe_lateral(test_piste,0.5,0,2))>4.0 and Features.height_offset(test_piste,0.5,0,2)==0.0,"Worn-out modules are bypassed by experts too")
	piste.features=[]
	var before_cost:float=model.operating_costs(false)
	check(Features.install(model,int(piste.id),"table_jump",0.45,0).ok,"A staffed-resort fixture has a usable actual table jump")
	check(model.operating_costs(false)>before_cost,"Installed snowpark modules create actual daily operating cost")
	model.Ops.enable(model)
	model.operations.auto_groom=false
	check(model.admit_guest(2,"expert"),"An actual expert is admitted for a physical module run")
	var guest:Dictionary=model.guests[0]
	guest.needs.rental=false;guest.needs.lesson=false;guest.needs.hunger=0;guest.needs.warmth=90;guest.needs.energy=90;guest.stay=1000
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind=="ski":guest.leg=index;model._start_leg(guest);break
	guest.traffic_lateral=0.0
	var module:Dictionary=piste.features[0]
	var sales:float=model.report.services
	for tick in range(1500):
		model.advance_minute(false)
		if int(module.get("uses",0))>0:break
	check(int(module.get("uses",0))>0 and float(module.get("condition",100))<100,"Actual skier traversal records use and physical wear")
	check(int(guest.agenda.park_visits)>0,"A real module run fulfils the expert guest's park objective")
	check(model.report.services==sales,"A park-module traversal never invents a shop sale")
	var used:int=module.get("uses",0)
	for frame in range(100):model.guest_position(guest)
	check(int(module.get("uses",0))==used,"Rendering the same skier cannot duplicate usage or wear")
	var maintenance:int=Features.maintenance_cost(module)
	cash=model.money
	check(Features.maintain(model,int(piste.id),0).ok and module.condition==100.0 and is_equal_approx(model.money,cash-maintenance),"Maintenance restores real condition and charges exactly once")
	check(float(model.operations.cost_centres.get("snowpark:%d" % int(piste.id),0))==maintenance,"Maintenance is a real operating expense in the piste cost centre")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Populated guest, usage and maintenance state remain loadable")
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
