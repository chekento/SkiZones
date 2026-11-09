extends RefCounted
## Low-poly holiday props authored as original procedural meshes. The same
## physics-free geometry follows all five visual styles through color accents.
const FestiveBuildings=preload("res://src/world/festive_buildings.gd")
const Lines=preload("res://src/world/line_art.gd")
const Art = preload("res://src/world/alpine_art.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")

static func make(kind: String, style: String = "alpine") -> ArrayMesh:
	if kind in FestiveBuildings.KINDS: return FestiveBuildings.make(kind,style)
	if style=="monochrome":return Lines.new().prop(kind)
	var a := Art.new()
	var colors: Dictionary=VisualStyles.detail_tints(style)
	var snow := Color(str(colors.snow))
	var wood := Color(str(colors.wood))
	var metal := Color(str(colors.metal))
	var foliage := Color("26876b") if style=="comic" else Color("8ba89a") if style=="pastel" else Color("344f54") if style=="cinematic" else Color("248b9e") if style=="crisp" else Color("49705b")
	var red := Color("ed6675") if style=="pastel" else Color("da3446")
	var gold := Color(str(VisualStyles.ui_palette(style).accent))
	match kind:
		"tree":
			a.cone(Vector3(0,4.2,0),1.0,8.0,wood,0.8)
			for layer in range(4):
				var y := 3.2+layer*3.2
				a.cone(Vector3(0,y+2.4,0),5.0-layer*1.0,4.8,foliage,0.22)
				a.cone(Vector3(0,y+3.5,0),3.4-layer*0.7,1.0,snow,0.08)
				for n in range(7):
					var angle := float(n)*TAU/7+layer*0.5
					var at := Vector3(cos(angle)*(4.3-layer*0.8),y+1.5,sin(angle)*(4.3-layer*0.8))
					a.sphere(at,0.46,red if n%2==0 else gold)
			a.cone(Vector3(0,17.2,0),1.15,2.2,gold,0.02)
		"gifts":
			for i in range(4):
				var x := -2.8+i*1.8
				var y := 0.8 + (i%2)*0.55
				var z := -0.4+(i%2)*1.8
				var giftcolor := red if i%2==0 else metal
				a.box(Vector3(x,y,z),Vector3(2.0,1.6+(i%2),1.8),giftcolor)
				a.box(Vector3(x,y+0.05,z),Vector3(0.26,1.9+(i%2),1.92),gold)
				a.box(Vector3(x,y+0.05,z),Vector3(2.12,1.9+(i%2),0.28),gold)
				a.sphere(Vector3(x,y+1.15+(i%2)*0.4,z),0.37,gold)
		"snowman":
			a.sphere(Vector3(0,2.4,0),2.5,snow)
			a.sphere(Vector3(0,5.3,0),1.7,snow)
			for x in [-0.65,0.65]: a.sphere(Vector3(x,5.6,1.37),0.2,wood.darkened(0.45))
			a.cone(Vector3(0,5.0,1.85),0.4,1.6,Color("e89f4c"),0.02)
			a.box(Vector3(0,7.0,0),Vector3(3.1,0.5,2.7),metal)
			a.cone(Vector3(0,7.65,0),1.1,1.3,metal,0.6)
			for side in [-1,1]:
				a.link(Vector3(side*1.6,3.7,0),Vector3(side*4.2,4.8,0.4),0.13,wood)
		"lanterns":
			a.link(Vector3(0,0,0),Vector3(0,10,0),0.25,wood)
			for z in [-1.5,1.5]:
				a.box(Vector3(0,8.4,z),Vector3(1.6,2.6,1.5),metal)
				a.box(Vector3(0,8.5,z+0.84),Vector3(1.3,2.1,0.15),gold)
				a.cone(Vector3(0,10.0,z),1.1,0.9,snow,0.05)
		"star":
			a.link(Vector3(0,0,0),Vector3(0,10.2,0),0.22,wood)
			for index in range(10):
				var angle := float(index)*TAU/10.0
				var direction := Vector3(cos(angle),sin(angle),0)
				a.link(Vector3(0,11,0),Vector3(0,11,0)+direction*(2.7 if index%2==0 else 1.5),0.20,gold)
			a.sphere(Vector3(0,11,0),0.9,gold)
		"garlands":
			a.link(Vector3(-6,5.2,0),Vector3(-6,0,0),0.23,wood)
			a.link(Vector3(6,5.2,0),Vector3(6,0,0),0.23,wood)
			for index in range(13):
				var t:=float(index)/12.0
				var x:float=lerpf(-6,6,t)
				var y:=5.0-1.3*sin(t*PI)
				a.sphere(Vector3(x,y,0),0.78,foliage)
				a.sphere(Vector3(x,y-0.2,0.65),0.23,red if index%3==0 else gold)
		"clock":
			for x in [-4.0,4.0]: a.box(Vector3(x,5.0,0),Vector3(0.4,10,0.5),wood)
			a.box(Vector3(0,9.6,0),Vector3(10.5,5.0,1.0),metal)
			a.box(Vector3(0,9.6,0.55),Vector3(9.5,4.1,0.15),Color("19344e"))
			for i in range(4):
				var x:float=-3.5+i*2.3
				a.box(Vector3(x,9.7,0.70),Vector3(1.0,0.35,0.12),gold)
			a.cone(Vector3(0,12.7,0),2.7,1.8,snow,0.1)
		"market":
			a.box(Vector3(0,1.5,0),Vector3(10,3,7),wood)
			a.box(Vector3(0,4.3,0),Vector3(12,0.5,8),snow)
			for x in [-5.2,5.2]:
				for z in [-3.6,3.6]: a.link(Vector3(x,0,z),Vector3(x,7,z),0.25,wood)
			a.box(Vector3(0,7.2,0),Vector3(12.7,0.65,8.7),red)
			for x in [-4,-2,0,2,4]: a.sphere(Vector3(x,5.1,4),0.5,gold)
			for i in range(3): a.box(Vector3(-2+i*2,2.8,4.2),Vector3(1.5,0.8,1.0),metal if i%2==0 else gold)
		"bell":
			a.link(Vector3(0,0,0),Vector3(0,7,0),0.18,wood)
			a.cone(Vector3(0,7.6,0),1.8,2.5,gold,0.4)
			a.sphere(Vector3(0,6.1,0),0.5,wood)
		"poster":
			# 16:9 landscape billboard. Outer border 14 x 8, picture exactly
			# 12.8 x 7.2 world units. The picture is a separate quad so the
			# decorative frame never covers the actual PMDD depth artwork.
			for x in [-6.85,6.85]:
				a.box(Vector3(x,4.4,0),Vector3(.46,8.8,.65),wood)
				a.sphere(Vector3(x,8.7,0),.42,red)
			a.box(Vector3(0,4.4,0),Vector3(14.0,8.15,.64),gold)
			a.box(Vector3(0,4.4,.35),Vector3(12.8,7.2,.12),Color("263952") if style!="bauhaus" else Color("d95d4a"))
			a.box(Vector3(0,8.63,0),Vector3(14.3,.52,.90),snow)
			a.sphere(Vector3(0,9.1,0),.55,red)
		"firework":
			for i in range(12):
				var ang:=float(i)*TAU/12.0
				var direction:=Vector3(cos(ang),sin(ang),0)
				a.link(Vector3.ZERO,direction*4.5,0.10,gold if i%2==0 else red)
				a.sphere(direction*5,0.35,gold)
	var mesh:=a.finish()
	return Lines.bounds_model(mesh) if style=="monochrome" else mesh

