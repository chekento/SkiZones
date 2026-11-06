extends SceneTree
## Public Dixi-WC is an independent module, never a hotel add-on.
const Resort=preload("res://src/core/resort.gd")
const WC=preload("res://src/core/public_wc.gd")
const Needs=preload("res://src/core/guest_needs.gd")
const Progression=preload("res://src/core/progression.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run() -> void:
	var model:=Resort.new()
	model.new_game(true,20261106)
	model.campaign.mode="free"
	model.money=2500000
	check(WC.KINDS.size()==5 and WC.is_public("wc_dixi") and not WC.is_public("hotel"),"Five independent public WC assets, hotel excluded")
	check(Progression.branch_for("sanitation").id=="sanitation","Sanitation has a separate tech tree")
	var bathroom:Dictionary={}
	for z in range(160,440,24):
		for x in range(65,480,24):
			if model.build_building("wc_dixi",Vector2(x,z)).ok:
				bathroom=model.buildings[-1]
				break
		if not bathroom.is_empty():break
	check(not bathroom.is_empty(),"Inexpensive blue Dixi is physically buildable")
	if bathroom.is_empty():quit(1);return
	var info:Dictionary=WC.status(model,bathroom)
	check(info.ready and int(info.units)==1 and float(info.hygiene)==100 and float(info.fill)==0,"New public WC starts usable, with own tank and hygiene")
	WC.visit(model,bathroom,5)
	info=WC.status(model,bathroom)
	check(int(info.visits)==5 and float(info.fill)>0 and float(info.hygiene)<100,"Real visitors fill public tank and use hygiene")
	var drained:Dictionary=WC.action(model,int(bathroom.id),"empty")
	check(drained.ok and float(WC.status(model,bathroom).fill)==0,"Paid tank disposal resets waste capacity")
	var cleaned:Dictionary=WC.action(model,int(bathroom.id),"clean")
	check(cleaned.ok and float(WC.status(model,bathroom).hygiene)==100,"Separate paid cleaning restores hygiene")
	check(WC.action(model,int(bathroom.id),"winterize").ok and WC.status(model,bathroom).winterized,"Public WC frost protection is a separate upgrade")
	var guest:Dictionary={"id":801,"age":20,"ability":1,"spent":false,"phase":"walk","leg":0,"route":{"legs":[]},"needs":{"hunger":10,"warmth":80,"energy":75,"joy":85,"rental":false,"lesson":false,"bladder":88.0,"bowel":17.0},"service_history":{}}
	check(Needs.valid(guest) and Needs.urgent(guest),"Bladder urgency creates a real physiological need")
	check(Needs.utility(guest,"wc_dixi")>60 and Needs.utility(guest,"restaurant")>0,"Independent Dixi and built-in restaurant bathroom serve the need")
	Needs.complete(guest,"wc_dixi")
	check(float(guest.needs.bladder)==0.0 and float(guest.needs.bowel)==0.0,"Dixi visit resolves bladder and bowel needs")
	guest.needs.bladder=24.0
	Needs.complete(guest,"bar")
	check(float(guest.needs.bladder)>24.0,"Drinks increase urination demand")
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored:=Resort.new()
	check(restored.restore(snapshot).ok and int(WC.status(restored,restored.asset(int(bathroom.id))).visits)==5,"New independent WC data survive actual save restore")
	var broken:Dictionary=snapshot.duplicate(true)
	for building in broken.buildings:
		if int(building.id)==int(bathroom.id):
			building.wc_public.hygiene=-3
			break
	check(not Resort.new().restore(broken).ok,"Corrupted public sanitation value rejected safely")
	var hotel:Dictionary={"kind":"hotel","wc_public":{"version":1}}
	check(not WC.valid(hotel),"Hotels cannot attach public portable-toilet state")
	model.day+=1
	WC.daily(model,bathroom)
	check(float(WC.status(model,bathroom).hygiene)<100 and WC.status(model,bathroom).winterized,"Frost-protected Dixi retains independent daily maintenance")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
