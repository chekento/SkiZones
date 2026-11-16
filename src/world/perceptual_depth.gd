extends RefCounted
## Three fixed atmospheric strata complement foreground / subjects / forest / ridges.
## Presentation only: no physics, navigation, model writes or camera manipulation.
const MIST = preload("res://src/shaders/perceptual_mist.gdshader")
const STRATA = [Vector3(80, 9, 55), Vector3(135, 22, 90), Vector3(210, 42, 130)]
const HEIGHTS = [10.0, 38.0, 105.0]
const MAX_PER_STRATUM = 8
var root := Node3D.new()
var layers: Array[MultiMeshInstance3D] = []
var anchors: Array[Transform3D] = []
var builds := 0

func build(parent: Node3D, mountain: RefCounted) -> void:
	if root.get_parent() != null: root.get_parent().remove_child(root)
	parent.add_child(root)
	root.name = "perceptual_depth"
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	layers.clear()
	anchors.clear()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var bounds: Rect2 = mountain.bounds
	for layer in range(STRATA.size()):
		var node := MultiMeshInstance3D.new()
		node.name = "DepthStratum%d" % layer
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = sphere
		node.multimesh.instance_count = MAX_PER_STRATUM
		var material := ShaderMaterial.new()
		material.shader = MIST
		node.material_override = material
		for i in range(MAX_PER_STRATUM):
			# Fixed low-discrepancy placement, independent of camera and RNG state.
			var u := fposmod(0.19 + i * 0.618034 + layer * 0.23, 1.0)
			var v := fposmod(0.13 + i * 0.414214 + layer * 0.37, 1.0)
			var point := bounds.position + bounds.size * Vector2(0.08 + u * 0.84, 0.08 + v * 0.84)
			var scale_value: Vector3 = STRATA[layer] * (0.80 + 0.05 * i)
			var basis_value := Basis(Vector3.UP, float(i) * 0.83 + layer).scaled_local(scale_value)
			var transform_value := Transform3D(basis_value, mountain.world(point, HEIGHTS[layer]))
			node.multimesh.set_instance_transform(i, transform_value)
			anchors.append(transform_value)
		root.add_child(node)
		layers.append(node)
	builds += 1
	root.visible = false

func configure(color: Color, daylight: float, weather: int, tier: int, enabled: bool) -> void:
	var density: float = [0.035, 0.065, 0.14, 0.10, 0.05][clampi(weather, 0, 4)]
	var count: int = [0, 4, 8][clampi(tier, 0, 2)] if enabled else 0
	var tint := color.darkened(0.52 * (1.0 - clampf(daylight, 0, 1)))
	for i in range(layers.size()):
		var node := layers[i]
		node.multimesh.visible_instance_count = count
		var material: ShaderMaterial = node.material_override
		material.set_shader_parameter("mist_color", tint)
		material.set_shader_parameter("opacity", density * (1.0 - i * 0.18))

func set_camera_context(perspective: bool, building_view: bool, effects: bool, tier: int) -> void:
	root.visible = perspective and not building_view and effects and tier > 0
