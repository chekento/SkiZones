extends RefCounted
## Dimensions and riding surfaces shared by meshes, placement and NPC movement.
const KINDS := ["ramp","rail","roller","kicker_medium","kicker_pro","table_jump","step_up","step_down","rail_down","rail_kink","rail_rainbow","box","tube","funbox","wallride","whoops","quarterpipe","halfpipe","spine","transfer"]
const NAMES := ["Kleine Sprungrampe","Breite Anfänger-Rail","Sanfte Schneewelle","Mittlerer Kicker","Pro-Kicker","Table Jump","Step-Up","Step-Down","Down-Rail","Kink-Rail","Rainbow-Rail","Breite Box","Tube","Funbox","Wallride","Whoops-Linie","Quarterpipe","Halfpipe","Spine","Transfer"]
const COSTS := [850,1200,600,1800,3200,2800,2600,2600,1600,2100,2400,1400,1500,2900,3400,2200,4600,7800,2900,3600]
const SPECS := {
	"ramp":{"length":10.0,"width":4.8,"height":1.35,"skill":1,"appeal":8.0,"upkeep":0.0,"risk":0.3,"shape":"kicker"},
	"rail":{"length":6.4,"width":1.1,"height":1.1,"skill":1,"appeal":8.0,"upkeep":0.0,"risk":0.4,"shape":"rail"},
	"roller":{"length":12.0,"width":4.8,"height":0.85,"skill":1,"appeal":6.0,"upkeep":0.0,"risk":0.1,"shape":"roller"},
	"kicker_medium":{"length":16.0,"width":5.0,"height":2.2,"skill":1,"appeal":16.0,"upkeep":6.0,"risk":0.8,"shape":"kicker"},
	"kicker_pro":{"length":22.0,"width":6.0,"height":3.4,"skill":2,"appeal":24.0,"upkeep":10.0,"risk":1.5,"shape":"kicker"},
	"table_jump":{"length":18.0,"width":6.0,"height":2.0,"skill":1,"appeal":18.0,"upkeep":8.0,"risk":0.6,"shape":"table"},
	"step_up":{"length":20.0,"width":5.0,"height":2.3,"skill":2,"appeal":20.0,"upkeep":8.0,"risk":1.1,"shape":"up"},
	"step_down":{"length":20.0,"width":5.0,"height":2.5,"skill":2,"appeal":20.0,"upkeep":8.0,"risk":1.2,"shape":"down"},
	"rail_down":{"length":9.0,"width":1.1,"height":1.5,"skill":1,"appeal":14.0,"upkeep":5.0,"risk":0.8,"shape":"downrail"},
	"rail_kink":{"length":10.0,"width":1.1,"height":1.4,"skill":2,"appeal":19.0,"upkeep":7.0,"risk":1.1,"shape":"kink"},
	"rail_rainbow":{"length":10.0,"width":1.0,"height":2.0,"skill":2,"appeal":21.0,"upkeep":7.0,"risk":1.2,"shape":"rainbow"},
	"box":{"length":9.0,"width":2.2,"height":0.8,"skill":1,"appeal":11.0,"upkeep":4.0,"risk":0.3,"shape":"box"},
	"tube":{"length":8.0,"width":1.4,"height":1.2,"skill":1,"appeal":13.0,"upkeep":5.0,"risk":0.5,"shape":"tube"},
	"funbox":{"length":13.0,"width":5.0,"height":1.5,"skill":1,"appeal":19.0,"upkeep":7.0,"risk":0.6,"shape":"funbox"},
	"wallride":{"length":12.0,"width":4.0,"height":3.0,"skill":2,"appeal":22.0,"upkeep":9.0,"risk":1.2,"shape":"wall"},
	"whoops":{"length":22.0,"width":5.0,"height":1.0,"skill":1,"appeal":17.0,"upkeep":6.0,"risk":0.4,"shape":"whoops"},
	"quarterpipe":{"length":12.0,"width":6.0,"height":3.5,"skill":2,"appeal":25.0,"upkeep":12.0,"risk":1.4,"shape":"quarter"},
	"halfpipe":{"length":24.0,"width":10.0,"height":3.0,"skill":2,"appeal":32.0,"upkeep":18.0,"risk":1.1,"shape":"half"},
	"spine":{"length":14.0,"width":5.0,"height":2.2,"skill":2,"appeal":20.0,"upkeep":7.0,"risk":1.0,"shape":"spine"},
	"transfer":{"length":18.0,"width":6.0,"height":2.5,"skill":2,"appeal":23.0,"upkeep":9.0,"risk":1.3,"shape":"transfer"}
}
static func legacy(kind:String)->bool:return kind in ["ramp","rail","roller"]
static func spec(kind:String)->Dictionary:return SPECS.get(kind,{})
static func valid_options(options:Dictionary)->bool:
	for field in ["rotation","scale"]:
		var value:Variant=options.get(field,0.0 if field=="rotation" else 1.0)
		if not (value is int or value is float) or not is_finite(float(value)):return false
	return absf(float(options.get("rotation",0)))<=45.0 and float(options.get("scale",1))>=0.7 and float(options.get("scale",1))<=1.4
static func footprint(kind:String,options:Dictionary={})->Vector2:
	var item:=spec(kind)
	if item.is_empty():return Vector2.ZERO
	var angle:=deg_to_rad(float(options.get("rotation",0)))
	var scale_value:float=options.get("scale",1.0)
	return Vector2(absf(cos(angle))*float(item.width)+absf(sin(angle))*float(item.length),absf(cos(angle))*float(item.length)+absf(sin(angle))*float(item.width))*scale_value
static func local_point(along:float,side:float,options:Dictionary)->Vector2:
	var angle:=deg_to_rad(float(options.get("rotation",0)))
	var scale_value:float=options.get("scale",1.0)
	return Vector2(cos(angle)*side-sin(angle)*along,sin(angle)*side+cos(angle)*along)/scale_value

static func surface_height(kind:String,along:float,side:float)->float:
	var item:=spec(kind)
	if item.is_empty() or absf(along)>float(item.length)*0.5 or absf(side)>float(item.width)*0.5:return 0.0
	var t:float=(along/float(item.length))+0.5
	var x:float=side/(float(item.width)*0.5)
	var h:float=item.height
	match str(item.shape):
		"kicker":return h*smoothstep(0.0,0.64,t)*(1.0-smoothstep(0.66,0.83,t))
		"rail":return h
		"roller":return sin(t*PI)*h
		"table":return h*smoothstep(0.0,0.24,t)*(1.0-smoothstep(0.75,1.0,t))
		"up":return h*smoothstep(0.0,0.14,t)*(0.38+0.62*smoothstep(0.48,0.58,t))*(1.0-smoothstep(0.8,1.0,t))
		"down":return h*smoothstep(0.0,0.18,t)*(1.0-0.58*smoothstep(0.45,0.53,t))*(1.0-smoothstep(0.82,1.0,t))
		"downrail":return h*(1.0-0.65*t)
		"kink":return h*(1.0-0.60*clampf((t-0.48)/0.52,0,1))
		"rainbow":return 0.45+sin(t*PI)*h
		"box":return h
		"tube":return h*0.42+sqrt(maxf(0.0,1.0-x*x))*h*0.58
		"funbox":return h*(1.0-0.25*absf(x))*smoothstep(0,0.23,t)*(1.0-smoothstep(0.77,1.0,t))
		"wall":return h*pow((x+1.0)*0.5,2)*sin(t*PI)
		"whoops":return pow(sin(t*PI*4.0),2)*h
		"quarter":return h*(1.0-sqrt(maxf(0.0,1.0-pow(clampf(t/0.76,0,1),2))))*(1.0-smoothstep(0.85,1.0,t))
		"half":return h*x*x*sin(t*PI)
		"spine":return h*maxf(0.0,1.0-absf(t*2.0-1.0))
		"transfer":return h*pow(maxf(0.0,sin(clampf(t+x*0.15,0,1)*PI)),1.6)*(1.0-0.2*absf(x))
	return 0.0
static func ride_height(kind:String,along:float,side:float)->float:
	var item:=spec(kind)
	if item.is_empty():return 0.0
	var t:float=along/float(item.length)+0.5
	var height_value:=surface_height(kind,along,side)
	if str(item.shape)=="kicker" and t>0.64 and t<1.0 and absf(side)<=float(item.width)*0.5:
		var flight:=clampf((t-0.64)/0.36,0,1)
		height_value=maxf(height_value,float(item.height)*((1.0-flight)+sin(flight*PI)*0.65))
	return height_value
