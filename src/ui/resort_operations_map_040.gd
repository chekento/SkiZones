extends Control
## 0.40 resort traffic map: real lift geometry and sampled terrain relief.
## No route/economy mutation; every rendered hotspot is an existing asset.
signal lift_selected(asset_id: int)
const Terrain = preload("res://src/core/terrain.gd")
const L = preload("res://src/core/i18n.gd")
var model: RefCounted
var rows: Array=[]
var hot_spots: Array=[]
var selected_id: int=-1

func setup(model_value: RefCounted, lift_rows: Array) -> void:
	model=model_value
	rows=lift_rows
	custom_minimum_size=Vector2(0,280)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text=L.text("Liftpunkt berühren: Anlage und Personal öffnen")
	queue_redraw()

func _map_rect() -> Rect2:
	return Rect2(16,31,maxf(1,size.x-32),maxf(1,size.y-68))

func _world_rect() -> Rect2:
	if model==null:return Rect2(Vector2.ZERO,Vector2.ONE)
	var full: Rect2=model.terrain.bounds
	if rows.is_empty():return full
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for row in rows:
		var lift: Dictionary=model.asset(int(row.id))
		if not lift.has("bottom") or not lift.has("top"):continue
		for point in [Terrain.unpack(lift.bottom),Terrain.unpack(lift.top)]:
			low=low.min(point)
			high=high.max(point)
	if not low.is_finite() or not high.is_finite():return full
	var extent:=high-low+Vector2(170,170)
	extent=extent.max(full.size*0.06)
	var ratio: float=_map_rect().size.x/maxf(1,_map_rect().size.y)
	if extent.x/extent.y>ratio:extent.y=extent.x/ratio
	else:extent.x=extent.y*ratio
	extent*=1.12
	return Rect2((low+high)*0.5-extent*0.5,extent)

func _project(at: Vector2) -> Vector2:
	var world: Rect2=_world_rect()
	var area: Rect2=_map_rect()
	return area.position+((at-world.position)/world.size)*area.size

func _draw_relief(area: Rect2, world: Rect2) -> void:
	# Bounded viewport-local sampling, not an arbitrary decorative pattern.
	var columns:=56
	var lines:=18
	var heights: Array=[]
	var lo:=INF
	var hi:=-INF
	for y in range(lines):
		for x in range(columns):
			var at: Vector2=world.position+world.size*Vector2((float(x)+0.5)/columns,(float(y)+0.5)/lines)
			var elevation: float=model.terrain.height(at)
			heights.append(elevation)
			lo=minf(lo,elevation)
			hi=maxf(hi,elevation)
	var step:=Vector2(area.size.x/columns,area.size.y/lines)
	for y in range(lines):
		for x in range(columns):
			var ratio: float=clampf((float(heights[y*columns+x])-lo)/maxf(1,hi-lo),0,1)
			var color: Color=Color("7dada8").lerp(Color("f1f6ec"),smoothstep(0,1,ratio))
			draw_rect(Rect2(area.position+step*Vector2(x,y),step+Vector2(0.25,0.25)),color)
			if x>0 and floori(ratio*8)!=floori(clampf((float(heights[y*columns+x-1])-lo)/maxf(1,hi-lo),0,1)*8):
				var corner: Vector2=area.position+step*Vector2(x,y)
				draw_line(corner,corner+Vector2(0,step.y),Color("315d62",0.22),1,true)
			if y>0 and floori(ratio*8)!=floori(clampf((float(heights[(y-1)*columns+x])-lo)/maxf(1,hi-lo),0,1)*8):
				var corner: Vector2=area.position+step*Vector2(x,y)
				draw_line(corner,corner+Vector2(step.x,0),Color("315d62",0.22),1,true)

func _draw() -> void:
	var area: Rect2=_map_rect()
	draw_rect(Rect2(Vector2.ZERO,size),Color("dfece7"))
	var font: Font=get_theme_default_font()
	draw_string(font,Vector2(16,20),L.text("BERGNETZ · WARTESCHLANGEN & STÖRUNGEN"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("24454b"))
	hot_spots.clear()
	if model==null:return
	_draw_relief(area,_world_rect())
	for row in rows:
		var lift: Dictionary=model.asset(int(row.id))
		if not lift.has("bottom") or not lift.has("top"):continue
		var a: Vector2=_project(Terrain.unpack(lift.bottom))
		var b: Vector2=_project(Terrain.unpack(lift.top))
		var centre: Vector2=(a+b)*0.5
		var queued: int=int(row.queue)
		var severity: int=int(row.severity)
		var tone: Color=Color("c95b48") if severity>=3 else Color("d38c4f") if severity>=2 else Color("4b9f99") if severity==1 else Color("477b82")
		draw_line(a,b,Color("fffaf1"),7.0,true)
		draw_line(a,b,tone,3.2,true)
		draw_circle(a,4,tone)
		draw_circle(b,4,tone)
		var radius: float=clampf(13+sqrt(float(queued))*2.1,13,33)
		if queued>0:draw_circle(centre,radius+8,Color(tone,0.19))
		draw_circle(centre,radius+2,Color("fffaf0"))
		draw_circle(centre,radius,tone)
		draw_string(font,centre+Vector2(-17,5),str(queued) if queued>0 else "✓",HORIZONTAL_ALIGNMENT_CENTER,34,14,Color.WHITE)
		if int(row.id)==selected_id:draw_arc(centre,radius+5,0,TAU,28,Color("193e49"),3,true)
		hot_spots.append({"id":int(row.id),"at":centre,"radius":radius+8})
	var legend: Array=[
		{"name":L.text("Normal"),"color":Color("477b82")},
		{"name":L.text("Wartezeit"),"color":Color("d38c4f")},
		{"name":L.text("Störung / Personal"),"color":Color("c95b48")}
	]
	var at_x:=18.0
	for item in legend:
		draw_circle(Vector2(at_x,size.y-16),5,item.color)
		draw_string(font,Vector2(at_x+10,size.y-12),item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("365c5f"))
		at_x+=minf(165.0,size.x/3.2)

func _pick(at: Vector2) -> void:
	var closest_id: int=-1
	var closest_dist: float=INF
	for hit in hot_spots:
		var dist: float=at.distance_to(hit.at)
		if dist<=hit.radius and dist<closest_dist:
			closest_dist=dist
			closest_id=int(hit.id)
	if closest_id>=0:
		selected_id=closest_id
		queue_redraw()
		lift_selected.emit(closest_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_pick(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_pick(event.position)
		accept_event()
