extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Training=preload("res://src/core/staff_training_042.gd")
const Pairs=preload("res://src/core/memory_pairs_042.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func finish(model:RefCounted,session:Dictionary,correct:bool=true)->Dictionary:
	var result:Dictionary={}
	for i in range(3):
		var task:Dictionary=Training.challenge(model,session)
		if task.is_empty():return {}
		result=Training.answer(model,session,int(task.answer) if correct else (int(task.answer)+1)%3)
	return result
func run()->void:
	var model:=Resort.new();model.new_game(true);model.money=5000000;model.campaign.mode="career";model.Ops.enable(model)
	var original_sales:float=model.report.services
	check(Training.CASES.size()==model.Ops.ROLES.size(),"Every real profession has a specific practical scenario")
	for role in model.Ops.ROLES:
		check(model.Ops.hire(model,str(role),"reserve","day",true).ok,"Real employee hired for training: "+str(role))
		var employee:Dictionary=model.operations.staff.back()
		var before:float=model.money
		var session:Dictionary=Training.start(model,int(employee.id))
		var replay:Dictionary=session.duplicate(true)
		check(session.ok and model.money==before-90,"Course charges one real fee: "+str(role))
		check(Training.challenge(model,session).prompt==Training.CASES[role][0],"Profession-specific first task: "+str(role))
		check(not Training.answer(model,session,"invalid").ok and session.step==0,"Invalid input cannot advance a course: "+str(role))
		var result:=finish(model,session)
		check(result.get("finished",false) and result.earned==36 and employee.training.xp==36,"Three earned decisions award actual employee experience: "+str(role))
		check(finish(model,replay).is_empty() and not Training.answer(model,session,0).ok,"Replayed or finished course cannot award again: "+str(role))
	var employee:Dictionary=model.operations.staff.back()
	var wrong:=Training.start(model,int(employee.id))
	check(finish(model,wrong,false).earned==0 and employee.training.xp==36,"Wrong decisions do not grant qualification experience")
	var cash:float=model.money
	check(not Training.start(model,int(employee.id)).ok and model.money==cash,"Daily course limit rejects before charging")
	for day in range(2,5):
		model.day=day
		for attempt in range(2):finish(model,Training.start(model,int(employee.id)))
	check(employee.training.xp==252 and employee.qualification==3,"Multiple real courses earn qualification thresholds over several days")
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored:=Resort.new()
	check(restored.restore(snapshot).ok and Training.person(restored,int(employee.id)).qualification==3,"Qualifications and course history survive a checked save")
	for field in ["xp","day","attempts","best","serial","settled"]:
		var broken:Dictionary=snapshot.duplicate(true);broken.operations.staff.back().training[field]=-1
		var stable:Dictionary=restored.snapshot()
		check(not restored.restore(broken).ok and restored.snapshot()==stable,"Malformed training state rejects atomically: "+field)
	var serial:Dictionary=employee.training.duplicate(true);serial.settled=int(serial.serial)+1
	check(not Training.valid(serial),"Invalid course settlement cannot be loaded")
	model.day+=1
	var stale:Dictionary=Training.start(model,int(employee.id));employee.assignment="building:999999"
	check(Training.challenge(model,stale).is_empty(),"Reassignment invalidates an active course")
	employee.assignment="reserve"
	model.campaign.mode="free";cash=model.money
	check(Training.start(model,int(employee.id)).ok and model.money==cash,"Free build courses spend no hidden currency")
	check(model.report.services==original_sales and model.total_guests==0,"Employee training creates no invented guest sales")
	# Exercise the actual service-duty ledger, including the wrong shift.
	var restaurant:Dictionary={"id":model.next_id,"kind":"restaurant","point":[40.0,40.0],"enabled":true,"level":1}
	model.next_id+=1;model.buildings.append(restaurant);model._invalidate()
	model.Ops.fill_building(model,int(restaurant.id),true)
	var staff:Array=model.operations.staff.filter(func(p):return p.assignment=="building:%d" % int(restaurant.id))
	model.minute=600;model.Ops.refresh_duty(model)
	var efficiency:float=model.Ops.service_efficiency(model,restaurant)
	for member in staff:member.qualification=3
	model.Ops.refresh_duty(model)
	check(model.Ops.service_efficiency(model,restaurant)>efficiency,"Qualified on-duty restaurant staff increase actual service efficiency")
	for member in staff:member.shift="night"
	model.Ops.refresh_duty(model)
	check(model.Ops.service_efficiency(model,restaurant)==1.0,"Off-duty trained employees cannot create a service bonus")
	var workshop:Dictionary={"id":model.next_id,"kind":"repair_office","point":[110.0,80.0],"enabled":true,"level":1}
	model.next_id+=1;model.buildings.append(workshop);model._invalidate()
	model.Ops.fill_building(model,int(workshop.id),true)
	model.lifts[0].fault="mechanical"
	check(model.Ops.repair(model,int(model.lifts[0].id),int(workshop.id)).ok,"Actual repair is commissioned at a staffed workshop")
	var repair:Dictionary=model.operations.repairs.back()
	var remaining:float=repair.remaining
	model.Ops.tick(model)
	var baseline:float=remaining-float(repair.remaining)
	for member in model.operations.staff:
		if member.assignment=="building:%d" % int(workshop.id):member.qualification=3
	remaining=repair.remaining
	model.Ops.tick(model)
	check(remaining-float(repair.remaining)>baseline and remaining-float(repair.remaining)<=1.15,"Qualified on-duty technicians speed up the actual work order within its cap")
	for member in model.operations.staff:
		if member.assignment=="building:%d" % int(workshop.id):member.break_until=model.Ops.clock(model)+30
	remaining=repair.remaining;model.Ops.tick(model)
	check(repair.remaining==remaining,"A trained workshop cannot repair without its present team")
	model.campaign.mode="career";model.money=0;model.day+=1
	var no_budget:Dictionary=employee.get("training",{}).duplicate(true)
	check(not Training.start(model,int(employee.id)).ok and employee.training==no_budget,"Insufficient budget cannot consume a training attempt")
	# Isolated arcade rules: no hidden rewards and no third-card peeking.
	var rng:=RandomNumberGenerator.new();rng.seed=42
	for count in [4,6,8]:
		var state:=Pairs.new_match(count,rng)
		check(state.deck.size()==count*2,"Real shuffled deck for %d pairs" % count)
		var frequencies:Dictionary={}
		for symbol in state.deck:frequencies[symbol]=int(frequencies.get(symbol,0))+1
		check(frequencies.values().all(func(n):return n==2),"Every symbol has exactly two cards")
		var first:int=0;var other:int=-1
		for i in range(1,state.deck.size()):
			if state.deck[i]!=state.deck[0]:other=i;break
		check(Pairs.flip(state,first) and not Pairs.flip(state,first) and Pairs.flip(state,other),"Two distinct valid flips create a move")
		check(state.moves==1 and not Pairs.flip(state,(other+1)%state.deck.size()),"A mismatch locks further peeking until covered")
		Pairs.cover(state)
		check(state.open.is_empty() and not Pairs.flip(state,-1),"Covering a mismatch retains score and rejects invalid cells")
		for symbol in range(count):
			for i in range(state.deck.size()):
				if state.deck[i]==symbol:Pairs.flip(state,i)
		check(state.done and state.moves==count+1 and state.matched.size()==count*2,"Finding all actual pairs finishes the match")
		check(not Pairs.flip(state,0),"Completed match cannot accept further moves")
	check(Pairs.new_match(7,rng).is_empty(),"Unsupported game size is rejected")

	model.money=180;model.day+=1
	for attempt in range(2):finish(model,Training.start(model,int(employee.id)),false)
	var practice_before:String=JSON.stringify(model.snapshot())
	check(not Training.start(model,int(employee.id)).ok,"Paid qualification course remains capped after two attempts")
	var practice:Dictionary=Training.start(model,int(employee.id),true)
	check(practice.ok and practice.practice,"Free practice remains available without money after the daily limit")
	var exercise:Dictionary=finish(model,practice)
	check(exercise.finished and exercise.earned==0 and not exercise.promoted,"Perfect practice reports quality without awarding qualifications")
	check(JSON.stringify(model.snapshot())==practice_before,"Practice changes no money, XP, motivation, attempts, duty or saved resort state")
	check(not Training.answer(model,practice,0).ok,"Finished practice cannot accept another answer")
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
