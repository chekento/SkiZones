extends Control
## Touchable, animated profession-specific practice board.
## The real score, XP, fees, shifts and answers remain in StaffTraining.
## Touch an action bay (or use the three accessible text buttons).
signal choice_pressed(choice:int)

var profession:String="service"
var stage:int=0
var phase:float=0.0
var active:bool=true
var _selected:int=-1
var _redraw_accumulator:float=0.0

func configure(role:String,step:int)->void:
	profession=role
	stage=step
	_selected=-1
	active=true
	custom_minimum_size=Vector2(380,228)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	queue_redraw()

func _process(delta:float)->void:
	if not is_visible_in_tree():return
	phase+=minf(delta,0.10)
	_redraw_accumulator+=delta
	if _redraw_accumulator>=0.12:
		_redraw_accumulator=0.0
		queue_redraw()

func _draw()->void:
	var w:float=maxf(size.x,310.0)
	var h:float=maxf(size.y,225.0)
	draw_rect(Rect2(Vector2.ZERO,Vector2(w,h)),Color("112536"))
	# Three layers: distant alpine silhouette, middle-distant village,
	# foreground active workstations; subtle motion stays bounded.
	var drift:float=sin(phase*0.23)*2.0
	draw_colored_polygon(PackedVector2Array([Vector2(0,112),Vector2(50+drift,39),Vector2(91+drift,87),Vector2(160+drift,25),Vector2(236+drift,104),Vector2(w,52),Vector2(w,150),Vector2(0,150)]),Color("314e63"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,145),Vector2(w*0.19,92),Vector2(w*0.35,139),Vector2(w*0.58,82),Vector2(w*0.85,144),Vector2(w,108),Vector2(w,h),Vector2(0,h)]),Color("57768a"))
	draw_rect(Rect2(Vector2(0,157),Vector2(w,h-157)),Color("e7edef"))
	for index in range(3):
		var width_value:float=w/3.0
		var x:float=float(index)*width_value
		var chosen:bool=index==_selected
		var tone:Color=Color("e2f5f8") if chosen else Color("f7fafb") if index%2==0 else Color("e8f1f5")
		draw_rect(Rect2(Vector2(x+5,162),Vector2(width_value-10,h-172)),tone)
		draw_rect(Rect2(Vector2(x+5,162),Vector2(width_value-10,4)),Color("33a6cf") if chosen else Color("a6bdc9"))
		var center:Vector2=Vector2(x+width_value*0.5,127)
		_draw_action(index,center,width_value)
		draw_circle(Vector2(center.x,h-29),14,Color("137fad") if chosen else Color("476478"))
		draw_string(ThemeDB.fallback_font,Vector2(center.x-5,h-22),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)

func _draw_action(slot:int,center:Vector2,width_value:float)->void:
	var bob:float=sin(phase*3.0+float(slot)*1.4)*2.2
	var body:Color=Color("e9e8e2") if profession=="chef" else Color("264f68") if profession=="waiter" else Color("d9523d") if profession in ["rescue","medic"] else Color("4e86a7")
	# The employee is an animated person, not a fixed text-only answer.
	draw_circle(center+Vector2(-16,-27+bob),9,Color("f0d0ab"))
	draw_line(center+Vector2(-16,-16+bob),center+Vector2(-16,7+bob),body,10)
	draw_line(center+Vector2(-16,4+bob),center+Vector2(-29,24),Color("344957"),4)
	draw_line(center+Vector2(-16,4+bob),center+Vector2(-4,24),Color("344957"),4)
	draw_line(center+Vector2(-16,-10+bob),center+Vector2(10,-3+bob),body,4)
	var prop:Color=Color("a5b6be")
	var accent:Color=Color("35b1d3")
	if profession in ["chef","barista"]:
		draw_rect(Rect2(center+Vector2(8,-4),Vector2(34,7)),prop)
		draw_rect(Rect2(center+Vector2(14,-16),Vector2(22,14)),Color("465c6a"))
		draw_line(center+Vector2(26,-20),center+Vector2(26,-24-2.0*sin(phase*3.0)),Color("f8f4e8"),2)
	elif profession in ["waiter","bartender","hotel","receptionist","housekeeper"]:
		draw_line(center+Vector2(8,-4),center+Vector2(43,-4),Color("dce4ea"),5)
		for i in range(2):draw_circle(center+Vector2(18+float(i)*14,-10),5,accent)
	elif profession in ["rescue","medic","lifeguard"]:
		draw_rect(Rect2(center+Vector2(8,-12),Vector2(33,22)),Color("f3f4ed"))
		draw_rect(Rect2(center+Vector2(22,-10),Vector2(5,18)),Color("d9523d"))
		draw_rect(Rect2(center+Vector2(16,-4),Vector2(17,5)),Color("d9523d"))
	elif profession in ["operator","ski_instructor","driver","snow"]:
		draw_line(center+Vector2(7,1),center+Vector2(41,-22),Color("2d4657"),5)
		draw_circle(center+Vector2(36,-19),5,accent)
	else:
		draw_rect(Rect2(center+Vector2(11,-8),Vector2(28,23)),Color("516f80"))
		draw_line(center+Vector2(17,-2),center+Vector2(34,-2),accent,2)
		draw_line(center+Vector2(17,5),center+Vector2(32,5),Color("dce9ee"),2)
	# Selection changes the work zone itself rather than only a text colour.
	draw_line(center+Vector2(-42,36),center+Vector2(46,36),accent if slot==_selected else Color("839da9"),3)
	if width_value>145:
		for dot in range(3):
			draw_circle(center+Vector2(-34+float(dot)*12,48),2.5,Color("2e647e"))

func _gui_input(event:InputEvent)->void:
	if not active:return
	var pointer:Vector2
	if event is InputEventScreenTouch:
		if not event.pressed:return
		pointer=event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
		pointer=event.position
	else:return
	_selected=clampi(floori(pointer.x/maxf(size.x,1.0)*3.0),0,2)
	active=false
	queue_redraw()
	choice_pressed.emit(_selected)
	accept_event()
