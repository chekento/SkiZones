extends SceneTree
const Assets=preload("res://src/world/style_assets.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Festival=preload("res://src/world/festive_buildings.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const Catalog=preload("res://src/core/catalog.gd")
const Preferences=preload("res://src/core/preferences.gd")
const Crew=preload("res://src/world/crew_life.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(value: bool,label_text: String) -> void:
	if value:passed+=1;print("PASS ",label_text)
	else:failed+=1;push_error("FAIL "+label_text)
func run() -> void:
	check(Styles.IDS.size()==10,"Ten named styles include monochrome line art")
	var hotel_shapes: Dictionary={}
	var stations: Dictionary={}
	var crew_homes: Dictionary={}
	for style in Styles.IDS:
		var hotel: ArrayMesh=Assets.building("hotel",2,Color("aabbcc"),style)
		hotel_shapes[str(hotel.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])]=true
		var station: ArrayMesh=Assets.station("chair2",1,"",style)
		stations[str(station.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])]=true
		var home: ArrayMesh=Crew.lodge_mesh(style)
		crew_homes[str(home.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])]=true
		if style=="monochrome":check(home.surface_get_primitive_type(0)==Mesh.PRIMITIVE_LINES,"Staff accommodation also uses sparse monochrome lines")
		var valid:=true
		for kind in Catalog.BUILDINGS:
			var mesh: ArrayMesh=Assets.building(kind,1,Color(Catalog.BUILDINGS[kind].color),style)
			valid=valid and mesh.get_surface_count()>0 and mesh.get_aabb().size.is_finite()
			if style=="monochrome":valid=valid and mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_LINES
		check(valid,style+" has nonempty building assets for every existing type")
		for kind in Festival.KINDS:
			var mesh: ArrayMesh=Festival.make(kind,style)
			check(mesh.get_surface_count()>0 and mesh.get_aabb().size.length()>10,"Holiday building "+kind+"/"+style)
		var dressed: ArrayMesh=Festival.dressing("hotel",2,style,"christmas")
		check(dressed.get_surface_count()>0,"Real hotel roof dressing in "+style)
	check(hotel_shapes.size()==10,"Every theme changes actual hotel geometry")
	check(stations.size()==10,"Every theme changes actual station geometry")
	check(crew_homes.size()==10,"Staff accommodation follows all ten architectural styles")
	var pref:=Preferences.new();pref.path="user://line-art-032.cfg";pref.visual_style="monochrome";pref.save_to()
	var restored:=Preferences.new();restored.path=pref.path;restored.load_from()
	check(restored.visual_style=="monochrome","Monochrome survives settings reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pref.path))
	var calendar:=Calendar.new();calendar.path="user://festive-assets-032.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(calendar.path))
	for day in range(1,25):calendar.claim(day,{"year":2026,"month":12,"day":24})
	for kind in Festival.KINDS:check(calendar.buy_decoration(kind).ok,"Actual holiday catalogue purchase: "+kind)
	var restored_calendar:=Calendar.new();restored_calendar.path=calendar.path
	check(Festival.KINDS.all(func(kind):return kind in restored_calendar.overview({"year":2026,"month":12,"day":24}).owned),"All four new festive purchases survive archive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(calendar.path))
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
