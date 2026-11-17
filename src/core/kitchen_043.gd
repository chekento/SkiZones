extends RefCounted
## Optional practical meals use the existing shared five-task shift ledger.
const L=preload("res://src/core/i18n.gd")
const RECIPES := [
	{"name":"Gemüsesuppe","ingredients":["Gemüse","Zwiebeln","Brühe"],"target":0.56},
	{"name":"Kartoffelpfanne","ingredients":["Kartoffeln","Zwiebeln","Gemüse"],"target":0.64},
	{"name":"Pilzpfanne","ingredients":["Pilze","Zwiebeln","Gemüse"],"target":0.60}
]
static func supported(kind:String)->bool:return kind in ["restaurant","schmarrn"]
static func recipe(building:Dictionary,day:int,step:int)->Dictionary:
	if not supported(str(building.get("kind",""))):return {}
	var result:Dictionary
	if building.kind=="schmarrn":
		result={"name":"Kaiserschmarrn","ingredients":["Eier","Mehl","Milch"],"target":0.62}
	else:result=RECIPES[posmod(int(building.id)+day+step,RECIPES.size())].duplicate(true)
	result["mode"]="cooking"
	result["prompt"]=L.text(str(result.name))
	result["mix"]=building.kind=="schmarrn"
	return result
static func valid_proof(task:Dictionary,input:Variant)->bool:
	if not input is Dictionary:return false
	if not input.get("ingredients") is Array or not input.get("prep") is int:return false
	if not input.get("heat") is float and not input.get("heat") is int:return false
	if input.get("served")!=true or input.prep!=6:return false
	if not is_finite(float(input.heat)) or float(input.heat)<0 or float(input.heat)>1:return false
	var submitted:Array=input.ingredients
	if submitted.size()!=task.ingredients.size():return false
	for ingredient in task.ingredients:
		if submitted.count(ingredient)!=1:return false
	return true
static func score(task:Dictionary,input:Variant)->int:
	if not valid_proof(task,input):return 0
	return roundi(clampf(1.0-absf(float(input.heat)-float(task.target))/0.30,0.0,1.0)*100)
