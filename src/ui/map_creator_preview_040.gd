extends Control
## Compact topographic preview for generated 0.40 landscapes.
const Creator=preload("res://src/core/map_creator_040.gd")
var blueprint: Dictionary = {}
const COLUMNS := 48
const ROWS := 30

func _ready() -> void:
	custom_minimum_size=Vector2(260,240)
	resized.connect(queue_redraw)

func set_blueprint(value: Dictionary) -> void:
	blueprint=value.duplicate(true)
	queue_redraw()

func _draw() -> void:
	var bounds:=Rect2(Vector2.ZERO,size)
	draw_rect(bounds,Color("15313d"),true)
	if blueprint.is_empty():return
	var area:Rect2=blueprint.bounds
	var max_height:=maxf(100.0,float(blueprint.settings.peak_height)*1.8)
	var cell:=size/Vector2(COLUMNS,ROWS)
	for y in range(ROWS):
		for x in range(COLUMNS):
			var fraction:=Vector2((float(x)+0.5)/COLUMNS,(float(y)+0.5)/ROWS)
			var point:=area.position+fraction*area.size
			var elevation:float=Creator.sample_height(blueprint,point)
			var level:=clampf(elevation/max_height,0.0,1.0)
			var color:=Color("3e7181").lerp(Color("729389"),smoothstep(0,0.25,level))
			color=color.lerp(Color("a4a9a6"),smoothstep(0.2,0.68,level))
			color=color.lerp(Color("eef4fb"),smoothstep(0.60,0.95,level))
			draw_rect(Rect2(Vector2(x,y)*cell,cell+Vector2.ONE),color,true)
	# Show generated geography, not only its statistical settings.
	for river in blueprint.get("rivers",[]):
		var points:=PackedVector2Array()
		for entry in river:
			points.append((Vector2(float(entry[0]),float(entry[1]))-area.position)/area.size*size)
		if points.size()>=2:draw_polyline(points,Color("66c7e9"),1.6,true)
	for lake in blueprint.get("lakes",[]):
		var point:Vector2=(Vector2(float(lake[0]),float(lake[1]))-area.position)/area.size*size
		var radius:float=maxf(2.8,float(lake[2])/area.size.x*size.x)
		draw_circle(point,radius,Color("4fbedf"))
		draw_arc(point,radius,0,TAU,32,Color("d1f3fb"),1.2,true)
	for cluster in blueprint.get("forest_clusters",[]):
		var point:Vector2=(Vector2(float(cluster[0]),float(cluster[1]))-area.position)/area.size*size
		draw_circle(point,2.0,Color("205d47"))
	for hub in blueprint.get("villages",[]):
		var point:Vector2=(Vector2(float(hub[0]),float(hub[1]))-area.position)/area.size*size
		draw_rect(Rect2(point-Vector2(3.0,3.0),Vector2(6,6)),Color("ffe5a3"),true)
		draw_rect(Rect2(point-Vector2(3.0,3.0),Vector2(6,6)),Color("374f58"),false,1.1)
	for entry in blueprint.get("trailheads",[]):
		var point:Vector2=(Vector2(float(entry[0]),float(entry[1]))-area.position)/area.size*size
		draw_circle(point,3.1,Color("e9b873"),false,1.4,true)
	# Elevation/peak markers remain readable on narrow phone screens.
	for peak in blueprint.peaks:
		var px:Vector2=(Vector2(float(peak[0]),float(peak[1]))-area.position)/area.size*size
		draw_circle(px,3.0,Color("1c3441"))
		draw_circle(px,1.5,Color("f7f2df"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("cfe4e7"),false,2.0)
