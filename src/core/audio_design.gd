extends RefCounted
## 0.26: metadata-only jukebox and spatial zone scoring; no external music URLs.
const Terrain = preload("res://src/core/terrain.gd")
const GENRES := ["off","alpine","techno","hiphop","punk","classical","meditative"]
const GENRE_NAMES := {
	"off":"Musik aus",
	"alpine":"Alpenfolk & Hüttenklang",
	"techno":"Berg-Techno",
	"hiphop":"Snowpark Hip-Hop",
	"punk":"Pisten-Punk",
	"classical":"Winter-Klassik",
	"meditative":"Meditative Bergluft"
}
const ZONES := ["wilderness","piste","lift","village","hotel","restaurant","disco","spa","workshop","rescue"]
const ZONE_NAMES := {
	"wilderness":"Freier Berg", "piste":"Piste", "lift":"Lift", "village":"Dorf",
	"hotel":"Hotel", "restaurant":"Gastronomie", "disco":"Après-Ski",
	"spa":"Wellness", "workshop":"Werkstatt", "rescue":"Bergrettung"
}
const SOUND_MIX := {
	"wilderness":{"wind":0.9,"crowd":0.0,"machinery":0.0,"music":0.0},
	"piste":{"wind":1.0,"crowd":0.12,"machinery":0.0,"music":0.0},
	"lift":{"wind":0.45,"crowd":0.55,"machinery":0.95,"music":0.10},
	"village":{"wind":0.26,"crowd":0.8,"machinery":0.10,"music":0.2},
	"hotel":{"wind":0.12,"crowd":0.5,"machinery":0.08,"music":0.28},
	"restaurant":{"wind":0.05,"crowd":0.86,"machinery":0.13,"music":0.45},
	"disco":{"wind":0.02,"crowd":1.0,"machinery":0.12,"music":1.0},
	"spa":{"wind":0.12,"crowd":0.16,"machinery":0.20,"music":0.20},
	"workshop":{"wind":0.10,"crowd":0.2,"machinery":0.84,"music":0.1},
	"rescue":{"wind":0.32,"crowd":0.14,"machinery":0.70,"music":0.0}
}
const HOTEL := ["hotel","grand_hotel","guesthouse","chalet","apartment","cabin"]
const RESTAURANT := ["restaurant","pizzeria","bar","cocoa","schmarrn","kiosk","lodge"]
const WORKSHOP := ["repair_office","maintenance","watchmaker","craftshop","rental"]
const QUIET := ["spa","pool","fitness"]

static func genre_valid(id: String) -> String:
	return id if id in GENRES else "off"

static func kind_zone(kind: String) -> String:
	if kind=="disco": return "disco"
	if kind=="first_aid": return "rescue"
	if kind in HOTEL: return "hotel"
	if kind in QUIET: return "spa"
	if kind in RESTAURANT: return "restaurant"
	if kind in WORKSHOP: return "workshop"
	return "village"

static func nearby(model: RefCounted, focus: Vector2) -> Dictionary:
	var result := {"kind":"wilderness","distance":INF,"target_id":-1,"weights":SOUND_MIX.wilderness}
	var best := INF
	for building in model.buildings:
		if not bool(building.get("enabled",true)): continue
		var distance:float=Terrain.unpack(building.point).distance_to(focus)
		var zone: String=kind_zone(str(building.kind))
		var priority: float=18.0 if zone in ["disco","hotel","restaurant"] else 12.0
		if distance<=110 and distance-priority<best:
			best=distance-priority
			result={"kind":zone,"distance":distance,"target_id":int(building.id),"weights":SOUND_MIX[zone]}
	for lift in model.lifts:
		if not bool(lift.get("enabled",true)):continue
		var at:Vector2=Geometry2D.get_closest_point_to_segment(focus,Terrain.unpack(lift.bottom),Terrain.unpack(lift.top))
		var distance:float=focus.distance_to(at)
		if distance<=72 and distance+5.0<best:
			best=distance+5
			result={"kind":"lift","distance":distance,"target_id":int(lift.id),"weights":SOUND_MIX.lift}
	for piste in model.pistes:
		if not bool(piste.get("enabled",true)):continue
		var points:Array=piste.points
		for i in range(1,points.size()):
			var at:Vector2=Geometry2D.get_closest_point_to_segment(focus,Terrain.unpack(points[i-1]),Terrain.unpack(points[i]))
			var distance:float=focus.distance_to(at)
			if distance<=80 and distance+8.0<best:
				best=distance+8
				result={"kind":"piste","distance":distance,"target_id":int(piste.id),"weights":SOUND_MIX.piste}
	return result

static func license_policy(provider: String, permission: bool = false) -> bool:
	# Only the built-in synthesis can be played without a documented rights record.
	# External providers are intentionally rejected until explicit permission.
	return provider=="internal" or (provider=="cc0" and permission)

