extends RefCounted
## Shared map specifications. Unlocks belong to the passport, not a single resort.
static var _noise: Dictionary = {}

const MAPS := {
	"sonnenhang": {"bounds": Rect2(-1440, -2200, 2880, 2700), "name": "Velvet Peaks", "subtitle": "Sonnige Almterrassen & ein gemütliches Skidorf", "color": "74b4bb", "rank": 1, "guests": 0, "contracts": 0, "forest": 1.0, "snow": 1.0, "description": "Weiche Almkuppen, ein geschütztes Dorf und weite Carvinghänge. Dein Einstieg in ein alpines Boutique-Resort.", "start_lift": "drag", "start_bottom": [200, 205], "start_top": [245, -130], "budget": 400000, "start": "Almdorf mit Tellerlift", "sky": "efb88f", "ground": "e9eef5", "trees": "718a80", "peaks": [[-650, -1050, 230, 430], [550, -1700, 330, 470], [-900, -1850, 160, 310]], "valleys": []},
	"fichtenkamm": {"bounds": Rect2(-1800, -2900, 3600, 3400), "name": "Whisperpine Lodge", "subtitle": "Verschlungene Waldtäler & stille Höhenrücken", "color": "77a58a", "rank": 2, "guests": 800, "contracts": 2, "forest": 1.6, "snow": 1.15, "description": "Ein Waldresort mit einem nostalgischen Zweiersessel. Erschließe geschützte Mulden und lange Verbindungen zwischen den Kämmen.", "start_lift": "chair2", "start_bottom": [95, 195], "start_top": [120, -220], "budget": 520000, "start": "Waldlodge mit Zweiersessel", "sky": "b9cda7", "ground": "e3eeec", "trees": "527d70", "peaks": [[-740, -1100, 350, 440], [540, -1850, 390, 380], [-620, -2600, 430, 570], [1250, -2300, 250, 400]], "valleys": [[0, -1500, -140, 600]]},
	"gletscherwelt": {"bounds": Rect2(-2200, -4000, 4400, 4500), "name": "Glacier Royale", "subtitle": "Gletscherzungen & hochalpine Schneeschüsseln", "color": "9ac4db", "rank": 3, "guests": 2000, "contracts": 5, "forest": 0.45, "snow": 1.5, "description": "Helle Eisflanken und breite Gletscherbecken. Eine Gondel erschließt den ersten Panorama-Sektor deines hochalpinen Resorts.", "start_lift": "gondola", "start_bottom": [265, 195], "start_top": [300, -350], "budget": 850000, "start": "Gletscherbasis mit Gondel", "sky": "bdd8eb", "ground": "eaf3ff", "trees": "7897a5", "peaks": [[-1150, -2450, 740, 600], [630, -3200, 900, 690], [1350, -1300, 440, 450], [-1350, -900, 220, 360]], "valleys": [[80, -2100, -180, 700]]},
	"dreigipfel": {"bounds": Rect2(-2800, -4700, 5600, 5200), "name": "Crownline Summit", "subtitle": "Drei Königsgipfel & spektakuläre Passagen", "color": "b5a5c6", "rank": 4, "guests": 4000, "contracts": 10, "forest": 0.8, "snow": 1.2, "description": "Drei eigenständige Massive rund um ein breites Verbindungstal. Der Viersessel ist dein Start in ein weitläufiges Ski-Imperium.", "start_lift": "chair", "start_bottom": [35, 190], "start_top": [40, -310], "budget": 700000, "start": "Panoramadorf mit Viersessel", "sky": "d7bfdc", "ground": "f0edfa", "trees": "758786", "peaks": [[-1650, -2350, 940, 610], [0, -3850, 1150, 720], [1680, -2780, 1000, 680]], "valleys": [[-700, -3000, -170, 420], [800, -3200, -160, 500]]},
	"aurora": {"bounds": Rect2(-2200, -3300, 4400, 3800), "name": "Aurora Drift", "subtitle": "Nordlicht-Mulden & spielerische Boardhänge", "color": "84c8c3", "rank": 2, "guests": 1200, "contracts": 3, "forest": 1.15, "snow": 1.35, "description": "Runde Schneeschüsseln und versetzte Hügel laden zum Snowboarden ein. Eine kompakte Anfängerbasis wächst in die weiten Nordlicht-Täler.", "start_lift": "carpet", "start_bottom": [265, 205], "start_top": [290, 5], "budget": 420000, "start": "Board-Basis mit Zauberteppich", "sky": "b8e1d9", "ground": "e6f4f5", "trees": "5f8d89", "peaks": [[-980, -1200, 440, 530], [630, -2200, 620, 660], [-1050, -2850, 520, 470], [1450, -1000, 310, 380]], "valleys": [[0, -1400, -170, 650]]},
	"mondkessel": {"bounds": Rect2(-2300, -3600, 4600, 4100), "name": "Moonblade Sanctuary", "subtitle": "Silberne Kessel & wendige Kurzski-Reviere", "color": "a69bc8", "rank": 3, "guests": 2800, "contracts": 7, "forest": 0.7, "snow": 1.25, "description": "Terrassierte Kessel und sanfte Übergänge zwischen eigenständigen Höhenzügen. Der Einersessel bringt die ersten Snowblader an den Hang.", "start_lift": "chair1", "start_bottom": [95, 205], "start_top": [60, -160], "budget": 560000, "start": "Kurzski-Chalet mit Einersessel", "sky": "c5bbdf", "ground": "ecebfa", "trees": "7d809b", "peaks": [[-1250, -1900, 700, 600], [1000, -1600, 710, 540], [0, -3100, 850, 700], [-1600, -800, 260, 350]], "valleys": [[0, -1800, -250, 750]]},
	"wolkenpass": {"bounds": Rect2(-2700, -4400, 5400, 4900), "name": "Cloudcrest Reserve", "subtitle": "Wolkenpässe & lange Carving-Rücken", "color": "92b8ce", "rank": 4, "guests": 5200, "contracts": 13, "forest": 0.9, "snow": 1.4, "description": "Lange Rücken, Seitentäler und weiche Wolkenpässe. Ein Sechsersessel eröffnet dein großzügiges Luxusresort über dem Tal.", "start_lift": "chair6", "start_bottom": [265, 190], "start_top": [330, -380], "budget": 900000, "start": "Höhenlodge mit Sechsersessel", "sky": "cedee8", "ground": "eef3fc", "trees": "6e9092", "peaks": [[-1550, -2400, 850, 640], [-400, -3600, 780, 570], [1250, -3100, 1100, 740], [1750, -1200, 460, 450]], "valleys": [[0, -2400, -210, 650]]},
	"sternengrat": {"bounds": Rect2(-3100, -5500, 6200, 6000), "name": "Starlight Valhalla", "subtitle": "Sternengrate & die große Gipfel-Expedition", "color": "d5ba8c", "rank": 5, "guests": 7500, "contracts": 18, "forest": 0.55, "snow": 1.5, "description": "Dein größtes Resort: hohe Gipfelketten, gestaffelte Hügel und tiefe Hochtäler. Ein Achtersessel startet die Expedition zum Sternengrat.", "start_lift": "chair8", "start_bottom": [70, 185], "start_top": [60, -380], "budget": 1050000, "start": "Grand Resort mit Achtersessel", "sky": "e8d2b2", "ground": "f5f1f6", "trees": "82928b", "peaks": [[-2100, -3300, 1180, 710], [-650, -4600, 1400, 780], [1350, -4200, 1460, 740], [2100, -2300, 850, 610], [-1300, -1500, 540, 510]], "valleys": [[100, -3000, -260, 830]]}
}

static func spec(id: String) -> Dictionary:
	return MAPS.get(id, MAPS.sonnenhang)

static func area(id: String) -> float:
	var bounds: Rect2 = spec(id).bounds
	return bounds.size.x * bounds.size.y / 1000000.0

static func base_height(point: Vector2, id: String, generation: int) -> float:
	if generation < 2 or id == "sonnenhang": return preload("res://src/core/terrain.gd").height(point)
	var index := maxi(0, MAPS.keys().find(id))
	var climb := maxf(210.0 - point.y, 0)
	var gradient: float = [0.205, 0.185, 0.22, 0.20, 0.15, 0.18, 0.20, 0.22][index]
	var shoulder := (38 + index * 3) * exp(-pow((point.x + 220 + index * 8) / 175.0, 2) - pow((point.y + 220) / 210.0, 2))
	return 6 + climb * gradient + shoulder + sin(point.x * 0.011 + index) * sin(climb * 0.009) * 1.6

static func extra_height(point: Vector2, id: String, generation: int = 1) -> float:
	if generation >= 2: return _resort_height(point, id)
	# The original valley is preserved, including old save geometry.
	var outside := maxf(maxf(absf(point.x) - 360, -400 - point.y), 0)
	if outside <= 0:
		return 0
	var blend := smoothstep(0, 260, outside)
	var peaks: Array
	match id:
		"fichtenkamm": peaks = [Vector4(-680, -1150, 230, 470), Vector4(480, -1700, 360, 420), Vector4(-550, -2500, 330, 510)]
		"gletscherwelt": peaks = [Vector4(-900, -2350, 530, 650), Vector4(650, -3000, 690, 750), Vector4(1200, -1200, 300, 450)]
		"dreigipfel": peaks = [Vector4(-1500, -2400, 720, 660), Vector4(0, -3800, 870, 820), Vector4(1550, -2700, 780, 720)]
		_: peaks = [Vector4(-650, -1050, 220, 400), Vector4(500, -1700, 310, 510), Vector4(-750, -2000, 180, 430)]
	var height_value := 0.0
	for peak in peaks:
		height_value += peak.z * exp(-pow((point.x - peak.x) / peak.w, 2) - pow((point.y - peak.y) / peak.w, 2))
	if not _noise.has(id):
		var noise := FastNoiseLite.new()
		noise.seed = MAPS.keys().find(id) * 1999 + 60421
		noise.frequency = 0.0038
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.48
		_noise[id] = noise
	var ridges: float = _noise[id].get_noise_2d(point.x, point.y)
	return blend * (height_value + ridges * (24 + height_value * 0.32) + sin(point.x * 0.004) * sin(point.y * 0.003) * 18)

static func _resort_height(point: Vector2, id: String) -> float:
	# Keep the established training valley; the surrounding landscape belongs to
	# this terrain generation and is never retroactively imposed on old saves.
	var outside := maxf(maxf(absf(point.x) - 360, -400 - point.y), 0)
	if outside <= 0: return 0
	var data := spec(id)
	var h := 0.0
	for peak in data.peaks + data.valleys:
		h += peak[2] * exp(-pow((point.x - peak[0]) / peak[3], 2) - pow((point.y - peak[1]) / peak[3], 2))
	var key := id + "_v2"
	if not _noise.has(key):
		var noise := FastNoiseLite.new()
		noise.seed = 60421 + MAPS.keys().find(id) * 1999
		noise.frequency = 0.0026
		noise.fractal_octaves = 3
		noise.fractal_gain = 0.45
		_noise[key] = noise
	var detail: float = _noise[key].get_noise_2d(point.x, point.y)
	var foothills := sin(point.x * 0.0032 + MAPS.keys().find(id)) * sin(point.y * 0.0025) * 32
	return smoothstep(0, 300, outside) * (h + detail * (24 + maxf(0, h) * 0.15) + foothills)
