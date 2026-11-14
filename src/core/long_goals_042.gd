extends RefCounted
## Once per resort: no daily money loop and no payments in free build.
const L=preload("res://src/core/i18n.gd")
const SPECS={
 "visitors":{"name":"Ein Berg für tausend Gäste","target":1000,"reward":2500},
 "rides":{"name":"Fünftausend Abfahrten","target":5000,"reward":3500},
 "happy":{"name":"Fünfhundert glückliche Abschiede","target":500,"reward":3000},
 "first_profit":{"name":"Der erste wirtschaftliche Betriebstag","target":1,"reward":1000},
 "profit":{"name":"Drei wirtschaftliche Betriebstage","target":3,"reward":1500},
 "team":{"name":"Acht qualifizierte Fachkräfte","target":8,"reward":2000},
 "winters":{"name":"Drei abgeschlossene Winter","target":3,"reward":5000}
}
static func valid(value:Variant)->bool:
 if not value is Array or value.size()>SPECS.size():return false
 var seen:Array=[]
 for id in value:
  if not id is String or not SPECS.has(id) or id in seen:return false
  seen.append(id)
 return true
static func progress(model:RefCounted,id:String)->int:
 match id:
  "visitors":return int(model.total_guests)
  "rides":return int(model.total_rides)
  "happy":return int(model.campaign.get("happy",0))
  "team":return model.operations.staff.filter(func(p):return int(p.qualification)>=2 and str(p.assignment)!="reserve").size()
  "winters":return floori(float(model.campaign.get("season_reward_day",0))/28.0)
  "first_profit","profit":
   var days:Dictionary={}
   for row in model.campaign.get("history",[]):
    if float(row.income)>float(row.costs) and int(row.guests)>0:days[int(row.day)]=true
   return maxi(int(model.campaign.get("long_goal_profit_days",0)),days.size())
 return 0
static func ready(model:RefCounted,id:String)->bool:
 if id=="first_profit" and "profit" in model.campaign.get("long_goal_claims",[]):return false
 return SPECS.has(id) and id not in model.campaign.get("long_goal_claims",[]) and progress(model,id)>=int(SPECS[id].target)
static func claim(model:RefCounted,id:String)->Dictionary:
 if not ready(model,id):return model._result(false,L.text("Dieses Langzeitziel ist noch offen oder bereits belohnt."))
 var claims:Array=model.campaign.get("long_goal_claims",[]).duplicate()
 var amount:int=int(SPECS[id].reward)
 if id=="profit" and "first_profit" not in claims:
  claims.append("first_profit");amount+=int(SPECS.first_profit.reward)
 claims.append(id);model.campaign.long_goal_claims=claims
 var reward:int=amount if model.campaign.get("mode","")=="career" else 0
 if reward>0:model.Progression.pay_reward(model,reward)
 var result:Dictionary=model._result(true,L.text("Langzeitziel abgeschlossen · %d € Bonus") % reward)
 result.reward=reward
 return result

static func pending(model:RefCounted)->Array:
 var result:Array=[]
 for id in SPECS:
  if ready(model,id):result.append(id)
 return result

static func pending_reward(model:RefCounted)->int:
 if model.campaign.get("mode","")!="career":return 0
 var amount:=0
 for id in pending(model):amount+=int(SPECS[id].reward)
 return amount

static func claim_all(model:RefCounted)->Dictionary:
 var count:=0
 var amount:=0
 for id in pending(model):
  var settled:Dictionary=claim(model,id)
  if settled.ok:count+=1;amount+=int(settled.reward)
 if count==0:return model._result(false,L.text("Noch keine einlösbaren Ziele."))
 var result:Dictionary=model._result(true,L.text("%d Ziele abgeschlossen · %d € Bonus") % [count,amount])
 result.reward=amount;result.count=count
 return result

## Ready accomplishments first, then early active goals; completed ones last.
static func display_order(model:RefCounted)->Array:
 var ids:Array=["first_profit","profit","visitors","rides","happy","team","winters"]
 var result:Array=[]
 var claims:Array=model.campaign.get("long_goal_claims",[])
 for phase in [0,1,2]:
  for id in ids:
   var completed:bool=id in claims or (id=="first_profit" and "profit" in claims)
   var category:int=2 if completed else 0 if ready(model,id) else 1
   if category==phase:result.append(id)
 return result
