extends Control
## All meal gestures are transient until one complete proof is submitted.
const L=preload("res://src/core/i18n.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
signal completed(proof:Dictionary)
signal updated
var task:Dictionary={}
var stage:=0
var ingredients:Array=[]
var prep:=0
var heat:=0.0
var heating:=false
var submitted:=false
var pointer:=-2
var source:=-1
var last:=Vector2.ZERO
var travel:=0.0
const BOWLS:=[Vector2(0.17,0.20),Vector2(0.50,0.20),Vector2(0.83,0.20)]
const BOARD:=Rect2(0.12,0.40,0.76,0.48)
const PREP_AREA:=Rect2(0.12,0.10,0.76,0.78)
const FIRE_BUTTON:=Rect2(0.08,0.68,0.84,0.24)
const PLATE:=Vector2(0.25,0.64)
const PASS:=Rect2(0.57,0.10,0.36,0.40)
func setup(order:Dictionary)->void:
	task=order.duplicate(true);name="kitchen_workbench"
	custom_minimum_size=Vector2(0,340);mouse_filter=Control.MOUSE_FILTER_STOP
	var ancestor:Node=get_parent()
	while ancestor!=null:
		if ancestor is DragScroll:ancestor.gesture_exclusions.append(self)
		if ancestor is ScrollContainer:
			ancestor.resized.connect(_fit_height.bind(ancestor));_fit_height.call_deferred(ancestor)
			break
		ancestor=ancestor.get_parent()
func _fit_height(scroll:ScrollContainer)->void:custom_minimum_size.y=clampf(scroll.size.y,180,340)
func hint()->String:
	if stage==0:return L.text("Ziehe die drei Zutaten auf das Brett.")
	if stage==1:return (L.text("Rühre mit kurzen Bewegungen im Teig · %d / 6") if task.mix else L.text("Schneide mit sechs Abwärtsbewegungen · %d / 6"))%prep
	if stage==2:return L.text("Erhitzen starten und im grünen Bereich stoppen.")
	return L.text("Ziehe den fertigen Teller in die grüne Ausgabe.")
func field_size()->Vector2:return Vector2(size.x,maxf(1,size.y-32))
func point(p:Vector2)->Vector2:return Vector2(0,32)+p*field_size()
func normalized(at:Vector2)->Vector2:return (at-Vector2(0,32))/Vector2(maxf(1,size.x),maxf(1,size.y-32))
func cancel_gesture()->void:pointer=-2;source=-1;travel=0;queue_redraw()
func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED:
		cancel_gesture()
		if heating:heating=false;heat=0;updated.emit()
func _gui_input(event:InputEvent)->void:
	if submitted:return
	if event is InputEventScreenTouch:
		if event.canceled:cancel_gesture()
		elif event.pressed:_press(normalized(event.position),event.index)
		else:_release(normalized(event.position),event.index)
	elif event is InputEventScreenDrag:_move(normalized(event.position),event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_press(normalized(event.position),-1)
		else:_release(normalized(event.position),-1)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:_move(normalized(event.position),-1)
	accept_event()
func _press(p:Vector2,id:int)->void:
	if pointer!=-2:return
	pointer=id;last=p;travel=0;source=-1
	if stage==0:
		for i in range(3):
			if not ingredients.has(task.ingredients[i]) and p.distance_to(BOWLS[i])<0.15:source=i;break
	elif stage==1 and PREP_AREA.has_point(p):source=0
	elif stage==2 and FIRE_BUTTON.has_point(p):source=0
	elif stage==3 and p.distance_to(PLATE)<0.18:source=0
	queue_redraw()
func _move(p:Vector2,id:int)->void:
	if id!=pointer:return
	if stage==1 and source==0 and PREP_AREA.has_point(p) and PREP_AREA.has_point(last):
		var distance:=p.distance_to(last)
		if distance<0.12:
			if task.mix:travel+=distance
			elif absf(p.x-last.x)<0.06:travel+=maxf(0,p.y-last.y)
	last=p;queue_redraw()
func _release(p:Vector2,id:int)->void:
	if id!=pointer:return
	if source>=0:
		if stage==0 and BOARD.has_point(p):
			ingredients.append(task.ingredients[source])
			if ingredients.size()==3:stage=1
		elif stage==1 and PREP_AREA.has_point(p) and travel>=(0.5 if task.mix else 0.18):
			prep+=1
			if prep==6:stage=2
		elif stage==2 and FIRE_BUTTON.has_point(p):
			if heating:heating=false;stage=3
			else:heat=0;heating=true
		elif stage==3 and PASS.has_point(p):
			submitted=true
			completed.emit({"ingredients":ingredients.duplicate(),"prep":prep,"heat":heat,"served":true})
	cancel_gesture();updated.emit()
func _process(delta:float)->void:
	if heating and is_visible_in_tree():
		heat=minf(1,heat+clampf(delta,0,0.10)/7.0);queue_redraw()
func panel(color:Color)->StyleBoxFlat:
	var result:=StyleBoxFlat.new();result.bg_color=color;result.set_corner_radius_all(12);return result
func box(rect:Rect2,color:Color)->void:draw_style_box(panel(color),Rect2(point(rect.position),rect.size*field_size()))
func text_at(p:Vector2,value:String,font_size:int=16,color:Color=Color("244e4b"),width:float=-1)->void:
	draw_string(ThemeDB.fallback_font,point(p),value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
func _draw()->void:
	draw_style_box(panel(Color("e9e3d8")),Rect2(Vector2.ZERO,size))
	if task.is_empty():return
	var caption:String=L.text("Zutaten auf das Brett ziehen")
	if stage==1:caption=(L.text("Rühren · %d / 6") if task.mix else L.text("Schneiden · %d / 6"))%prep
	elif stage==2:caption=L.text("Garpunkt · grün stoppen")
	elif stage==3:caption=L.text("Teller zur Ausgabe ziehen")
	draw_string(ThemeDB.fallback_font,Vector2(12,22),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,14,Color("244e4b"))
	if stage==0:
		box(BOARD,Color("b99269"))
		for line in range(1,6):
			draw_line(point(Vector2(0.15,0.40+line*0.07)),point(Vector2(0.85,0.40+line*0.07)),Color("b28a60"),1)
		for i in range(ingredients.size()):
			food(point(Vector2(0.28+i*0.23,0.68)),str(ingredients[i]),minf(20,field_size().y*0.10))
		for i in range(3):
			if ingredients.has(task.ingredients[i]):continue
			var p:Vector2=last if source==i else BOWLS[i]
			var radius:float=minf(24,field_size().y*0.085)
			draw_circle(point(p),radius,Color("f5f1e7"));draw_arc(point(p),radius,0,TAU,28,Color("759b87"),2)
			food(point(p),str(task.ingredients[i]),radius*0.65)
			text_at(p+Vector2(-0.13,0.18),L.text(str(task.ingredients[i])),13,Color("244e4b"),size.x*0.30)
	elif stage==1:
		box(PREP_AREA,Color("b99269"))
		for i in range(6):
			var p:=Vector2(0.25+(i%3)*0.24,0.32+int(i/3)*0.30)
			food(point(p),str(task.ingredients[i%3]),minf(16,field_size().y*0.10))
			if i<prep:draw_line(point(p)-Vector2(12,0),point(p)+Vector2(12,0),Color("faf8ef"),2)
		if pointer!=-2 and source==0:
			draw_line(point(last)-Vector2(20,5),point(last)+Vector2(20,5),Color("f9fbfa"),7)
	elif stage==2:
		draw_circle(point(Vector2(0.5,0.26)),minf(field_size().y*0.18,65),Color("485956"))
		draw_circle(point(Vector2(0.5,0.26)),minf(field_size().y*0.14,50),Color("6c4930") if heat>0.9 else Color("c59156"))
		draw_line(point(Vector2(0.5,0.26))+Vector2(25,0),point(Vector2(0.5,0.26))+Vector2(65,0),Color("485956"),9)
		for i in range(3):food(point(Vector2(0.47+i*0.025,0.23+(i%2)*0.05)),str(task.ingredients[i]),6)
		box(Rect2(0.08,0.50,0.84,0.09),Color("bfb6a7"))
		box(Rect2(0.08+(float(task.target)-0.1)*0.84,0.50,0.168,0.09),Color("74ad89"))
		box(Rect2(0.08+heat*0.82,0.47,0.02,0.15),Color("244e4b"))
		box(FIRE_BUTTON,Color("285c53"))
		text_at(Vector2(0.13,0.84),L.text("Jetzt stoppen") if heating else L.text("Erhitzen starten"),17,Color.WHITE,size.x*0.75)
	else:
		box(PASS,Color("a4cbb1"));text_at(Vector2(0.61,0.33),L.text("Ausgabe"),16,Color("244e4b"),size.x*0.28)
		var p:Vector2=last if source==0 else PLATE
		draw_circle(point(p),32,Color("faf8ef"));draw_circle(point(p),23,Color("c79960"))

		for i in range(3):food(point(p)+Vector2((i-1)*13,(i%2)*8-4),str(task.ingredients[i]),7)

func food(at:Vector2,ingredient:String,radius:float)->void:
	match ingredient:
		"Zwiebeln":
			draw_circle(at,radius,Color("b68b9b"));draw_arc(at,radius*0.65,0,TAU,20,Color("f1d9dd"),2);draw_arc(at,radius*0.3,0,TAU,16,Color("f1d9dd"),1)
		"Pilze":
			draw_rect(Rect2(at+Vector2(-radius*0.2,0),Vector2(radius*0.4,radius)),Color("f2e2ca"));draw_circle(at,radius,Color("aa8060"));draw_line(at-Vector2(radius,0),at+Vector2(radius,0),Color("634936"),2)
		"Kartoffeln":
			draw_circle(at,radius,Color("c5a36e"));draw_circle(at+Vector2(-radius*0.3,radius*0.2),1.5,Color("95724a"));draw_circle(at+Vector2(radius*0.4,-radius*0.3),1.5,Color("95724a"))
		"Eier":
			draw_circle(at,radius,Color("f2e7ca"));draw_circle(at+Vector2(radius*0.2,0),radius*0.4,Color("e2b64f"))
		"Milch":
			draw_rect(Rect2(at-Vector2(radius*0.6,radius),Vector2(radius*1.2,radius*2)),Color("f8f5e9"));draw_rect(Rect2(at-Vector2(radius*0.6,radius*0.5),Vector2(radius*1.2,radius*0.5)),Color("81aaa8"))
		"Mehl":
			draw_colored_polygon(PackedVector2Array([at+Vector2(-radius,radius*0.7),at+Vector2(0,-radius),at+Vector2(radius,radius*0.7)]),Color("faf5e4"))
		"Brühe":
			draw_circle(at,radius,Color("c7a655"));draw_arc(at,radius*0.6,0,PI,16,Color("ebd994"),2)
		_:
			draw_circle(at+Vector2(-radius*0.35,0),radius*0.65,Color("739569"));draw_circle(at+Vector2(radius*0.35,radius*0.25),radius*0.6,Color("c57e51"));draw_circle(at+Vector2(0,-radius*0.35),radius*0.5,Color("a8b779"))
