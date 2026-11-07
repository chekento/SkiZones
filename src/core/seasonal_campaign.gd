extends RefCounted
## Deterministic campaign rotation; artwork is a separately replaceable asset.
## Never randomize every frame: billboards stay stable until the calendar changes.
const Calendar = preload("res://src/core/annual_festival.gd")
const VARIANTS := {
	"preview": [
		{"title":"WINTERWUNDER","subtitle":"Der Advent kommt ins Bergdorf","date":"01. DEZ","detail":"24 Türchen · 24 Überraschungen","image":"res://assets/seasonal/christmas_winterwunder_01.webp","motif":"trees"},
		{"title":"ADVENT AM BERG","subtitle":"Schneeglanz und Vorfreude","date":"01.–24. DEZ","detail":"Entdecke den SkiZones-Adventskalender","image":"res://assets/seasonal/christmas_advent_02.webp","motif":"village"},
		{"title":"FESTLICHE PISTEN","subtitle":"Dein Winter. Dein Resort.","date":"AB 01. DEZ","detail":"Feiere den Dezember in SkiZones","image":"res://assets/seasonal/christmas_pistes_03.webp","motif":"stars"}
	],
	"advent": [
		{"title":"24 WINTERMOMENTE","subtitle":"Der Adventskalender ist geöffnet","date":"01.–24. DEZ","detail":"Jeden Tag ein neues Türchen","image":"res://assets/seasonal/christmas_winterwunder_01.webp","motif":"trees"},
		{"title":"ALPENLICHTER","subtitle":"Ein Dorf voller Weihnachtszauber","date":"DEZEMBER","detail":"Erkunde die festlich geschmückten Hütten","image":"res://assets/seasonal/christmas_advent_02.webp","motif":"village"},
		{"title":"WINTERFEST","subtitle":"Pulverschnee und Lichterglanz","date":"01.–24. DEZ","detail":"Advent in deinem Skiresort","image":"res://assets/seasonal/christmas_pistes_03.webp","motif":"stars"}
	],
	"christmas": [
		{"title":"FROHE WEIHNACHTEN","subtitle":"Feiertage zwischen den Gipfeln","date":"25.–30. DEZ","detail":"Lichter, Schnee und Bergmagie","image":"res://assets/seasonal/christmas_winterwunder_01.webp","motif":"trees"},
		{"title":"WINTERLICHT","subtitle":"Das ganze Dorf feiert mit","date":"DEZEMBER","detail":"Weihnachtliche Momente in SkiZones","image":"res://assets/seasonal/christmas_advent_02.webp","motif":"village"}
	],
	"new_year_eve": [
		{"title":"SILVESTER AM BERG","subtitle":"Die längste Nacht des Winters","date":"31. DEZ","detail":"Countdown · Musik · Feuerwerk","image":"res://assets/seasonal/new_year_countdown_01.webp","motif":"fireworks"},
		{"title":"GIPFELGLANZ","subtitle":"Gemeinsam ins neue Jahr","date":"31.12. · 00:00","detail":"Silvesterparty im SkiZones-Resort","image":"res://assets/seasonal/new_year_mountain_02.webp","motif":"midnight"}
	],
	"new_year": [
		{"title":"FROHES NEUES JAHR","subtitle":"Ein frischer Start am Berg","date":"01. JAN","detail":"Neue Saison · neue Abenteuer","image":"res://assets/seasonal/new_year_countdown_01.webp","motif":"fireworks"},
		{"title":"NEUJAHRSGLANZ","subtitle":"Willkommen im neuen Bergjahr","date":"01. JAN","detail":"Schnee, Sonne und neue Pläne","image":"res://assets/seasonal/new_year_mountain_02.webp","motif":"midnight"}
	]
}

static func stage(date: Dictionary) -> String:
	if Calendar.preview_poster(date): return "preview"
	return Calendar.season(date)

static func options(date: Dictionary) -> Array:
	return VARIANTS.get(stage(date),[])

static func choose(date: Dictionary,index: int) -> Dictionary:
	var variants: Array=options(date)
	if variants.is_empty(): return {}
	# Year and day are seed inputs; the index differentiates adjacent signs.
	var chosen: Dictionary=variants[posmod(index+int(date.get("day",1))+int(date.get("year",0)),variants.size())].duplicate(true)
	chosen["stage"]=stage(date)
	chosen["index"]=index
	return chosen

static func art_available(item: Dictionary) -> bool:
	return ResourceLoader.exists(str(item.get("image","")))
