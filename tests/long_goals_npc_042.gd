extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Goals=preload("res://src/core/long_goals_042.gd")
const Habits=preload("res://src/core/guest_habits_042.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func run()->void:
 var model:=Resort.new();model.new_game(true);model.campaign.mode="career"
 var money:float=model.money
 check(not Goals.claim(model,"happy").ok and model.money==money,"Unfulfilled milestone cannot create cash")
 model.campaign.happy=500
 var reward_before:float=model.report.rewards
 check(Goals.claim(model,"happy").ok and model.money==money+3000 and model.report.rewards==reward_before+3000,"Actual reward enters cash and the reward ledger exactly once")
 var after:Dictionary=model.snapshot()
 check(not Goals.claim(model,"happy").ok and model.snapshot()==after,"Repeated claim cannot duplicate any state or money")
 var restored:=Resort.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(after))).ok and not Goals.ready(restored,"happy"),"Claim protection survives a checked save and reload")
 for value in [["happy","happy"],["unknown"],"happy",[1]]:
  var broken:Dictionary=after.duplicate(true);broken.campaign.long_goal_claims=value
  var before:Dictionary=restored.snapshot()
  check(not restored.restore(broken).ok and restored.snapshot()==before,"Malformed goal claims reject atomically")
 model.campaign.history=[{"day":1,"income":100.0,"costs":90.0,"rewards":0,"guests":20}]
 check(Goals.ready(model,"first_profit") and not Goals.ready(model,"profit"),"First economic goal is available on day one")
 var early_cash:float=model.money
 check(Goals.claim(model,"first_profit").ok and model.money==early_cash+1000,"First profitable day pays an early 1000-euro accomplishment")
 model.campaign.history.append({"day":2,"income":100.0,"costs":90.0,"rewards":0,"guests":20})
 check(not Goals.ready(model,"profit"),"Second stage waits for three genuine profitable days")
 model.campaign.history.append({"day":3,"income":100.0,"costs":90.0,"rewards":0,"guests":20})
 check(Goals.claim(model,"profit").ok and model.money==early_cash+2500,"Third profitable day completes the unchanged economic reward budget")
 model.campaign.long_goal_claims=["happy"]
 early_cash=model.money
 check(Goals.claim(model,"profit").ok and model.money==early_cash+2500 and not Goals.ready(model,"first_profit"),"Late collection settles both stages once without losing the early bonus")
 model.campaign.long_goal_claims=["profit"]
 check(not Goals.ready(model,"first_profit"),"Legacy fully rewarded economic milestone cannot gain a second retroactive payout")
 model.campaign.history=[]
 for day in range(1,11):model.campaign.history.append({"day":day,"income":100.0,"costs":110.0,"rewards":99999,"guests":20})
 check(Goals.progress(model,"profit")==0,"Reward-funded losses do not qualify as profitable operations")
 for row in model.campaign.history:row.costs=90.0
 check(Goals.progress(model,"profit")==10,"Ten actual profitable report rows qualify")
 model.campaign.history.append(model.campaign.history[0].duplicate())
 check(Goals.progress(model,"profit")==10,"Duplicate report dates cannot inflate goal progress")
 model.campaign.season_reward_day=83
 check(Goals.progress(model,"winters")==2,"Three winters are not completed early")
 model.campaign.season_reward_day=84
 check(Goals.ready(model,"winters"),"Third finalized winter qualifies")
 var maximum:=0
 for id in Goals.SPECS:maximum+=int(Goals.SPECS[id].reward)
 check(maximum==18500,"Lifetime reward budget is bounded")
 model.campaign.mode="free";money=model.money
 check(Goals.claim(model,"winters").ok and model.money==money,"Sandbox can record an accomplishment without fictitious cash")
 var guest:Dictionary={"id":17,"years":39,"age":400,"runs":2,"needs":{"energy":90},"service_history":{}}
 var before_guest:Dictionary=guest.duplicate(true)
 var offsets:Dictionary={}
 var tastes:Dictionary={}
 for id in range(40):
  var sample:Dictionary=guest.duplicate(true);sample.id=id
  var profile:Dictionary=Habits.profile(sample)
  offsets[profile.break_offset]=true;tastes[profile.taste]=true
 check(offsets.size()>10 and tastes.size()==4,"NPC population has varied stable break times and all four leisure tastes")
 check(Habits.profile(guest)==Habits.profile(guest),"Personal choices remain deterministic")
 var other:Dictionary=guest.duplicate(true);guest.party_id=9;other.party_id=9;other.id=999
 check(Habits.profile(guest)==Habits.profile(other),"Members of a party share break preferences")
 guest.erase("party_id")
 guest.service_history={"spa":360}
 check(Habits.bonus(guest,"souvenir",950)==0,"Recent wellness prevents an immediate different leisure purchase")
 guest.service_history={};guest.needs.energy=10
 check(Habits.bonus(guest,"disco",1250)==0,"Exhausted guests are not tempted into nightlife")
 guest.needs.energy=90;guest.years=15
 check(Habits.bonus(guest,"bar",1200)==0 and Habits.bonus(guest,"disco",1250)==0,"Personal variation cannot bypass the minors gate")
 guest=before_guest.duplicate(true)
 var snapshot:Dictionary=model.snapshot()
 for minute in range(480,1400,20):
  for kind in ["restaurant","souvenir","spa","bar","shelter"]:Habits.bonus(guest,kind,minute)
 check(guest==before_guest and model.snapshot()==snapshot,"Preference scoring never spends money, changes needs or mutates saves")
 print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
