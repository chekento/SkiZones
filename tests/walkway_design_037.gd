extends SceneTree
const Design = preload("res://src/core/walkway_design.gd")
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ",message)
	else: failed += 1; push_error("FAIL " + message)
func _init() -> void:
	var stroke: Array = []
	for i in range(101): stroke.append([float(i)*2,30*sin(float(i)*PI/100)])
	var points := Design.waypoints(stroke)
	check(points.size()>2 and points.size()<30 and Terrain.unpack(points.front()).distance_to(Terrain.unpack(stroke.front()))<0.001 and Terrain.unpack(points.back()).distance_to(Terrain.unpack(stroke.back()))<0.001,"A curved stroke retains its endpoints and becomes a small editable polyline")
	var error := 0.0
	for row in stroke:
		var nearest := INF
		for i in range(1,points.size()): nearest=minf(nearest,Terrain.unpack(row).distance_to(Geometry2D.get_closest_point_to_segment(Terrain.unpack(row),Terrain.unpack(points[i-1]),Terrain.unpack(points[i]))))
		error=maxf(error,nearest)
	check(error<=1.51,"Generated waypoints stay within 1.5 metres of the actual drawn curve")
	check(Design.waypoints([[0,0],[NAN,2]]).is_empty(),"Invalid strokes cannot enter geometry")
	var complex: Array = []
	for i in range(150): complex.append([i*4,20 if i%2 else -20])
	check(Design.waypoints(complex).is_empty(),"An over-complex stroke is rejected rather than losing its end")
	var costs: Array = []
	for surface in Design.SURFACES:
		var model := Resort.new()
		model.new_game(true)
		model.money=3000000
		var route := [Terrain.pack(Terrain.BASE),[330,190],[340,-160],Terrain.pack(Foot.boarding_point(model.lifts[0],true))]
		var preview: Dictionary = model.preview_walkway(route,surface)
		check(preview.ok and preview.surface==surface,"Real terrain and obstacle checks accept the connected "+surface+" route")
		costs.append(preview.get("cost",0))
		var result: Dictionary = model.build_walkway(route,surface)
		check(result.ok and model.walk_areas[0].surface==surface,"Construction retains the chosen "+surface+" surface")
		check(model.pedestrian_layout().links.any(func(link):return link.get("manual",false) and link.get("surface","")==surface),"Guests use the actual built "+surface+" corridor")
		var saved: Dictionary=model.snapshot()
		var restored := Resort.new()
		check(restored.restore(saved).ok and restored.walk_areas[0].surface==surface,"A "+surface+" path survives snapshot/restore")
		var broken := saved.duplicate(true)
		broken.walk_areas[0].surface="imaginary"
		check(not restored.restore(broken).ok,"An unknown saved surface is rejected atomically")
		saved.walk_areas[0].erase("surface")
		check(restored.restore(saved).ok,"Historical paths without a surface field remain loadable")
		check(not model.preview_walkway([[10000,10000],[10020,10000]],surface).ok,"Drawing outside the resort never bypasses geometry checks")
	check(costs[0]<costs[1] and costs[1]<costs[3] and costs[3]<costs[2],"Four surfaces have distinct displayed construction costs")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
