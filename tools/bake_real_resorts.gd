extends SceneTree
## Precompute immutable source geometry; runtime guests and snow remain dynamic.
const Resort = preload("res://src/core/resort.gd")
const Geo = preload("res://src/core/real_resorts.gd")
func _init() -> void:
	for id in Geo.IDS:
		var model := Resort.new()
		model.new_game(true, 20261027, id)
		var result := {"revision": 1, "source_sha256": Geo.data(id).source_sha256, "next_id": model.next_id, "lifts": model.lifts, "pistes": model.pistes, "buildings": model.buildings}
		var file := FileAccess.open("res://assets/geodata/%s-seed.json" % id, FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
		print("BAKED ", id, " ", model.lifts.size(), " lifts / ", model.pistes.size(), " piste sections")
	quit()
