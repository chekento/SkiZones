extends SceneTree
## Diagnostic inventory: reports real full return circuits by skiing ability.
## Read-only: no source geometry, save files, or game settings are modified.
const Resort = preload("res://src/core/resort.gd")
const Maps = preload("res://src/core/maps.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const Ops = preload("res://src/core/operations.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var selected: Array = Maps.FANTASY_MAPS.keys() + Geo.IDS
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--map="):
            selected = [argument.trim_prefix("--map=")]
    for map_id in selected:
        var model = Resort.new()
        model.new_game(true, 20261027, map_id)
        model.weather_index = 0
        model.minute = 600
        for lift in model.lifts:
            Ops.fill_stations(model, int(lift.id), true)
            lift.fault = ""
        Ops.refresh_duty(model)
        model._operational_change()

        # Count complete return routes for beginner, intermediate, and expert
        # independently. Expert-only coverage is NOT proof of playable pistes
        # for beginners, or of a convenient return connection.
        var circuits_by_ability: Dictionary = {}
        var covered_by_ability: Dictionary = {}
        for ability in range(3):
            var ids: Dictionary = {}
            for route in model.routes_for(ability):
                ids[int(route.target)] = true
            covered_by_ability[ability] = ids
            circuits_by_ability[str(ability)] = ids.size()

        var expert_ids: Dictionary = covered_by_ability[2]
        var missing: Array = []
        var closed: Array = []
        var missing_all: Array = []
        var missing_counts: Dictionary = {"0": 0, "1": 0, "2": 0}
        for piste in model.pistes:
            var piste_id: int = int(piste.id)
            if not model.piste_open(piste):
                closed.append({"id": piste_id, "name": piste.name})
                continue
            for ability in range(3):
                if not covered_by_ability[ability].has(piste_id):
                    var key := str(ability)
                    missing_counts[key] = int(missing_counts[key]) + 1
            if not expert_ids.has(piste_id):
                missing.append({"id": piste_id, "name": piste.name})
            if not covered_by_ability[0].has(piste_id) and not covered_by_ability[1].has(piste_id) and not expert_ids.has(piste_id):
                missing_all.append(piste_id)

        print("ROUTE_AUDIT ", JSON.stringify({
            "map": map_id,
            "pistes": model.pistes.size(),
            "complete_routes": expert_ids.size(),
            "closed": closed,
            "missing_circuit": missing,
            "complete_routes_by_ability": circuits_by_ability,
            "missing_circuits_by_ability": missing_counts,
            "no_route_at_any_ability": missing_all
        }))
    quit()
