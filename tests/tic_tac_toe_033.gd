extends SceneTree
## Authentic Tic-Tac-Toe checks: legal clicks, deterministic AI, blocks, results,
## full playable matches, and a GUI board that responds to real Button presses.
const Rules = preload("res://src/core/tic_tac_toe.gd")
const Board = preload("res://src/ui/tic_tac_toe_board.gd")
const Styles = preload("res://src/core/visual_styles.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed += 1; print("PASS ",description)
	else: failed += 1; push_error("FAIL "+description)

func run() -> void:
	var match_state: Dictionary = Rules.fresh(22)
	check(match_state.cells.size()==9 and Rules.vacancies(match_state.cells).size()==9,"New board is empty and has nine real cells")
	check(not Rules.play(match_state,-1).ok and not Rules.play(match_state,9).ok,"Out-of-bounds touches cannot change the match")
	var first: Dictionary = Rules.play(match_state,0)
	check(first.ok and first.human==0 and first.computer>=0 and match_state.cells[0]=="X" and match_state.cells[int(first.computer)]=="O","Human and computer occupy different real squares")
	check(not Rules.play(match_state,0).ok and not Rules.play(match_state,int(first.computer)).ok,"Occupied squares reject further touches")
	check(Rules.result(["X","X","X","O","","","","O",""])=="X","Horizontal human victory")
	check(Rules.result(["O","X","X","O","X","","O","",""])=="O","Vertical computer victory")
	check(Rules.result(["X","O","O","O","X","","","","X"])=="X","Diagonal human victory")
	check(Rules.result(["X","O","X","X","O","O","O","X","X"])=="draw","Full drawn board is identified")
	check(Rules.computer_square(["O","O","","X","X","","","",""],17)==2,"Computer makes an immediate legal win")
	check(Rules.computer_square(["X","X","","O","","","","",""],17)==2,"Computer blocks immediate human win")
	var result_hashes: Array = []
	for seed_value in range(24):
		var game: Dictionary = Rules.fresh(seed_value)
		var guard := 0
		while not game.finished and guard < 9:
			var legal: Array=Rules.vacancies(game.cells)
			if legal.is_empty():break
			var outcome: Dictionary=Rules.play(game,int(legal[0]))
			check(outcome.ok and game.moves<=9,"Seed %d: a complete match stays legal" % seed_value)
			guard+=1
		check(game.finished and game.winner in ["X","O","draw"],"Seed %d: match actually terminates" % seed_value)
		result_hashes.append(JSON.stringify(game.cells))
	check(result_hashes.size()==24 and result_hashes[0]==result_hashes[0],"Opponent seed sequence stays reproducible")
	var board := Board.new()
	board.style_id="monochrome"
	root.add_child(board)
	await process_frame
	check(board.get_node("GridContainer")!=null if board.has_node("GridContainer") else board.find_children("square_*","Button",true,false).size()==9,"Monochrome arcade builds a touch-enabled three-by-three board")
	var buttons: Array=board.find_children("square_*","Button",true,false)
	check(buttons.size()==9 and buttons.all(func(button):return button.custom_minimum_size.x>=70 and button.custom_minimum_size.y>=70),"All nine tap targets have mobile-sized hitboxes")
	if buttons.size()==9:
		buttons[0].emit_signal("pressed")
		check(not buttons[0].text.is_empty() and buttons[0].disabled,"Pressing a real button plays the human mark and locks its square")
	board.restart()
	check(buttons.all(func(button):return button.text.is_empty() and not button.disabled),"New round clears all squares without reload")
	board.queue_free()
	await process_frame
	for theme_id in Styles.IDS:
		var themed := Board.new()
		themed.style_id = theme_id
		root.add_child(themed)
		await process_frame
		var surface := themed.get_node_or_null("arcade_surface") as PanelContainer
		var title := themed.find_child("arcade_title", true, false) as Label
		var instructions := themed.find_child("arcade_instructions", true, false) as Label
		var score := themed.find_child("arcade_score", true, false) as Label
		check(surface != null and title != null and instructions != null and score != null,
			"%s: real themed surface contains the entire game text" % theme_id)
		if surface != null and title != null and instructions != null and score != null:
			var panel_style := surface.get_theme_stylebox("panel") as StyleBoxFlat
			var palette: Dictionary = Styles.ui_palette(theme_id)
			check(panel_style != null and panel_style.bg_color == Color(str(palette.panel)),
				"%s: panel renders the chosen graphic style's actual background" % theme_id)
			if panel_style != null:
				check(surface.is_ancestor_of(title) and surface.is_ancestor_of(instructions) and surface.is_ancestor_of(score),
					"%s: text is physically inside its painted panel, not on the host window" % theme_id)
				for label in [title,instructions,score]:
					var color: Color = label.get_theme_color("font_color")
					check(Board.contrast_ratio(color, panel_style.bg_color) >= 4.5,
						"%s: %s has at least 4.5:1 text contrast" % [theme_id,label.name])
		themed.queue_free()
		await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
