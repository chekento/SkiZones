extends RefCounted
## In-world ExtraBlatt: only shown when a player's printing press exists.
## Uses actual chronological achievement IDs from the career save.
const AchievementBook = preload("res://src/core/achievement_book.gd")
const LEGACY_NAMES := [
	"Der hundertste Schwung",
	"Buntes Pistennetz",
	"750 Gäste feiern den Berg",
	"Ein Resort mit ausgezeichnetem Ruf"
]
const HEADLINES := [
	"Neuer Meilenstein in den Bergen",
	"Die Redaktion gratuliert dem Skigebiet",
	"Eine bemerkenswerte Wintersaison",
	"Stolz auf das Team am Berg",
	"Ein großer Tag für das Resort"
]

static func press_available(model: RefCounted) -> bool:
	return model.building_count("printing_press")>0

static func latest(model: RefCounted, count: int = 5) -> Array:
	if not press_available(model): return []
	var results: Array=[]
	var all: Array=model.achievements
	for index in range(all.size()-1,-1,-1):
		if results.size()>=clampi(count,0,5): break
		var id: int=int(all[index])
		var entry: Dictionary=AchievementBook.entry(id)
		var name: String=LEGACY_NAMES[id] if id>=0 and id<LEGACY_NAMES.size() else str(entry.get("name",""))
		if name.is_empty(): continue
		var goal: String="Ein historischer Erfolg des Resorts." if id<LEGACY_NAMES.size() else str(entry.goal)
		results.append({"id":id,"title":name,"lead":HEADLINES[results.size()%HEADLINES.size()],"detail":goal})
	return results

static func sold(model: RefCounted) -> int:
	var total:=0
	for building in model.buildings:
		if building.kind=="newsstand": total+=maxi(0,int(building.get("visits",0)))
	return total

static func sales(model: RefCounted) -> float:
	var total:=0.0
	for building in model.buildings:
		if building.kind=="newsstand": total+=maxf(0.0,float(building.get("revenue",0.0)))
	return total

static func statistics(model: RefCounted) -> Dictionary:
	return {"stands":model.building_count("newsstand"),"sold":sold(model),"revenue":sales(model),"edition":latest(model)}
