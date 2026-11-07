extends SceneTree
## Regression: readable snow on snow, elevated piste junctions, seasonal
## campaign rotation and shared original-image/text composition.
const Surfaces=preload("res://src/world/walk_surfaces.gd")
const Campaign=preload("res://src/core/seasonal_campaign.gd")
const Card=preload("res://src/ui/seasonal_poster_card.gd")
const Preview=preload("res://src/ui/seasonal_poster.gd")
var passed:=0
var failed:=0

class View:
	extends Node3D
	var visual_style: String="alpine"
	var _pedestrian_snapshot: Dictionary={}
	func ground_position(at: Vector2,offset:float=0.0) -> Vector3:
		return Vector3(at.x,offset,at.y)
	func surface_position(at:Vector2) -> Vector3:
		return Vector3(at.x,0.8 if at.x>=4.0 else 0.0,at.y)

func check(ok:bool,detail:String) -> void:
	if ok:passed+=1;print("PASS ",detail)
	else:failed+=1;push_error("FAIL "+detail)
func _init() -> void:call_deferred("run")

func run() -> void:
	var dates:Array=[
		{"year":2026,"month":11,"day":7},
		{"year":2026,"month":12,"day":7},
		{"year":2026,"month":12,"day":27},
		{"year":2026,"month":12,"day":31},
		{"year":2027,"month":1,"day":1}
	]
	for date in dates:
		var alternatives:Dictionary={}
		for index in range(6):
			var poster:Dictionary=Campaign.choose(date,index)
			check(not poster.is_empty() and poster.has("image") and poster.has("date") and poster.has("motif"),
				"Campaign has artwork, title and event date: "+str(date))
			alternatives[str(poster.motif)]=true
			check(poster==Campaign.choose(date,index),"Poster variant is stable across renders")
		check(alternatives.size()>1,"Adjacent kiosks offer different motifs")
	var view:=View.new()
	root.add_child(view)
	var layout:Dictionary={"areas":[],"links":[{"points":[[0,0],[20,0]],"width":8.0,"surface":"snow","manual":true}]}
	var mesh:ArrayMesh=Surfaces.new().build(view,layout)
	check(mesh.get_surface_count()>0,"Built footpath has a visible world mesh")
	var verts:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var colors:PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var covered:=0
	var buried:=0
	var contrasted:=0
	for i in range(verts.size()):
		if verts[i].x>6 and verts[i].x<18:
			covered+=1
			if verts[i].y<0.89:buried+=1
		if verts[i].x>1 and verts[i].x<18 and colors[i].get_luminance()<0.75:contrasted+=1
	check(covered>0 and buried==0,"Visible path clears raised piste snow along the whole intersection")
	check(contrasted>0,"Snow path retains cool, contrasted snow-on-snow material")
	var item:Dictionary=Campaign.choose(dates[0],1)
	var card:=Card.new()
	card.size=Vector2(640,420)
	root.add_child(card)
	card.configure("alpine",item)
	check(card.headline.text==item.title and card.date_text.text==item.date,"World poster prints legible event title and tilted date separately from artwork")
	check(card.photo.texture==null and card.art.motif==item.motif,"Missing optional artwork uses correct motif, without a blank board")
	card.queue_free()
	var preview:=Preview.new()
	root.add_child(preview)
	preview.open("alpine",item)
	check(preview.poster.headline.text==item.title and preview.poster.date_text.text==item.date,"Tapped advertisement preview matches the selected world poster")
	preview.queue_free()
	view.queue_free()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
