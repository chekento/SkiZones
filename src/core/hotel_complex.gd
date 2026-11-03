extends RefCounted
## Existing standalone businesses form a strictly linear hotel chain on the map.
## A module keeps its own staff, operating revenue and save identity.
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
const MODULES := ["pool","spa","fitness","restaurant","pizzeria","cocoa","bar","souvenir","watchmaker","craftshop"]
const MAX_MODULES := 8
const MAX_EDGE_GAP := 24.0
const LINK_COST := 4500

static func _id(value: Variant) -> bool:
	return value is int and value > 0 and value <= 100000000

static func is_module(building: Dictionary) -> bool:
	return str(building.get("kind","")) in MODULES

static func _footprint_gap(a: Dictionary, b: Dictionary) -> float:
	var center_a := Terrain.unpack(a.point)
	var center_b := Terrain.unpack(b.point)
	var half_a: Vector2 = Foot.building_size(a)*0.5
	var half_b: Vector2 = Foot.building_size(b)*0.5
	var delta := (center_a-center_b).abs()
	return Vector2(maxf(0.0,delta.x-half_a.x-half_b.x),maxf(0.0,delta.y-half_a.y-half_b.y)).length()

static func ordered(buildings: Array, hotel_id: int) -> Array:
	var result: Array = []
	var parent := hotel_id
	for slot in range(1,MAX_MODULES+1):
		var found: Dictionary = {}
		for building in buildings:
			var attachment: Dictionary = building.get("hotel_attachment",{})
			if int(attachment.get("hotel_id",-1)) == hotel_id and int(attachment.get("slot",-1)) == slot and int(attachment.get("after_id",-1)) == parent:
				found=building
				break
		if found.is_empty(): break
		result.append(found)
		parent=int(found.id)
	return result

static func check(model: RefCounted, hotel_id: int, module_id: int) -> Dictionary:
	var hotel: Dictionary = model.asset(hotel_id)
	var module: Dictionary = model.asset(module_id)
	if hotel.is_empty() or not Catalog.LODGING.has(str(hotel.get("kind",""))) or not hotel.enabled:
		return {"ok":false,"message":"Ein bestehendes, geöffnetes Hotel auswählen."}
	if module.is_empty() or not is_module(module) or not module.enabled or module.has("hotel_attachment"):
		return {"ok":false,"message":"Ein freies, geeignetes Dorfgebäude auswählen."}
	var chain := ordered(model.buildings,hotel_id)
	if chain.size() >= MAX_MODULES:
		return {"ok":false,"message":"Dieser Hotelkomplex hat bereits acht Module."}
	var previous: Dictionary = hotel if chain.is_empty() else chain.back()
	var gap := _footprint_gap(previous,module)
	if gap > MAX_EDGE_GAP:
		return {"ok":false,"message":"Das nächste Modul muss neben dem Ende der Hotelkette stehen (maximal 24 m Fassadenabstand)."}
	for other in model.buildings:
		if other.has("hotel_attachment") and int(other.hotel_attachment.get("hotel_id",-1)) == hotel_id and int(other.id) == module_id:
			return {"ok":false,"message":"Gebäude ist bereits verbunden."}
	return {"ok":true,"after_id":int(previous.id),"slot":chain.size()+1,"cost":LINK_COST,"message":"Modul verbindet sich mit dem Hotelkomplex."}

static func attach(model: RefCounted, hotel_id: int, module_id: int) -> Dictionary:
	var test := check(model,hotel_id,module_id)
	if not test.ok: return test
	if model.money < LINK_COST: return {"ok":false,"message":"Für den Verbindungsgang fehlen 4.500 €."}
	# All checks complete before state and budget change.
	var module: Dictionary = model.asset(module_id)
	module.hotel_attachment={"hotel_id":hotel_id,"after_id":int(test.after_id),"slot":int(test.slot)}
	model.money -= LINK_COST
	model.report.investments = float(model.report.get("investments",0.0)) + LINK_COST
	model._invalidate()
	return {"ok":true,"message":"Eigenständiger Betrieb ist jetzt Modul %d des Hotelkomplexes." % int(test.slot)}

static func detach(model: RefCounted, hotel_id: int, module_id: int) -> Dictionary:
	var chain := ordered(model.buildings,hotel_id)
	if chain.is_empty() or int(chain.back().id) != module_id:
		return {"ok":false,"message":"Nur das letzte Modul kann entfernt werden, damit die lineare Verbindung erhalten bleibt."}
	chain.back().erase("hotel_attachment")
	model._invalidate()
	return {"ok":true,"message":"Modul getrennt. Das Geschäft bleibt eigenständig bestehen."}

static func valid_all(buildings: Array) -> bool:
	var by_id := {}
	for building in buildings:
		if not _id(building.get("id")) or by_id.has(building.id): return false
		by_id[building.id]=building
	var hotel_ids := {}
	for building in buildings:
		if not building.has("hotel_attachment"): continue
		var a: Variant=building.hotel_attachment
		if not a is Dictionary or a.size()!=3 or not is_module(building): return false
		for key in ["hotel_id","after_id","slot"]:
			if not _id(a.get(key)): return false
		if int(a.slot) > MAX_MODULES or not by_id.has(a.hotel_id) or not by_id.has(a.after_id): return false
		if not Catalog.LODGING.has(str(by_id[a.hotel_id].kind)): return false
		if int(a.hotel_id) == int(building.id) or int(a.after_id) == int(building.id): return false
		hotel_ids[a.hotel_id]=true
	for hotel_id in hotel_ids:
		var chain := ordered(buildings,int(hotel_id))
		var expected := 0
		for building in buildings:
			if int(building.get("hotel_attachment",{}).get("hotel_id",-1)) == int(hotel_id): expected+=1
		if chain.size()!=expected: return false
		var previous: Dictionary=by_id[hotel_id]
		for module in chain:
			if _footprint_gap(previous,module) > MAX_EDGE_GAP + 0.01: return false
			previous=module
	return true
