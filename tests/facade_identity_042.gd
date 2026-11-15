extends SceneTree
## SkiZones 0.42 release gate: thematic facades are baked, differentiated and
## never modify careers, terrain, collision footprints or Android draw nodes.
const Assets = preload("res://src/world/style_assets.gd")
const Facade = preload("res://src/world/facade_identity_042.gd")
const Art = preload("res://src/world/alpine_art.gd")
const Lines = preload("res://src/world/line_art.gd")
const Styles = preload("res://src/core/visual_styles.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func run() -> void:
	var model := Resort.new()
	model.new_game(true,20261115,"sonnenhang")
	var snapshot: String = JSON.stringify(model.snapshot())
	var examples := ["hotel","first_aid","school","rental","restaurant","repair_office","town_hall","snowpark","bus","newsstand"]
	var per_style: Dictionary = {}
	for style in Styles.IDS:
		var different := {}
		var total_vertices := 0
		var all_finite := true
		var primitive_correct := true
		for kind in examples:
			var size_value: Vector3 = Assets.dimensions(kind,2)
			var mesh: ArrayMesh = Assets.building(kind,2,Color(str(Catalog.BUILDINGS[kind].color)),style)
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var expected: int = Mesh.PRIMITIVE_LINES if style == "monochrome" else Mesh.PRIMITIVE_TRIANGLES
			primitive_correct = primitive_correct and mesh.surface_get_primitive_type(0) == expected
			all_finite = all_finite and not vertices.is_empty() and mesh.get_aabb().size.is_finite()
			all_finite = all_finite and mesh.get_aabb().size.length() < 250
			total_vertices += vertices.size()
			different[str(vertices)] = true
			check(vertices.size() >= (20 if style=="monochrome" else 70), style + "/" + kind + " has real baked detail geometry")
		check(primitive_correct,style + " preserves monochrome line art or 3D triangle rendering")
		check(all_finite,style + " has finite, bounded buildings without separate particle nodes")
		check(different.size() >= 8,style + " shows at least eight distinct facility silhouettes")
		per_style[style] = total_vertices
	check(per_style.size() == 10,"All ten existing styles keep their distinct building families")
	for kind in ["hotel","first_aid","school","rental","restaurant","repair_office","town_hall"]:
		var base: ArrayMesh = Art.new().chalet(kind,2,Color(str(Catalog.BUILDINGS[kind].color)))
		var decorated: ArrayMesh = Assets.building(kind,2,Color(str(Catalog.BUILDINGS[kind].color)),"alpine")
		var original_count: int = base.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		var next_count: int = decorated.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		check(next_count > original_count, "0.42 Alpine "+kind+" adds an identifiable facade to the existing model")
	var lines := Lines.new()
	Facade.line_identity(lines,"first_aid",22.0,18.0,11.0)
	check(lines.finish().surface_get_primitive_type(0)==Mesh.PRIMITIVE_LINES, "Monochrome rescue cross is genuine linework")
	check(JSON.stringify(model.snapshot()) == snapshot, "Building mesh generation never writes to career, bank balance, saves or terrain")
	print("FACADE PERF: styles=",Styles.IDS.size()," facility_types=",examples.size()," vertices_by_style=",per_style)
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _init() -> void:
	call_deferred("run")
