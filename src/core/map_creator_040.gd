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
	"tree_count": 2400,
	"lake_count": 1,
	"river_count": 2,
	"ridge_connectivity": 65,
	"tree_line": 2000,
	"trailhead_count": 2,
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
		"forest":[0,100], "tree_count":[0,12000], "lake_count":[0,8], "village_count":[0,8],
		"river_count":[0,6], "ridge_connectivity":[0,100], "tree_line":[200,3500], "trailhead_count":[0,8],
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
				position=centre+axis*(fraction-0.5)*size.x*0.72+across*rng.randf_range(-0.05, -0.05+0.18*(1.0-float(config.ridge_connectivity)/100.0))*size.y
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
	# Actual geographic placements, rather than only decorative counters. The
	# seed and fixed candidate count keep re-generations stable across updates.
	# All positions lie inside the playable rectangle and avoid the safe base.
	var shape_map:Dictionary={"peaks":peaks,"valleys":valleys}
	var lakes:Array=[]
	for i in range(int(config.lake_count)):
		var best_point:=Vector2.ZERO
		var best_score:=INF
		for attempt in range(28):
			var candidate:=Vector2(rng.randf_range(-size.x*0.40,size.x*0.40),-rng.randf_range(size.y*0.18,size.y*0.86))
			var separation:=true
			for other in lakes:
				if Vector2(other[0],other[1]).distance_to(candidate)<175.0:separation=false
			if not separation:continue
			var score:float=sample_height(shape_map,candidate)+absf(candidate.x)*0.005
			if score<best_score:
				best_score=score
				best_point=candidate
		if is_finite(best_score):
			lakes.append([roundf(best_point.x),roundf(best_point.y),rng.randi_range(65,130)])
	var villages:Array=[]
	for i in range(int(config.village_count)):
		var fraction:float=(float(i)+0.5)/float(maxi(1,int(config.village_count)))
		var x:float=(fraction-0.5)*size.x*0.66+rng.randf_range(-50.0,50.0)
		var y:float=-size.y*rng.randf_range(0.08,0.23)
		villages.append([roundf(x),roundf(y),rng.randi_range(50,100)])
	var trailheads:Array=[]
	for i in range(int(config.trailhead_count)):
		var x:float=rng.randf_range(-size.x*0.30,size.x*0.30)
		var y:float=-size.y*rng.randf_range(0.25,0.58)
		trailheads.append([roundf(x),roundf(y)])
	var rivers:Array=[]
	for i in range(int(config.river_count)):
		var x:float=rng.randf_range(-size.x*0.34,size.x*0.34)
		var origin_y:float=-size.y*rng.randf_range(0.54,0.85)
		var segments:Array=[]
		for j in range(9):
			var fraction:float=float(j)/8.0
			var y:float=lerpf(origin_y,-size.y*0.04,fraction)
			segments.append([roundf(clampf(x+sin(fraction*TAU*1.5+float(i))*size.x*0.025,-size.x*0.45,size.x*0.45)),roundf(y)])
		rivers.append(segments)
	# Forests are batched as clusters, never thousands of individually stored
	# Tree nodes. Actual 3D instancing can consume these patches incrementally.
	var clusters:Array=[]
	var remaining:int=int(config.tree_count)
	var cluster_count:int=mini(64,ceili(float(remaining)/240.0))
	for i in range(cluster_count):
		var choice:=Vector2.ZERO
		for attempt in range(16):
			var point:=Vector2(rng.randf_range(-size.x*0.43,size.x*0.43),-rng.randf_range(size.y*0.10,size.y*0.85))
			choice=point
			if sample_height(shape_map,point)<=float(config.tree_line):break
		var count:int=ceili(float(remaining)/float(maxi(1,cluster_count-i)))
		clusters.append([roundf(choice.x),roundf(choice.y),rng.randi_range(90,210),count])
		remaining-=count
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
		"map_creator":true,"tree_density":int(config.forest),"tree_count":int(config.tree_count),
		"lake_count":int(config.lake_count),"village_count":int(config.village_count),
		"river_count":int(config.river_count),"ridge_connectivity":int(config.ridge_connectivity),
		"tree_line":int(config.tree_line),"trailhead_count":int(config.trailhead_count),
		"lakes":lakes,"villages":villages,"trailheads":trailheads,"rivers":rivers,"forest_clusters":clusters,
		"erosion":int(config.erosion),"avalanche_risk":int(config.avalanche_risk),
		"exposure":config.exposure,"snowline":int(config.snowline)
	}
	return {"ok":true,"map":result}

## Exact analytic preview of the generated peaks and basins; no random calls.
## The upcoming gameplay adapter uses the same immutable blueprint.
static func sample_height(blueprint: Dictionary, point: Vector2) -> float:
	var result := 0.0
	for shape in blueprint.get("peaks",[]):
		var radius := maxf(1.0,float(shape[3]))
		result+=float(shape[2])*exp(-pow((point.x-float(shape[0]))/radius,2.0)-pow((point.y-float(shape[1]))/radius,2.0))
	for shape in blueprint.get("valleys",[]):
		var radius := maxf(1.0,float(shape[3]))
		result+=float(shape[2])*exp(-pow((point.x-float(shape[0]))/radius,2.0)-pow((point.y-float(shape[1]))/radius,2.0))
	return maxf(0.0,result)
