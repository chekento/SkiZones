extends RefCounted
## SkiZones 0.40: deterministic, validated, offline-first custom mountain blueprint.
## This produces editable gameplay geometry data, not a decorative random image.
## A later integration connects versioned blueprints to independent save slots.
const SCHEMA := 1
const SIZES := {
	"compact": Vector2(2400, 2600),
	"standard": Vector2(4200, 4600),
	"large": Vector2(6400, 7000),
	"grand": Vector2(9000, 9600)
}
const LANDFORMS := ["ridge", "isolated", "plateau", "alpine_pasture", "hills", "glacial_basin", "horseshoe"]
const DIFFICULTIES := ["gentle", "mixed", "technical", "extreme"]
const CLIMATES := ["alpine", "continental", "snowy", "mild"]
const EXPOSURES := ["north", "east", "south", "west"]
const DEFAULT := {
	"name": "Meine Alpenwelt",
	"seed": 20261108,
	"size": "standard",
	"landform": "ridge",
	"difficulty": "mixed",
	"climate": "alpine",
	"exposure": "south",
	"peak_count": 7,
	"peak_height": 850,
	"forest": 55,
	"lake_count": 1,
	"village_count": 2,
	"ridge_angle": 20,
	"valley_width": 48,
	"plateau_width": 42,
	"rolling_hills": 35,
	"snowline": 1250,
	"erosion": 35,
	"avalanche_risk": 20
}

static func validate(values: Dictionary) -> Dictionary:
	var settings := DEFAULT.duplicate(true)
	for key in values:
		if not settings.has(key):
			return {"ok": false, "error": "Unknown setting: " + str(key)}
		settings[key] = values[key]
	for key in ["size", "landform", "difficulty", "climate", "exposure"]:
		var choices: Array = SIZES.keys() if key == "size" else LANDFORMS if key == "landform" else DIFFICULTIES if key == "difficulty" else CLIMATES if key == "climate" else EXPOSURES
		if not settings[key] is String or settings[key] not in choices:
			return {"ok":false,"error":"Invalid option: "+key}
	if not settings.name is String or settings.name.strip_edges().length() < 2 or settings.name.length() > 48:
		return {"ok":false,"error":"Map name must be 2–48 characters"}
	if settings.name.contains("/") or settings.name.contains("\\"):
		return {"ok":false,"error":"Invalid map name"}
	var limits := {
		"seed":[0,2147483647], "peak_count":[1,24], "peak_height":[80,2800],
		"forest":[0,100], "lake_count":[0,8], "village_count":[0,8],
		"ridge_angle":[0,359], "valley_width":[0,100], "plateau_width":[0,100],
		"rolling_hills":[0,100], "snowline":[100,3500],
		"erosion":[0,100], "avalanche_risk":[0,100]
	}
	for key in limits:
		var value: Variant=settings[key]
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)):
			return {"ok":false,"error":"Expected finite integer: "+key}
		if value < limits[key][0] or value > limits[key][1]:
			return {"ok":false,"error":"Out of range: "+key}
		settings[key]=int(value)
	return {"ok":true,"settings":settings}

static func generate(options: Dictionary = {}) -> Dictionary:
	var checked := validate(options)
	if not checked.ok: return checked
	var config: Dictionary=checked.settings
	var rng := RandomNumberGenerator.new()
	rng.seed=int(config.seed)
	var size: Vector2=SIZES[config.size]
	var angle := deg_to_rad(float(config.ridge_angle))
	var axis := Vector2(cos(angle),sin(angle))
	var across := Vector2(-axis.y,axis.x)
	var centre := Vector2(0,-size.y*0.50+180)
	var peaks: Array=[]
	var valleys: Array=[]
	var steepness: float=[0.60,0.85,1.06,1.28][DIFFICULTIES.find(config.difficulty)]
	var spread: float=float(config.valley_width)/100.0
	for index in range(int(config.peak_count)):
		var fraction := (float(index)+0.5)/float(config.peak_count)
		var position := Vector2.ZERO
		match config.landform:
			"ridge":
				position=centre+axis*(fraction-0.5)*size.x*0.72+across*rng.randf_range(-0.12,0.12)*size.y
			"isolated":
				position=Vector2(rng.randf_range(-0.39,0.39)*size.x, -rng.randf_range(0.20,0.88)*size.y)
			"plateau":
				position=centre+Vector2(rng.randf_range(-0.25,0.25)*size.x,rng.randf_range(-0.18,0.18)*size.y)
			"alpine_pasture":
				position=Vector2((fraction-0.5)*size.x*0.68, -size.y*rng.randf_range(0.44,0.72))
			"hills":
				position=Vector2(rng.randf_range(-0.40,0.40)*size.x, -rng.randf_range(0.14,0.86)*size.y)
			"glacial_basin":
				var theta: float=fraction*TAU+rng.randf_range(-0.11,0.11)
				position=centre+Vector2(cos(theta)*size.x*0.29,sin(theta)*size.y*0.30)
			"horseshoe":
				var theta: float=PI*0.12+fraction*PI*0.76
				position=centre+Vector2(cos(theta)*size.x*0.37,-sin(theta)*size.y*0.29)
		position.x=clampf(position.x,-size.x*0.43,size.x*0.43)
		position.y=clampf(position.y,-size.y+500.0,-size.y*0.12)
		var height: float=float(config.peak_height)*steepness*rng.randf_range(0.72,1.18)
		if config.landform=="hills": height*=0.28+float(config.rolling_hills)*0.003
		if config.landform=="alpine_pasture":height*=0.54
		var span: float=minf(size.x,size.y)*rng.randf_range(0.15,0.24)
		if config.landform=="plateau":span*=1.0+float(config.plateau_width)*0.012
		if config.landform=="isolated":span*=maxf(0.6,1.0-spread*0.35)
		peaks.append([roundf(position.x),roundf(position.y),roundf(height),roundf(span)])
	if config.landform in ["ridge","horseshoe","glacial_basin"]:
		valleys.append([roundf(centre.x),roundf(centre.y),-roundf(float(config.peak_height)*0.21*spread),roundf(size.x*0.19+size.x*spread*0.22)])
	if config.landform=="alpine_pasture":
		valleys.append([0,-roundf(size.y*0.42),-roundf(float(config.peak_height)*0.14),roundf(size.x*0.28)])
	var multiplier := 0.30+float(config.forest)/100.0*1.65
	if config.landform=="glacial_basin":multiplier*=0.55
	var snow := 0.75+float(3500-int(config.snowline))/3500.0*0.68
	if config.climate=="snowy":snow+=0.35
	if config.climate=="mild":snow-=0.22
	var result := {
		"schema":SCHEMA,"settings":config.duplicate(true),
		"bounds":Rect2(-size.x*0.5,-size.y+420,size.x,size.y),
		"name":config.name,"subtitle":"Eigene generierte Skiwelt",
		"color":"83b7c3","rank":1,"guests":0,"contracts":0,
		"forest":multiplier,"snow":clampf(snow,0.55,1.8),
		"peaks":peaks,"valleys":valleys,
		"start_lift":"drag","start_bottom":[140,180],"start_top":[155,-180],
		"budget":400000,"start":"Eigenes Basislager",
		"sky":"bfd8ed","ground":"e4eff6","trees":"688578",
		"map_creator":true,"tree_density":int(config.forest),
		"lake_count":int(config.lake_count),"village_count":int(config.village_count),
		"erosion":int(config.erosion),"avalanche_risk":int(config.avalanche_risk),
		"exposure":config.exposure,"snowline":int(config.snowline)
	}
	return {"ok":true,"map":result}
