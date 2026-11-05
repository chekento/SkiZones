extends RefCounted
## In-world ExtraBlatt: only shown when a player's printing press exists.
## Uses actual chronological achievement IDs from the career save.
const AchievementBook = preload("res://src/core/achievement_book.gd")
const Maps = preload("res://src/core/maps.gd")
const Radio = preload("res://src/core/audio_design.gd")
const RUBRICS := ["BERGSPORT", "DORFLEBEN", "WINTERWIRTSCHAFT", "PANORAMA", "AUS DEM RATHAUS"]
const RADIO_CLAIMS := {
	"alpine": "Akustische Gitarren und warme Hüttenklänge für jeden Skitag.",
	"folk_alpine": "HüttenFolk: ehrliche Akustik statt verkleideter Volksmusik.",
	"folk_swedish": "Nordic Frost: kühle Akustik für weite Winterlandschaften.",
	"mountain_sunrise": "Summit Sunrise: der erste Sonnenstrahl über dem Berg.",
	"freeride": "Freeride Pulse: treibende Synthbeats für Ski und Board.",
	"punk": "PistenRock: Gitarren, Rock und Energie für den Snowpark.",
	"hiphop": "Powder Flow: Hip-Hop und Lo-Fi für die nächste Park Line.",
	"techno": "SnowBeat Radio: Techno und House direkt vom Gipfel.",
	"apres": "Alpenglühen FM: House und Funk für die Après-Ski-Nacht.",
	"classical": "Alpine Classic: Piano und Orchester über dem Tal.",
	"meditative": "Mountain Chill: ruhige Klangflächen ohne Hektik.",
	"lodge_lofi": "Lodge Lo-Fi: entspannte Beats am warmen Kamin.",
	"glacier": "Glacier Dreams: eisige Klangflächen und weite Stille.",
	"space": "Cosmic Drift: Synthwave und Space-Ambient am Sternenhimmel.",
	"atmospherics": "Deep Atmospherics: Drones und sphärische Bergnächte.",
	"hotel_lobby": "Hotel Lobby FM: Piano und Jazz nur in der Hotellounge."
}
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
		var motif: int=posmod(id + int(model.day) + int(model.total_rides),HEADLINES.size())
		var rubric: String=RUBRICS[posmod(id + int(model.day),RUBRICS.size())]
		results.append({"id":id,"title":name,"lead":HEADLINES[motif],"detail":goal,
			"rubric":rubric,"byline":"Die Redaktion · Tag %d" % int(model.day),
			"summary":"%s · %d Abfahrten · %d Gäste insgesamt" % [str(Maps.spec(model.map_id).name),int(model.total_rides),int(model.total_guests)]})
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

## Editorial ads are deterministic and based on actual registered station names.
## No sponsorship revenue is invented by displaying an advertisement.
static func radio_spots(model: RefCounted, count: int = 6) -> Array:
	var keys: Array = Radio.GENRES.filter(func(id): return id != "off") + Radio.CONTEXT_STATIONS
	var result: Array = []
	var start: int = posmod(int(model.day)-1,keys.size())
	for i in range(clampi(count,0,keys.size())):
		var key: String=keys[(start+i)%keys.size()]
		result.append({"id":key,"name":str(Radio.GENRE_NAMES.get(key,key)),
			"copy":str(RADIO_CLAIMS.get(key,"Ein Klang für deinen Bergurlaub.")),
			"external":key in Radio.EXTERNAL_STATIONS,
			"exclusive":key in Radio.CONTEXT_STATIONS})
	return result

static func statistics(model: RefCounted) -> Dictionary:
	return {"stands":model.building_count("newsstand"),"sold":sold(model),"revenue":sales(model),"edition":latest(model),
		"district":str(Maps.spec(model.map_id).name),"ads":radio_spots(model),"issue":int(model.day)}

