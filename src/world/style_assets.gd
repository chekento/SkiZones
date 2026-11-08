extends RefCounted
## Theme architecture is rebuilt inside the original footprint, never in saves.
const Art=preload("res://src/world/alpine_art.gd")
const Lines=preload("res://src/world/line_art.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Catalog=preload("res://src/core/catalog.gd")
static func dimensions(kind: String,level: int=1) -> Vector3:
	if kind.begins_with("wc_"):
		# A newly placed Portable Toilet visibly grows into the next sanitation
		# architecture without changing its stable saved building kind.
		var index:int=clampi(level-1,0,4) if kind=="wc_dixi" else ["wc_dixi","wc_cabin","wc_module","wc_house","wc_luxury"].find(kind)
		var widths:Array=[6.4,11.0,17.0,23.0,30.0]
		var depths:Array=[6.8,9.0,12.0,17.0,22.0]
		var heights:Array=[9.5,10.5,11.0,13.0,16.0]
		return Vector3(widths[maxi(0,index)],heights[maxi(0,index)],depths[maxi(0,index)])
	var big: bool=kind in ["hotel","grand_hotel","guesthouse"]
	var wide: bool=kind in ["maintenance","repair_office"]
	var width:=44.0 if kind=="grand_hotel" else 16.0 if kind=="cabin" else 35.0 if kind=="hotel" else 29.0 if wide else 22.0
	var depth:=32.0 if kind=="grand_hotel" else 14.0 if kind=="cabin" else 28.0 if kind=="hotel" else 24.0 if wide else 18.0
	var floors:=3+int(level>=2) if kind=="grand_hotel" else 2+int(level>=2) if big else 1+int(level==3)
	return Vector3(width,floors*8.0+3.0,depth)
static func building(kind: String,level: int,accent: Color,style: String) -> ArrayMesh:
	style=Styles.valid(style)
	if kind.begins_with("wc_"):
		if style=="monochrome":
			var drawing:=Lines.new()
			var size_value:Vector3=dimensions(kind,level)
			drawing.box(Vector3(0,size_value.y*0.5,0),size_value)
			drawing.box(Vector3(0,size_value.y*0.42,size_value.z*0.5),Vector3(minf(4,size_value.x*0.45),size_value.y*0.67,0.3))
			drawing.line(Vector3(-2,size_value.y*0.8,size_value.z*0.5+0.4),Vector3(2,size_value.y*0.8,size_value.z*0.5+0.4))
			return drawing.finish()
		var wc_kind: String=["wc_dixi","wc_cabin","wc_module","wc_house","wc_luxury"][clampi(level-1,0,4)] if kind=="wc_dixi" else kind
		return Art.new().public_toilet(wc_kind,level,accent,style)
	if style=="alpine": return Art.new().chalet(kind,level,accent)
	var s:=dimensions(kind,level)
	var w:=s.x;var h:=s.y;var d:=s.z
	if style=="monochrome":
		var a:=Lines.new()
		if kind=="snowmaker":
			a.box(Vector3(0,4,0),Vector3(8,5,8));a.line(Vector3(-4,0,0),Vector3(0,6,0));a.line(Vector3(4,0,0),Vector3(0,6,0))
		elif kind in ["pool","spa"]:
			a.box(Vector3(0,1,0),Vector3(w,2,d));a.line(Vector3(-w*.4,2,0),Vector3(w*.4,2,0))
		else:
			a.box(Vector3(0,h*.5,0),s);a.roof(w,d,h)
			a.box(Vector3(0,3,d*.5+.05),Vector3(3,6,0.1))
			for x in [-w*.28,w*.28]: a.box(Vector3(x,h*.6,d*.5+.05),Vector3(4,3,0.1))
			if kind in ["first_aid","repair_office"]:
				a.line(Vector3(-2,h+3,d*.5),Vector3(2,h+3,d*.5));a.line(Vector3(0,h+1,d*.5),Vector3(0,h+5,d*.5))
		return a.finish()
	# Outdoor and mechanical objects retain recognisable function and a distinct
	# themed canopy, instead of silently turning every service into a house.
	var a:=Art.new()
	var palette: Dictionary=Styles.detail_tints(style)
	var body:=Color(str(palette.wood)).lerp(accent,0.25)
	var snow:=Color(str(palette.snow));var trim:=Color(str(Styles.ui_palette(style).accent))
	if kind in ["snowmaker","pool","spa","viewpoint","shelter","snowpark","bus","kiosk"]:
		a.add(Art.new().chalet(kind,level,accent),Vector3.ZERO,Color.WHITE,Vector3.ZERO,Vector3.ONE,true)
		var index: int=Styles.IDS.find(style)
		for x in [-5,5]:a.box(Vector3(x,3,-5),Vector3(0.4+index*.05,6+index*.2,0.45),trim)
		if style in ["pastel","aurora_ink"]:a.sphere(Vector3(0,7,-5),5.7,trim,Vector3(1,.15+index*.015,.3))
		elif style=="bauhaus":a.box(Vector3(2,7,-5),Vector3(8,3,2),trim);a.cone(Vector3(-4,8,-5),1.5,4,body,1.5)
		elif style=="comic":a.cone(Vector3(0,8,-5),3.0,5,trim,.1)
		else:a.box(Vector3(0,6+index*.2,-5),Vector3(11+index*.15,0.5+index*.09,1.0),trim)
		return a.finish()
	match style:
		"comic":
			# Deliberately exaggerated cartoon architecture, not a color filter:
			# oversized silhouette, thick ink-like framing, huge dormers,
			# chunky snowcap and high-contrast window geometry.
			var ink := Color("192443")
			var candy := Color("ffcd57")
			a.soft_box(Vector3(0,h*.5,0),Vector3(w*1.08,h,d*1.06),body.lightened(.16),Vector3.ZERO,1.8)
			a.box(Vector3(0,h+1.5,0),Vector3(w*1.18,3.2,d*1.17),ink)
			a.roof(w*1.2,d*1.13,h+3.0)
			# Roof snow is an actual oversized mesh volume.
			a.soft_box(Vector3(0,h+7,0),Vector3(w*1.16,2.8,d*.48),snow,Vector3.ZERO,1.6)
			for side in [-1,1]:
				a.soft_box(Vector3(side*w*.31,h+8,d*.07),Vector3(w*.23,11,d*.28),trim,Vector3.ZERO,1.3)
				a.box(Vector3(side*w*.31,h+8,d*.22),Vector3(w*.14,5,.9),ink)
				a.box(Vector3(side*w*.31,h+8,d*.23),Vector3(w*.10,3,1.1),candy)
				a.box(Vector3(side*w*.48,h*.5,0),Vector3(2.2,h*1.03,d*1.08),ink)
			for x in [-w*.29,w*.29]:
				a.box(Vector3(x,h*.55,d*.54),Vector3(6.8,6.8,1.5),ink)
				a.box(Vector3(x,h*.55,d*.58),Vector3(4.8,4.8,1.5),Color("86e7ff"))
				a.box(Vector3(x,h*.55,d*.65),Vector3(.9,5.0,.45),ink)
				a.box(Vector3(x,h*.55,d*.66),Vector3(5.0,.9,.45),ink)
			a.soft_box(Vector3(0,3.6,d*.57),Vector3(5.2,7.2,1.6),ink,Vector3.ZERO,.9)
			a.box(Vector3(0,4,d*.67),Vector3(3.4,5.4,1),candy)
		"pastel":
			a.soft_box(Vector3(0,h*.5,0),s,body.lightened(.2),Vector3.ZERO,2)
			a.sphere(Vector3(0,h,0),w*.52,snow,Vector3(1,.36,d/w))
			for x in [-w*.35,w*.35]:a.cone(Vector3(x,h*.5,0),1.4,h,trim,1.4)
		"cinematic":
			a.box(Vector3(0,h*.5,0),s,body.darkened(.14))
			a.roof(w+1,d,h)
			for x in [-.43,-.23,0,.23,.43]:a.box(Vector3(w*x,h*.5,d*.5+.25),Vector3(.45,h,.5),trim.darkened(.5))
			a.box(Vector3(-w*.3,h+5,-d*.15),Vector3(2.4,10,2.4),Color(str(palette.stone)))
		"crisp":
			a.box(Vector3(0,h*.5,0),s,Color("a2cbd7"))
			a.box(Vector3(0,h,0),Vector3(w+2,1.4,d+2),snow)
			for i in range(7):a.box(Vector3(-w*.45+i*w*.15,h*.55,d*.5+.4),Vector3(.4,h*.8,.9),trim)
			a.box(Vector3(0,h+3,-d*.25),Vector3(w*.7,5,d*.35),Color("d6f3f6"))
		"piste_map":
			a.box(Vector3(0,h*.45,0),Vector3(w,h*.9,d),body)
			a.roof(w,d,h*.9)
			for y in range(3,int(h),3):a.box(Vector3(0,y,d*.5+.15),Vector3(w,.18,.3),Color("455649"))
			a.box(Vector3(0,h+3,d*.5+1),Vector3(w*.65,4,.5),snow)
		"neon_noir":
			a.box(Vector3(0,h*.5,0),s,Color("24253e"))
			a.box(Vector3(w*.15,h+2,0),Vector3(w*.7,4,d*.85),Color("3c416b"))
			for y in [1.0,h*.5,h]:a.box(Vector3(0,y,d*.5+.4),Vector3(w,.35,.7),trim)
			for x in [-w*.48,w*.48]:a.box(Vector3(x,h*.5,d*.5+.4),Vector3(.45,h,.7),Color("6ceaff"))
			a.box(Vector3(-w*.23,h+5,0),Vector3(w*.23,6,d*.5),trim)
		"aurora_ink":
			a.soft_box(Vector3(0,h*.5,0),s,body,Vector3.ZERO,1.6)
			for tier in range(3):
				a.sphere(Vector3(sin(tier*1.7)*w*.08,h+tier*1.5,0),w*.55,snow.lerp(trim,tier*.17),Vector3(1,.12,d/w))
			a.cone(Vector3(-w*.35,h*.5,0),1.0,h+4,trim,.25)
		"bauhaus":
			a.box(Vector3(-w*.12,h*.45,0),Vector3(w*.76,h*.9,d),Color("e8d8b3"))
			a.box(Vector3(w*.34,h*.6,0),Vector3(w*.28,h*1.2,d*.65),Color("b8563f"))
			a.box(Vector3(-w*.12,h*.9,0),Vector3(w*.8,.8,d+1),Color("25477c"))
			a.cone(Vector3(-w*.28,h+2,0),w*.11,4,trim,w*.11)
	# Doors, windows and a functional sign remain legible in every architecture.
	a.box(Vector3(0,3,d*.5+.5),Vector3(3,6,.7),body.darkened(.4))
	for x in [-w*.28,w*.28]:a.box(Vector3(x,h*.56,d*.5+.4),Vector3(4,3,.6),snow.lerp(trim,.3))
	a._facade_details(kind,w,d,h,trim)
	var sign_color:=Color("e35660") if kind=="first_aid" else trim
	a.box(Vector3(0,h*.8,d*.5+.6),Vector3(6,1.1,.7),sign_color)
	return a.finish()
static func station(kind: String,level: int,livery: String,style: String) -> ArrayMesh:
	var source:=Art.new().station(kind,level,livery)
	if style=="alpine":return source
	if style=="monochrome":
		var a:=Lines.new();a.box(Vector3(0,5,0),Vector3(12,10,16));a.roof(14,18,10)
		a.line(Vector3(-7,11,0),Vector3(7,11,0));return a.finish()
	var a:=Art.new();a.add(source,Vector3.ZERO,Color.WHITE,Vector3.ZERO,Vector3.ONE,true)
	var color:=Color(str(Styles.ui_palette(style).accent))
	var index: int=Styles.IDS.find(style)
	if style=="pastel":a.sphere(Vector3(0,10,0),8,color,Vector3(1,.2,1.2))
	elif style=="aurora_ink":
		for side in [-1,1]:a.sphere(Vector3(side*3,10+side*.6,0),6,color,Vector3(1.1,.23,1.5))
	elif style=="bauhaus":a.box(Vector3(3,10,0),Vector3(8,3,14),color);a.cone(Vector3(-4,12,0),2,7,color,2)
	else:
		a.box(Vector3(0,8+index*.15,0),Vector3(14+index*.15,.7+index*.07,17),color)
		for side in [-1,1]:a.box(Vector3(side*6.5,5,0),Vector3(.4,10,16),color)
	return a.finish()
