extends RefCounted
## Presentation-only reactions to *actual* guests at venues. Never changes saved buildings.
const Catalog = preload("res://src/core/catalog.gd")
const Styles = preload("res://src/core/visual_styles.gd")
const WARM := ["lodge", "hotel", "grand_hotel", "guesthouse", "restaurant", "cocoa", "schmarrn", "pizzeria", "spa", "pool", "bar"]
const SERVICE := ["rental", "school", "bus", "maintenance", "repair_office", "first_aid", "souvenir", "watchmaker", "craftshop", "town_hall", "printing_press", "newsstand"]

var entries: Array = []
var _time := 0.0
var _refresh := 0.0
var _puff_mesh: SphereMesh
var _signal_mesh: BoxMesh

static func party_level(people: int) -> int:
    if people >= 20: return 3
    if people >= 10: return 2
    if people >= 5: return 1
    return 0

static func inside_counts(guests: Array) -> Dictionary:
    # "visits" is lifetime throughput, not instantaneous occupancy; never use it.
    var counts: Dictionary = {}
    for guest in guests:
        if not guest is Dictionary or guest.get("phase", "") != "moving": continue
        var itinerary: Dictionary = guest.get("route", {})
        var legs: Array = itinerary.get("legs", [])
        var current: int = int(guest.get("leg", -1))
        if current < 0 or current >= legs.size(): continue
        var leg: Dictionary = legs[current]
        if leg.get("kind", "") != "visit" or leg.get("pause_only", false): continue
        var id: int = int(leg.get("id", -1))
        if id < 0: continue
        counts[id] = int(counts.get(id, 0)) + maxi(1, int(guest.get("group_size", 1)))
    return counts

func clear() -> void:
    entries.clear()
    _time = 0.0
    _refresh = 0.0

func _color(style: String) -> Color:
    return Color(str(Styles.ui_palette(style).accent))

func register(building: Dictionary, mesh: MeshInstance3D, style: String) -> void:
    var kind: String = str(building.get("kind", ""))
    var size: Vector3 = preload("res://src/world/style_assets.gd").dimensions(kind, int(building.get("level", 1)))
    var data := {"id":int(building.id), "kind":kind, "mesh":mesh, "notes":[], "accent":null, "base_y":size.y + 2.5}
    if kind == "disco":
        for i in range(2):
            var note := Label3D.new()
            note.text = "♪" if i == 0 else "♫"
            note.font_size = 74
            note.pixel_size = 0.055
            note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            note.no_depth_test = false
            note.outline_size = 5
            note.outline_modulate = Color("182a39")
            note.modulate = _color(style)
            note.position = Vector3(-6.0 if i == 0 else 6.0, size.y + 3.0, 0.0)
            note.visible = false
            mesh.add_child(note)
            data.notes.append(note)
    elif kind in WARM:
        if _puff_mesh == null:
            _puff_mesh = SphereMesh.new()
            _puff_mesh.radius = 1.0
            _puff_mesh.height = 1.7
            _puff_mesh.radial_segments = 6
            _puff_mesh.rings = 3
        var wisp := MeshInstance3D.new()
        wisp.mesh = _puff_mesh
        wisp.material_override = _puff_material(style)
        wisp.position = Vector3(size.x * 0.24, size.y + 2.5, -size.z * 0.18)
        wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.add_child(wisp)
        data.accent = wisp
    elif kind in SERVICE:
        if _signal_mesh == null:
            _signal_mesh = BoxMesh.new()
            _signal_mesh.size = Vector3(1.4, 0.22, 1.0)
        var flag := MeshInstance3D.new()
        flag.mesh = _signal_mesh
        flag.material_override = _signal_material(style)
        flag.position = Vector3(size.x * 0.30, size.y + 1.0, 0)
        flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.add_child(flag)
        data.accent = flag
    entries.append(data)

func _puff_material(style: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("dce9ee") if style != "monochrome" else Color("bbbbbb")
    material.roughness = 1.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material

func _signal_material(style: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = _color(style)
    material.roughness = 0.8
    return material

func restyle(style: String) -> void:
    for entry in entries:
        for note in entry.notes: note.modulate = _color(style)
        if entry.accent != null:
            entry.accent.material_override = _puff_material(style) if entry.kind in WARM else _signal_material(style)

func update(view: Node3D, delta: float) -> void:
    _time += delta
    _refresh += delta
    if _refresh < 0.10: return
    _refresh = 0.0
    if view.model == null: return
    var present := inside_counts(view.model.guests)
    for entry in entries:
        var mesh: MeshInstance3D = entry.mesh
        if not is_instance_valid(mesh): continue
        var building: Dictionary = view.model.asset(int(entry.id))
        if building.is_empty(): continue
        var near: bool = Vector2(mesh.position.x, mesh.position.z).distance_to(view.focus) < minf(520.0, view.zoom * 1.45)
        var enabled: bool = bool(building.get("enabled", true))
        var guests: int = int(present.get(int(entry.id), 0)) if enabled else 0
        var phase: float = _time * 1.9 + float(int(entry.id) % 23) * 0.7
        if entry.kind == "disco":
            var level: int = party_level(guests)
            var sway: float = [0.0, 0.006, 0.019, 0.035][level]
            var growth: float = 1.0 + (0.085 if level == 3 else 0.025 if level == 2 else 0.0)
            mesh.rotation.z = sin(phase * (1.7 if level > 1 else 1.0)) * sway if near else 0.0
            mesh.scale = Vector3(growth, 1.0 + (growth - 1.0) * 0.3, growth) if near else Vector3.ONE
            for i in range(entry.notes.size()):
                var note: Label3D = entry.notes[i]
                note.visible = near and view.effects_enabled and view.quality_tier > 0 and level >= (1 if i == 0 else 2)
                note.position.y = float(entry.base_y) + float(i) * 3.0 + sin(phase * 2.0 + i) * (1.3 + level * 0.4)
                note.rotation.z = sin(phase * 0.8 + i) * 0.08
        elif entry.accent != null:
            var accent: MeshInstance3D = entry.accent
            accent.visible = near and enabled and view.effects_enabled and view.quality_tier > 0
            if not accent.visible: continue
            if entry.kind in WARM:
                accent.position.y = float(entry.base_y) + sin(phase * 0.6) * 0.8
                accent.scale = Vector3(0.65, 0.5, 0.65) * (0.75 + 0.2 * sin(phase))
            else:
                accent.rotation.y = sin(phase * 0.8) * 0.25
