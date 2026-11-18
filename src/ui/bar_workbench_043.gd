extends "res://src/ui/kitchen_workbench_043.gd"
## Reuses the proven pointer/scroll/layout shell; the bar has its own five-step handling.
const BOTTLES:=[Vector2(0.17,0.20),Vector2(0.50,0.20),Vector2(0.83,0.20)]
const SHAKER:=Rect2(0.30,0.40,0.40,0.48)
const SHAKE_AREA:=Rect2(0.12,0.12,0.76,0.72)
const POUR:=Rect2(0.08,0.68,0.84,0.24)
const GLASS:=Vector2(0.30,0.66)
const GARNISH:=Vector2(0.22,0.18)
const SERVE:=Rect2(0.60,0.10,0.32,0.40)
var garnished:=false
func setup(order:Dictionary)->void:
	super.setup(order);name="bar_workbench"
func hint()->String:
	match stage:
		0:return L.text("Ziehe die drei Zutaten in den Shaker.")
		1:return L.text("Schüttle mit sechs kurzen seitlichen Bewegungen · %d / 6")%prep
		2:return L.text("Ausschank gedrückt halten und bei der grünen Markierung loslassen.")
		3:return L.text("Ziehe die Garnitur auf das gefüllte Glas.")
	return L.text("Ziehe das fertige Getränk in die grüne Ausgabe.")
func _press(p:Vector2,id:int)->void:
	if pointer!=-2:return
	pointer=id;source=-1;last=p;travel=0
	if stage==0:
		for i in range(3):
			if not ingredients.has(task.ingredients[i]) and p.distance_to(BOTTLES[i])<0.15:source=i;break
	elif stage==1 and SHAKE_AREA.has_point(p):source=0
	elif stage==2 and POUR.has_point(p):source=0;heat=0;heating=true
	elif stage==3 and p.distance_to(GARNISH)<0.18:source=0
	elif stage==4 and p.distance_to(GLASS)<0.18:source=0
	queue_redraw()
func _move(p:Vector2,id:int)->void:
	if id!=pointer:return
	if stage==1 and source==0 and SHAKE_AREA.has_point(p) and SHAKE_AREA.has_point(last):
		if p.distance_to(last)<0.12 and absf(p.y-last.y)<0.06:travel+=absf(p.x-last.x)
	if stage==2 and heating and not POUR.has_point(p):
		heating=false;heat=0;source=-1
	last=p;queue_redraw()
func _release(p:Vector2,id:int)->void:
	if id!=pointer:return
	if source>=0:
		match stage:
			0:
				if SHAKER.has_point(p):
					ingredients.append(task.ingredients[source])
					if ingredients.size()==3:stage=1
			1:
				if SHAKE_AREA.has_point(p) and travel>=0.30:
					prep+=1
					if prep==6:stage=2
			2:
				if heating and POUR.has_point(p):heating=false;stage=3
			3:
				if p.distance_to(GLASS)<0.18:garnished=true;stage=4
			4:
				if SERVE.has_point(p):
					submitted=true
					completed.emit({"ingredients":ingredients.duplicate(),"shakes":prep,"fill":heat,"garnish":str(task.garnish) if garnished else "","served":true})
	cancel_gesture();updated.emit()
func cancel_gesture()->void:
	# A cancelled pour is retriable and cannot leave an invisible timer running.
	if stage==2 and heating:heating=false;heat=0
	super.cancel_gesture()
func _process(delta:float)->void:
	if heating and stage==2 and is_visible_in_tree():heat=minf(1,heat+clampf(delta,0,0.1)/5.0);queue_redraw()
func _glass(p:Vector2,amount:float)->void:
	var rect:=Rect2(point(p)-Vector2(21,34),Vector2(42,68))
	draw_style_box(panel(Color("d3dfd9")),rect)
	draw_rect(Rect2(rect.position+Vector2(5,58*(1-amount)+5),Vector2(32,58*amount)),Color(str(task.color)))
	if garnished:
		draw_circle(rect.position+Vector2(37,8),10,Color("80a46f"));draw_arc(rect.position+Vector2(37,8),7,0,TAU,20,Color("d7d895"),2)
func _draw()->void:
	draw_style_box(panel(Color("e8e1d7")),Rect2(Vector2.ZERO,size))
	if task.is_empty():return
	var captions:=[L.text("Zutaten in den Shaker ziehen"),L.text("Schütteln · %d / 6")%prep,L.text("Halten · bei Grün loslassen"),L.text("Garnitur auf das Glas ziehen"),L.text("Getränk zur Ausgabe ziehen")]
	draw_string(ThemeDB.fallback_font,Vector2(12,22),captions[stage],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,14,Color("244e4b"))
	if stage==0:
		box(SHAKER,Color("869b99"));text_at(Vector2(0.35,0.65),"%d / 3"%ingredients.size(),16)
		for i in range(3):
			if ingredients.has(task.ingredients[i]):continue
			var p:Vector2=last if source==i else BOTTLES[i]
			var pos:=point(p);var r:=minf(19,field_size().y*0.10)
			draw_style_box(panel(Color("75958b")),Rect2(pos-Vector2(r*0.6,r),Vector2(r*1.2,r*2)))
			draw_rect(Rect2(pos-Vector2(r*0.3,r*1.4),Vector2(r*0.6,r*0.5)),Color("4a6e67"))
			draw_rect(Rect2(pos-Vector2(r*0.5,0),Vector2(r,r*0.7)),Color("e4d6ba"))
			text_at(p+Vector2(-0.15,0.18),L.text(str(task.ingredients[i])),12,Color("244e4b"),size.x*0.31)
	elif stage==1:
		var offset:=Vector2(sin(travel*TAU)*0.05,0) if pointer!=-2 else Vector2.ZERO
		box(Rect2(Vector2(0.40,0.16)+offset,Vector2(0.20,0.54)),Color("869b99"))
		box(Rect2(Vector2(0.44,0.10)+offset,Vector2(0.12,0.08)),Color("496d66"))
		for i in range(6):draw_circle(point(Vector2(0.20+i*0.12,0.84)),5,Color("4f8b71") if i<prep else Color("b8b0a2"))
	elif stage==2:
		_glass(Vector2(0.5,0.25),heat)
		box(Rect2(0.08,0.49,0.84,0.09),Color("bfb6a7"))
		box(Rect2(0.08+(float(task.target)-0.1)*0.84,0.49,0.168,0.09),Color("74ad89"))
		box(Rect2(0.08+heat*0.82,0.46,0.02,0.15),Color("244e4b"))
		box(POUR,Color("285c53"));text_at(Vector2(0.13,0.84),L.text("Gedrückt halten"),17,Color.WHITE,size.x*0.74)
	else:
		var p:Vector2=last if source==0 and stage==4 else GLASS
		_glass(p,heat)
		if stage==3:
			var garnish_at:Vector2=last if source==0 else GARNISH
			draw_circle(point(garnish_at),13,Color("8ba56f"));draw_arc(point(garnish_at),9,0,TAU,20,Color("d7d895"),2)
			text_at(Vector2(0.40,0.20),L.text(str(task.garnish)),14)
		else:
			box(SERVE,Color("a4cbb1"));text_at(Vector2(0.63,0.34),L.text("Ausgabe"),15)
