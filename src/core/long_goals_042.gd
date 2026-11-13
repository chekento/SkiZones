extends RefCounted
## Once per resort: no daily money loop and no payments in free build.
const L=preload("res://src/core/i18n.gd")
const SPECS={
 "visitors":{"name":"Ein Berg für tausend Gäste","target":1000,"reward":2500},
 "rides":{"name":"Fünftausend Abfahrten","target":5000,"reward":3500},
 "happy":{"name":"Fünfhundert glückliche Abschiede","target":500,"reward":3000},
 "profit":{"name":"Zehn wirtschaftliche Betriebstage","target":10,"reward":2500},
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
  "profit":
   var days:Dictionary={}
   for row in model.campaign.get("history",[]):
    if float(row.income)>float(row.costs) and int(row.guests)>0:days[int(row.day)]=true
   return days.size()
 return 0
static func ready(model:RefCounted,id:String)->bool:
 return SPECS.has(id) and id not in model.campaign.get("long_goal_claims",[]) and progress(model,id)>=int(SPECS[id].target)
static func claim(model:RefCounted,id:String)->Dictionary:
 if not ready(model,id):return model._result(false,L.text("Dieses Langzeitziel ist noch offen oder bereits belohnt."))
 var claims:Array=model.campaign.get("long_goal_claims",[]).duplicate()
 claims.append(id);model.campaign.long_goal_claims=claims
 var reward:int=int(SPECS[id].reward) if model.campaign.get("mode","")=="career" else 0
 if reward>0:model.Progression.pay_reward(model,reward)
 return model._result(true,L.text("Langzeitziel abgeschlossen · %d € Bonus") % reward)
