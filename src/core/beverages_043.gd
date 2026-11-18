extends RefCounted
## Practical mocktails follow actual business offer unlocks and the shared shift ledger.
const Offers=preload("res://src/core/building_offers_035.gd")
const L=preload("res://src/core/i18n.gd")
const RECIPES:=[
	{"name":"Alpen-Mocktail","ingredients":["Apfelsaft","Limettensaft","Mineralwasser"],"garnish":"Limette","target":0.62,"color":"c5b765"},
	{"name":"Beeren-Spritz","ingredients":["Beerensaft","Zitronensaft","Mineralwasser"],"garnish":"Minze","target":0.56,"color":"b8758b"},
	{"name":"Winterorange","ingredients":["Orangensaft","Apfelsaft","Zitronensaft"],"garnish":"Orange","target":0.68,"color":"d19b57"}
]
static func supported(kind:String)->bool:return kind in ["bar","disco"]
static func unlock_level(kind:String)->int:return 3 if kind=="disco" else 2
static func available(building:Dictionary)->bool:
	if not supported(str(building.get("kind",""))):return false
	for offer in Offers.active(str(building.kind),int(building.get("level",1))):
		if offer.id=="mocktail":return true
	return false
static func recipe(building:Dictionary,day:int,step:int)->Dictionary:
	if not available(building):return {}
	var order:Dictionary=RECIPES[posmod(int(building.id)+day+step,RECIPES.size())].duplicate(true)
	order["mode"]="mixing";order["prompt"]=L.text(str(order.name))
	return order
static func valid_proof(task:Dictionary,input:Variant)->bool:
	if not input is Dictionary:return false
	if not input.get("ingredients") is Array or not input.get("shakes") is int:return false
	if not input.get("fill") is float and not input.get("fill") is int:return false
	if input.get("served")!=true or input.shakes!=6 or input.get("garnish")!=task.garnish:return false
	if not is_finite(float(input.fill)) or float(input.fill)<0 or float(input.fill)>1:return false
	if input.ingredients.size()!=task.ingredients.size():return false
	for ingredient in task.ingredients:
		if input.ingredients.count(ingredient)!=1:return false
	return true
static func score(task:Dictionary,input:Variant)->int:
	if not valid_proof(task,input):return 0
	return roundi(clampf(1.0-absf(float(input.fill)-float(task.target))/0.30,0,1)*100)
