extends SceneTree
## 0.34 living-world regression: real visit legs, five tree shapes, theme-specific nature.
const Living = preload("res://src/world/living_assets.gd")
const Art = preload("res://src/world/alpine_art.gd")
const Styles = preload("res://src/core/visual_styles.gd")
var passed := 0
var failed := 0

class FakeModel:
    extends RefCounted
    var guests: Array = []
    var building := {"id":17,"kind":"disco","level":1,"enabled":true}
    func asset(id: int) -> Dictionary:
        return building if id == 17 else {}

class FakeView:
    extends Node3D
    var model: RefCounted
    var focus := Vector2.ZERO
    var zoom := 250.0
    var effects_enabled := true
    var quality_tier := 1

func _init() -> void:
    call_deferred("run")

func check(works: bool, description: String) -> void:
    if works:
        passed += 1
        print("PASS ",description)
    else:
        failed += 1
        push_error("FAIL " + description)

func guest(id: int, group: int, phase: String = "moving", at: String = "visit") -> Dictionary:
    return {"phase":phase,"leg":0,"group_size":group,"route":{"legs":[{"kind":at,"id":id,"points":[[0,0],[0,0]]}]}}

func run() -> void:
    check(Living.party_level(4)==0 and Living.party_level(5)==1 and Living.party_level(9)==1,
        "Disco starts only at five simultaneous visitors")
    check(Living.party_level(10)==2 and Living.party_level(19)==2 and Living.party_level(20)==3,
        "Ten visitors intensify music, twenty enlarge the artwork")
    var guests := [guest(17, 4),guest(17, 6),guest(18, 3),guest(17, 8, "leaving"),guest(17, 2, "moving", "ski")]
    var occupancy: Dictionary = Living.inside_counts(guests)
    check(int(occupancy.get(17,0))==10 and int(occupancy.get(18,0))==3,
        "Only currently visiting real parties count; leaving and skiing visitors do not")
    var view := FakeView.new()
    var model := FakeModel.new()
    view.model = model
    var building := MeshInstance3D.new()
    building.position = Vector3(20,0,20)
    view.add_child(building)
    var art := Living.new()
    art.register(model.building, building, "alpine")
    check(art.entries.size()==1 and art.entries[0].notes.size()==2,
        "Disco has two presentation-only musical notes")
    model.guests = [guest(17, 5)]
    art.update(view, 0.12)
    check(art.entries[0].notes[0].visible and not art.entries[0].notes[1].visible and is_equal_approx(building.scale.x,1.0),
        "Five people show subtle notes without geometry growth")
    model.guests = [guest(17, 8),guest(17, 5)]
    art.update(view, 0.12)
    check(art.entries[0].notes[1].visible and building.scale.x>1.0,
        "Ten people visibly strengthen the animation")
    model.guests = [guest(17, 8),guest(17, 8),guest(17, 7)]
    art.update(view, 0.12)
    check(building.scale.x>=1.08 and building.scale.x<=1.10,
        "Twenty people widen the visible house without moving game coordinates")
    model.building.enabled=false
    art.update(view, 0.12)
    check(is_equal_approx(building.scale.x,1.0) and not art.entries[0].notes[0].visible,
        "Disabling a venue ends its party visuals")
    model.building.enabled=true
    art.restyle("monochrome")
    check(art.entries[0].notes[0].modulate==Color(str(Styles.ui_palette("monochrome").accent)),
        "Theme switching recolors the animated notes")
    var new_trees := true
    var distinct := {}
    for species in range(5):
        var mesh: ArrayMesh = Art.new().tree_variant("cinematic",species)
        new_trees = new_trees and mesh.get_surface_count()==1 and mesh.get_aabb().size.is_finite()
        distinct[str(mesh.get_aabb())] = true
    check(new_trees and distinct.size()>=5, "All five forest species have valid differentiated 3D silhouettes")
    var props_good := true
    for style in Styles.IDS:
        for kind in range(30):
            var item: ArrayMesh = Art.new().landscape_detail(kind,style)
            props_good = props_good and item.get_surface_count()==1 and item.get_aabb().size.is_finite()
    check(props_good, "Thirty ground props generate valid meshes for all ten visual themes")
    check(load("res://src/shaders/alpine_wind.gdshader") is Shader,
        "Wind shader is an actual Godot resource")
    art.clear()
    building.free()
    view.free()
    print("RESULT: %d passed; %d failed" % [passed,failed])
    quit(1 if failed>0 else 0)
