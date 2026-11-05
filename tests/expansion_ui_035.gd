extends SceneTree
const Reaction = preload("res://src/ui/reaction_game.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1;print("PASS ",description)
	else: failed+=1;push_error("FAIL "+description)
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	game.hud.hide_menu()
	game.set_tool("piste")
	var palette: Control=game.hud.palette
	check(palette.planning_page==0 and palette.route_tab.visible,"Piste builder begins on Route with a fixed reachable header")
	game.points=[[0,0]]
	game._update_plan()
	check(palette.planning_page==1 and palette.live_stats.text.contains("m"),"First route point automatically opens actual start-height statistics")
	game.points=[[0,0],[200,205]]
	game._update_plan()
	var before: String=palette.live_stats.text
	game.points=[[0,0],[100,100]]
	game._update_plan()
	check(palette.live_stats.text!=before,"Moving route points immediately updates distance and descent")
	palette.route_tab.pressed.emit()
	game._update_plan()
	check(palette.planning_page==0,"User can return to Route without an automatic refresh stealing the tab")
	game.clear_plan()
	check(palette.planning_page==0 and game.points.is_empty(),"Finishing or cancelling resets the next route to the construction page")
	var lodge: Dictionary=game.model.buildings.filter(func(b):return b.kind=="lodge")[0]
	game.model.campaign.rank=5
	game.hud.experience.open(int(lodge.id))
	var games: Array=game.hud.experience.find_children("*","",true,false).filter(func(node):return node is Reaction)
	check(games.size()==1,"Reaction game is genuinely reachable in an actual lodge interior")
	game.hud.experience.close()
	var board:=Reaction.new()
	board.style_id="monochrome"
	root.add_child(board)
	await settle()
	board.set_process(false)
	var snapshot: String=JSON.stringify(game.model.snapshot())
	board._button.pressed.emit()
	board._button.pressed.emit()
	check(board.samples.size()==1 and board.samples[0]==1500,"Tapping before GO is a real scored false start")
	for i in range(4):
		board._button.pressed.emit()
		board._process(3.0)
		board._process(0.18+float(i)*0.02)
		board._button.pressed.emit()
	check(board.phase=="done" and board.samples.size()==5 and board._score.text.contains("Median"),"Five real start/tap rounds produce a final median reaction score")
	board._button.pressed.emit()
	board.hide()
	board._process(0.5)
	check(board.phase=="next" and board.samples.is_empty(),"Leaving a tab cancels its active timed round without recording an invisible failure")
	board.show()
	check(JSON.stringify(game.model.snapshot())==snapshot,"Playing the reaction game does not alter money or the career")
	board.queue_free()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language)
		for dimensions in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=dimensions
			await settle()
			var money_before: float=game.model.money
			game.hud.management._credit_confirmation(game.hud.management.LoanOptions.offer("micro",2))
			await settle()
			var dialogs: Array=game.hud.management.find_children("*","ConfirmationDialog",true,false)
			check(dialogs.size()==1,"One readable credit confirmation at "+language+str(dimensions))
			if not dialogs.is_empty():
				var dialog: ConfirmationDialog=dialogs[0]
				check(dialog.size.x<=dimensions.x and dialog.size.y<=dimensions.y,"Credit conditions and buttons fit phone bounds at "+language+str(dimensions))
				dialog.canceled.emit()
				await settle()
			check(game.model.money==money_before and game.model.loan==0,"Cancelling a credit preview never changes cash or debt")

	game.queue_free()
	await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
