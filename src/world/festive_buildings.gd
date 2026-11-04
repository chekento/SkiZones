extends RefCounted
## Holiday architecture and roof dressing; presentation only, never save edits.
const Art=preload("res://src/world/alpine_art.gd")
const Lines=preload("res://src/world/line_art.gd")
const Assets=preload("res://src/world/style_assets.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const KINDS: Array=["gingerbread_lodge","gift_workshop","winter_stage","market_stall"]
static func make(kind: String,style: String) -> ArrayMesh:
	if style=="monochrome":
		var line_art:=Lines.new()
		var width:=21.0 if kind=="winter_stage" else 12.0 if kind=="market_stall" else 17.0
		line_art.box(Vector3(0,5,0),Vector3(width,10,12))
		if kind!="winter_stage":line_art.roof(width+1,14,10)
		else:line_art.box(Vector3(0,1,1),Vector3(width,2,14))
		if kind=="gift_workshop":
			line_art.box(Vector3(0,4,6.5),Vector3(4,4,1));line_art.line(Vector3(-2,4,7.1),Vector3(2,4,7.1))
		elif kind=="gingerbread_lodge":
			line_art.circle(Vector3(0,12,7),1.4)
		elif kind=="market_stall":line_art.box(Vector3(0,3,5),Vector3(width,2,2))
		return line_art.finish()
	var a:=Art.new()
	var trim:=Color(str(Styles.ui_palette(style).accent))
	var snow:=Color(str(Styles.detail_tints(style).snow))
	var wood:=Color(str(Styles.detail_tints(style).wood))
	match kind:
		"gingerbread_lodge":
			a.add(Assets.building("cabin",1,Color("b87747"),style),Vector3.ZERO,Color.WHITE,Vector3.ZERO,Vector3.ONE,true)
			for side in [-1,1]:
				for y in range(2,14,2):a.sphere(Vector3(side*7,y,7),.65,snow if y%4==0 else trim)
			for i in range(6):a.sphere(Vector3(-6+i*2.4,13,7),.7,snow)
		"gift_workshop":
			a.box(Vector3(0,5,0),Vector3(17,10,13),wood)
			a.roof(19,15,10)
			for x in [-5,0,5]:
				a.box(Vector3(x,4,7),Vector3(3,3,2),trim if x!=0 else snow)
				a.box(Vector3(x,4,8.1),Vector3(.4,3.2,.2),snow)
			a.cone(Vector3(5,15,-3),1.3,8,trim,1.3)
		"winter_stage":
			a.box(Vector3(0,1,0),Vector3(21,2,14),wood)
			for x in [-9,9]:a.box(Vector3(x,7,-4),Vector3(.6,12,.6),trim)
			a.box(Vector3(0,13,-4),Vector3(21,1,8),snow)
			a.box(Vector3(0,7,-6),Vector3(18,10,.5),trim)
			for x in [-7,7]:a.box(Vector3(x,4,-3),Vector3(3,5,3),Color("293b48"))
			for i in range(5):a.sphere(Vector3(-7+i*3.5,12,0),.6,snow)
		"market_stall":
			a.box(Vector3(0,2,0),Vector3(12,4,8),wood)
			for x in [-5,5]:a.box(Vector3(x,5,0),Vector3(.5,10,.5),trim)
			a.roof(14,10,9)
			for i in range(7):a.box(Vector3(-5.5+i*1.8,6,4.2),Vector3(1.8,.6,1.5),trim if i%2 else snow)
			for x in [-3,0,3]:a.sphere(Vector3(x,4.8,3),.7,trim)
	# Distinct silhouettes carry the named theme into the new holiday set.
	if style=="pastel":a.sphere(Vector3(0,14,0),4,snow,Vector3(1,.3,1))
	elif style=="bauhaus":a.box(Vector3(4,14,-2),Vector3(5,5,5),trim)
	elif style=="neon_noir":a.box(Vector3(0,11,5),Vector3(17,.35,.6),trim)
	elif style=="aurora_ink":a.sphere(Vector3(-3,14,0),5,trim,Vector3(1.4,.13,.8))
	elif style=="comic":a.cone(Vector3(4,15,0),2,4,trim,.1)
	elif style=="crisp":a.box(Vector3(0,14,-3),Vector3(17,.5,5),snow)
	elif style=="piste_map":a.box(Vector3(0,14,0),Vector3(12,.3,9),wood)
	elif style=="cinematic":a.cone(Vector3(-5,14,-3),.8,7,wood,.8)
	var mesh:=a.finish()
	return Lines.bounds_model(mesh) if style=="monochrome" else mesh
static func dressing(kind: String,level: int,style: String,phase: String) -> ArrayMesh:
	var s:=Assets.dimensions(kind,level)
	var h: float=2 if kind in ["pool","spa","viewpoint","snowpark"] else s.y
	if style=="monochrome":
		var a:=Lines.new()
		for x in [-s.x*.4,0,s.x*.4]:
			a.line(Vector3(x-1.2,h+2,s.z*.5+.4),Vector3(x+1.2,h+2,s.z*.5+.4))
			a.line(Vector3(x,h+.8,s.z*.5+.4),Vector3(x,h+3.2,s.z*.5+.4))
		a.line(Vector3(-s.x*.45,h,s.z*.5+.3),Vector3(s.x*.45,h,s.z*.5+.3))
		return a.finish()
	var a:=Art.new()
	var gold:=Color(str(Styles.ui_palette(style).accent))
	var foliage:=Color(str(Styles.detail_tints(style).flora))
	var red:=Color("d55c65") if style!="neon_noir" else Color("ff6ad4")
	var snow:=Color(str(Styles.detail_tints(style).snow))
	for i in range(13):
		var t: float=float(i)/12.0
		var x: float=lerpf(-s.x*.45,s.x*.45,t)
		var y: float=h-1.2*sin(t*PI)
		a.sphere(Vector3(x,y,s.z*.5+.35),.5,foliage)
		a.sphere(Vector3(x,y-.2,s.z*.5+.7),.18,gold if i%3 else red)
	# Wreath is above the door, never on a pedestrian approach.
	for i in range(12):
		var angle: float=TAU*i/12.0
		a.sphere(Vector3(cos(angle)*1.3,8+sin(angle)*1.3,s.z*.5+.9),.4,foliage)
	a.box(Vector3(0,7,s.z*.5+1),Vector3(1.5,.6,.4),red)
	for x in [-s.x*.35,s.x*.35]:
		a.cone(Vector3(x,h+2,0),1.4,3.5,snow,.1)
		a.sphere(Vector3(x,h+4,0),.4,gold)
	if phase in ["new_year_eve","new_year"]:
		a.box(Vector3(0,h+4,0),Vector3(8,3,.5),gold)
		for x in [-2,0,2]:a.box(Vector3(x,h+4,.35),Vector3(.4,1.6,.2),snow)
	return a.finish()
