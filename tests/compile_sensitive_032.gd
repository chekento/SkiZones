extends SceneTree
## Fail clearly when a newly added panel dependency cannot be instantiated.
## Some scene tests transitively preload the panels only on the first frame.
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func run()->void:
	for path in ["res://src/core/start_tiers.gd","res://src/core/recruitment.gd","res://src/core/operations.gd","res://src/ui/operating_pages.gd","res://src/ui/management.gd","res://src/ui/career_slots.gd","res://src/ui/scenarios.gd","res://src/main.gd"]:
		var script: Resource=ResourceLoader.load(path)
		if script is GDScript and (script as GDScript).can_instantiate():
			passed+=1
			print("PASS compiled ",path)
		else:
			failed+=1
			push_error("FAIL compile "+path)
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
