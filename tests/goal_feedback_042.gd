extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Goals=preload("res://src/core/long_goals_042.gd")
const Feed=preload("res://src/ui/goal_notice_feed_042.gd")
const Banner=preload("res://src/ui/achievement_toast.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var model:=Resort.new();model.new_game(true)
	var feed:=Feed.new()
	check(feed.collect(model).is_empty() and Goals.pending(model).is_empty(),"Unfinished goals create neither banner nor claimable cash")
	model.campaign.happy=500
	var before:Dictionary=model.snapshot()
	var messages:Array=feed.collect(model)
	check(messages.size()==1 and messages[0].kind=="goal" and not messages[0].has("reward"),"Earned goal creates a distinct eligibility notice without pretending to pay money")
	check(model.snapshot()==before,"Notification collection never mutates finances or saved progress")
	check(feed.collect(model).is_empty(),"Repeated HUD updates do not repeat a goal notice")
	model.total_guests=1000;model.total_rides=5000
	messages=feed.collect(model)
	check(messages.size()==1 and Goals.pending(model).size()==3,"Simultaneous new milestones are batched into one banner")
	check(Goals.pending_reward(model)==9000 and "9000" in messages[0].detail,"Notice and office agree on all currently available real rewards")
	model.campaign.happy=499;feed.collect(model);model.campaign.happy=500
	check(feed.collect(model).is_empty(),"A fluctuating ready condition cannot spam the notice channel")
	var money:float=model.money
	var rewards:float=model.report.rewards
	var settled:Dictionary=Goals.claim_all(model)
	check(settled.ok and settled.count==3 and settled.reward==9000,"One explicit action settles all three earned goals")
	check(model.money==money+9000 and model.report.rewards==rewards+9000,"Bulk claim credits the real cash and reward ledgers exactly once")
	before=model.snapshot()
	check(not Goals.claim_all(model).ok and model.snapshot()==before,"Double activation cannot duplicate a bulk payout")
	check(Goals.pending_reward(model)==0 and feed.collect(model).is_empty(),"Collected goals leave neither pending cash nor new ready notices")
	var copy:=Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(before))).ok and not Goals.claim_all(copy).ok,"Bulk claim guards survive checked JSON restoration")
	var early:=Resort.new();early.new_game(true);early.campaign.long_goal_profit_days=3
	check(Goals.pending_reward(early)==2500,"Both early economic stages sum to the fixed 2500-euro budget")
	settled=Goals.claim_all(early)
	check(settled.ok and settled.reward==2500 and settled.count==2,"Bulk action settles first and third profitable-day stages together")
	var old_campaign:Dictionary=early.campaign
	early.campaign=old_campaign.duplicate(true);early.campaign.long_goal_claims=[]
	check(feed.collect(early).size()==1 and feed.collect(early).is_empty(),"Loading another campaign resets session notices once even on the same model")
	var other:=Resort.new();other.new_game(true);other.campaign.long_goal_profit_days=3
	check(feed.collect(other).size()==1,"Independent resorts never inherit another resort's notice suppression")
	other.campaign.mode="free";money=other.money;rewards=other.report.rewards
	check(Goals.pending_reward(other)==0,"Free build never advertises a cash prize")
	settled=Goals.claim_all(other)
	check(settled.ok and settled.reward==0 and other.money==money and other.report.rewards==rewards,"Sandbox bulk completion records goals without fictitious money")
	var maximum:=Resort.new();maximum.new_game(true)
	maximum.total_guests=1000;maximum.total_rides=5000;maximum.campaign.happy=500
	maximum.campaign.long_goal_profit_days=3;maximum.campaign.season_reward_day=84
	maximum.operations.staff=[]
	for i in range(8):maximum.operations.staff.append({"qualification":2,"assignment":"building:1"})
	check(Goals.pending(maximum).size()==7 and Goals.pending_reward(maximum)==18500,"All seven ready milestones retain the exact lifetime cash ceiling")
	settled=Goals.claim_all(maximum)
	check(settled.reward==18500 and Goals.pending(maximum).is_empty(),"Collecting the complete catalogue cannot exceed its economic budget")
	check(Banner.priority("warning")>Banner.priority("goal") and Banner.priority("goal")>Banner.priority("music"),"Goal notices preserve urgent warnings and outrank station changes")
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
