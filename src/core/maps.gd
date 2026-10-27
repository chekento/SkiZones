extends RefCounted
## Shared map specifications. Unlocks belong to the passport, not a single resort.
static var _noise: Dictionary = {}

const MAPS := {
	"sonnenhang": {"name": "Sonnenhang", "subtitle": "Weite Almwiesen & sanfte Waldhänge", "bounds": Rect2(-1440, -2200, 2880, 2700), "color": "74b4bb", "rank": 1, "guests": 0, "contracts": 0, "forest": 1.0, "snow": 1.0, "description": "Dein erstes großes Tal. Sanfte Osthänge, ein steiler Westgrat und viel Platz für lange Rundwege."},
	"fichtenkamm": {"name": "Fichtenkamm", "subtitle": "Waldtäler & verwinkelte Bergrücken", "bounds": Rect2(-1800, -2900, 3600, 3400), "color": "77a58a", "rank": 2, "guests": 800, "contracts": 2, "forest": 1.6, "snow": 1.15, "description": "Dichte Wälder und zwei lange Kämme. Verbinde Seitentäler und plane geschützte Abfahrten zwischen den Bäumen."},
	"gletscherwelt": {"name": "Gletscherwelt", "subtitle": "Hochalpine Flanken & offene Schneefelder", "bounds": Rect2(-2200, -4000, 4400, 4500), "color": "9ac4db", "rank": 3, "guests": 2000, "contracts": 5, "forest": 0.45, "snow": 1.5, "description": "Lange Abfahrten unter eisigen Gipfeln. Weniger Wald, mehr Schnee und große Höhenunterschiede für dein nächstes Resort."},
	"dreigipfel": {"name": "Drei Gipfel", "subtitle": "Drei Massive & ein ganzes Bergpanorama", "bounds": Rect2(-2800, -4700, 5600, 5200), "color": "b5a5c6", "rank": 4, "guests": 4000, "contracts": 10, "forest": 0.8, "snow": 1.2, "description": "Das größte Gebiet: drei eigenständige Massive, lange Verbindungen und Platz für ein weit verzweigtes Lift- und Pistennetz."}
}

static func spec(id: String) -> Dictionary:
	return MAPS.get(id, MAPS.sonnenhang)

static func area(id: String) -> float:
	var bounds: Rect2 = spec(id).bounds
	return bounds.size.x * bounds.size.y / 1000000.0

static func extra_height(point: Vector2, id: String) -> float:
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
