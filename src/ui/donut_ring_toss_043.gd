extends Control
## Five deterministic physical throws. No model reference, stake, reward or save mutation.
const L=preload("res://src/core/i18n.gd")
const Offers=preload("res://src/core/building_offers_035.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const LAUNCH:=Vector2(0.5,0.78)
const PEGS:=[Vector2(0.25,0.28),Vector2(0.5,0.25),Vector2(0.75,0.28)]
const VALUES:=[10,20,10]
const GRAVITY:=1.7
var style_id:="alpine"
var phase:="aim"
var attempts:=0
var points:=0
var pointer:=-2
var pull:=LAUNCH
var position_value:=LAUNCH
var velocity:=Vector2.ZERO
var accumulator:=0.0
var feedback:=""
static func available(building:Dictionary)->bool:
	if building.get("kind","")!="schmarrn":return false
	for offer in Offers.active("schmarrn",int(building.get("level",1))):
		if offer.id=="donuts":return true
	return false
func _ready()->void:
	name="donut_ring_toss";custom_minimum_size=Vector2(0,340);mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true
	var ancestor:Node=get_parent()
	while ancestor!=null:
		if ancestor is DragScroll:ancestor.gesture_exclusions.append(self)
		if ancestor is ScrollContainer:
			ancestor.resized.connect(_fit_height.bind(ancestor));_fit_height.call_deferred(ancestor);break
		ancestor=ancestor.get_parent()
func _fit_height(scroll:ScrollContainer)->void:custom_minimum_size.y=clampf(scroll.size.y,180,340)
func field_size()->Vector2:return Vector2(size.x,maxf(1,size.y-32))
func point(p:Vector2)->Vector2:return Vector2(0,32)+p*field_size()
func normalized(at:Vector2)->Vector2:return (at-Vector2(0,32))/Vector2(maxf(1,size.x),maxf(1,size.y-32))
func reset()->void:
	phase="aim";attempts=0;points=0;pointer=-2;pull=LAUNCH;position_value=LAUNCH;velocity=Vector2.ZERO;accumulator=0;feedback="";queue_redraw()
func cancel()->void:
	pointer=-2;pull=LAUNCH
	if phase=="flight":phase="aim";position_value=LAUNCH;velocity=Vector2.ZERO;accumulator=0
	queue_redraw()
func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED:cancel()
func _gui_input(event:InputEvent)->void:
	if event is InputEventScreenTouch:
		if event.canceled:cancel()
		elif event.pressed:_press(normalized(event.position),event.index)
		else:_release(normalized(event.position),event.index)
	elif event is InputEventScreenDrag:_move(normalized(event.position),event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_press(normalized(event.position),-1)
		else:_release(normalized(event.position),-1)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:_move(normalized(event.position),-1)
	accept_event()
func _press(p:Vector2,id:int)->void:
	if pointer!=-2 or phase=="flight":return
	if phase=="done":
		if Rect2(0.15,0.65,0.70,0.24).has_point(p):pointer=id
		return
	if p.distance_to(LAUNCH)>0.16:return
	pointer=id;pull=p;feedback="";queue_redraw()
func _move(p:Vector2,id:int)->void:
	if id!=pointer or phase!="aim":return
	pull=Vector2(clampf(p.x,0.20,0.80),clampf(p.y,LAUNCH.y,0.99));queue_redraw()
func _release(p:Vector2,id:int)->void:
	if id!=pointer:return
	pointer=-2
	if phase=="done":
		if Rect2(0.15,0.65,0.70,0.24).has_point(p):reset()
		return
	if phase!="aim":return
	if not Rect2(0,0,1,1).has_point(p) or p.y<LAUNCH.y+0.04:pull=LAUNCH;queue_redraw();return
	pull=Vector2(clampf(p.x,0.20,0.80),clampf(p.y,LAUNCH.y,0.99))
	velocity=(LAUNCH-pull)*7.0;position_value=LAUNCH;phase="flight";accumulator=0;queue_redraw()
func _finish(value:int)->void:
	attempts+=1;points+=value;phase="done" if attempts>=5 else "aim"
	feedback=L.text("Treffer · +%d Punkte")%value if value>0 else L.text("Knapp vorbei · nächster Wurf")
	position_value=LAUNCH;pull=LAUNCH;velocity=Vector2.ZERO;accumulator=0
func _step(delta:float)->void:
	var before:=position_value
	position_value+=velocity*delta+Vector2(0,GRAVITY*delta*delta*0.5);velocity.y+=GRAVITY*delta
	if velocity.y>0:
		for i in range(PEGS.size()):
			if before.y<=PEGS[i].y and position_value.y>=PEGS[i].y and absf(position_value.x-PEGS[i].x)<0.055:_finish(VALUES[i]);return
	if position_value.y>1.05 or position_value.x< -0.15 or position_value.x>1.15:_finish(0)
func _process(delta:float)->void:
	if phase!="flight" or not is_visible_in_tree():return
	accumulator+=clampf(delta,0,0.1)
	while accumulator>=1.0/120.0 and phase=="flight":
		accumulator-=1.0/120.0;_step(1.0/120.0)
	queue_redraw()
func panel(color:Color)->StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color;box.set_corner_radius_all(12);return box
func _donut(at:Vector2,radius:float)->void:
	draw_circle(at,radius,Color("a77c50"));draw_arc(at,radius*0.72,0,TAU,40,Color("bd8d96"),radius*0.40)
	draw_circle(at,radius*0.29,Color("e9e1d3"))
	for i in range(7):
		var p:=at+Vector2(cos(i*TAU/7),sin(i*TAU/7))*radius*0.70
		draw_line(p-Vector2(1.5,1),p+Vector2(1.5,1),Color("f4e7c2"),1.5)
func _draw()->void:
	var palette:Dictionary=Styles.ui_palette(style_id)
	var ink:=Color(str(palette.ink))
	draw_style_box(panel(Color(str(palette.panel))),Rect2(Vector2.ZERO,size))
	draw_string(ThemeDB.fallback_font,Vector2(10,22),L.text("Ringwurf · %d / 5 · %d Punkte")%[attempts,points],HORIZONTAL_ALIGNMENT_LEFT,size.x-20,14,ink)
	draw_style_box(panel(Color("d3b893")),Rect2(point(Vector2(0.08,0.10)),Vector2(0.84,0.35)*field_size()))
	for i in range(3):
		var pos:=point(PEGS[i])
		draw_line(pos,pos+Vector2(0,16),Color("80624b"),6);draw_circle(pos,5,Color("f0e7ca"))
		draw_string(ThemeDB.fallback_font,pos+Vector2(-9,-13),str(VALUES[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("493f35"))
	if phase=="done":
		draw_style_box(panel(Color("285c53")),Rect2(point(Vector2(0.15,0.65)),Vector2(0.70,0.24)*field_size()))
		draw_string(ThemeDB.fallback_font,point(Vector2(0.20,0.81)),L.text("Neue fünf Würfe"),HORIZONTAL_ALIGNMENT_LEFT,size.x*0.60,17,Color.WHITE)
	else:
		if pointer!=-2:
			draw_line(point(LAUNCH),point(pull),Color("6d8980"),2)
			var initial:Vector2=(LAUNCH-pull)*7.0
			for i in range(1,13):
				var t:float=i*0.065
				var p:Vector2=LAUNCH+initial*t+Vector2(0,GRAVITY*t*t*0.5)
				if Rect2(0,0,1,1).has_point(p):draw_circle(point(p),2,Color("839c90"))
		_donut(point(position_value if phase=="flight" else pull),minf(size.x*0.045,field_size().y*0.085))
	if feedback!="":draw_string(ThemeDB.fallback_font,point(Vector2(0.08,0.57)),feedback,HORIZONTAL_ALIGNMENT_LEFT,size.x*0.85,13,ink)
