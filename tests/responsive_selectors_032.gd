extends SceneTree
## Screen-size regression for critical Android resort selectors.
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,name:String)->void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)
func run()->void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var initial_size: Vector2i=root.size
	for dims in [Vector2i(1440,900),Vector2i(960,540),Vector2i(560,360)]:
		root.size=dims
		for i in range(4):await process_frame
		game.hud.career_slots.open()
		await process_frame
		var full: Rect2=root.get_visible_rect()
		var selector: Control=game.hud.career_slots
		check(full.encloses(selector.get_global_rect()),"Career selector fits "+str(dims))
		check(selector.cards.columns==(1 if dims.x<1050 else 2),"Career cards adapt columns "+str(dims))
		check(full.encloses(selector.heading_label.get_global_rect()),"Career header stays visible "+str(dims))
		check(full.encloses(selector.close_button.get_global_rect()),"Career back action remains visible "+str(dims))
		game.hud.career_slots.hide()
		game.hud.scenarios.open()
		for i in range(3):await process_frame
		var scenarios: Control=game.hud.scenarios
		check(full.encloses(scenarios.get_global_rect()),"Scenario selector fits "+str(dims))
		check(scenarios.grid.columns==(1 if dims.x<1060 else 2),"Scenario cards adapt columns "+str(dims))
		check(full.encloses(scenarios.close_button.get_global_rect()),"Scenario back action remains visible "+str(dims))
		game.hud.scenarios.hide()
	root.size=initial_size
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
