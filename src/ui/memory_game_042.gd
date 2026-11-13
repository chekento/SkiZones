extends VBoxContainer
## Touch pairs with three sizes and explicit feedback, never cash rewards.
const Rules=preload("res://src/core/memory_pairs_042.gd")
const L=preload("res://src/core/i18n.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Contrast=preload("res://src/ui/tic_tac_toe_board.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
const SYMBOLS=["Berg","Ski","Lift","See","Baum","Sonne","Hütte","Stern"]
var style_id:="alpine"
var state:Dictionary={}
var cells:Array[Button]=[]
var difficulty:=OptionButton.new()
var status:=Label.new()
var grid:=GridContainer.new()
var rng:=RandomNumberGenerator.new()
var _remaining:=0.0
var _best:Dictionary={}
var _ink:=Color.BLACK
var _base:=Color.WHITE
var _accent:=Color("315d72")
var _light:=Color("c8dde1")

func _ready()->void:
	name="memory_game"
	rng.randomize();add_theme_constant_override("separation",12)
	var palette:Dictionary=Styles.ui_palette(style_id)
	_base=Color(str(palette.panel));_ink=Color(str(palette.ink));_accent=Color(str(palette.outline));_light=Color(str(palette.highlight))
	if Contrast.contrast_ratio(_ink,_base)<4.5:_ink=Color.BLACK if Contrast.contrast_ratio(Color.BLACK,_base)>Contrast.contrast_ratio(Color.WHITE,_base) else Color.WHITE
	var surface:=PanelContainer.new();surface.name="memory_surface"
	var background:=StyleBoxFlat.new();background.bg_color=_base;background.border_color=_accent;background.set_border_width_all(2);background.set_corner_radius_all(clampi(int(palette.corner),0,18));background.set_content_margin_all(12)
	surface.add_theme_stylebox_override("panel",background);add_child(surface)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",12);surface.add_child(body)
	var title:=Label.new();title.text=L.text("BERGPAARE · FIND DIE ZUSAMMENGEHÖRIGEN KARTEN");title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_font_size_override("font_size",19);title.add_theme_color_override("font_color",_ink);body.add_child(title)
	difficulty.name="memory_difficulty";difficulty.custom_minimum_size.y=48;difficulty.fit_to_longest_item=false
	for count in [4,6,8]:difficulty.add_item(L.text("%d Paare") % count)
	difficulty.select(1);difficulty.item_selected.connect(func(_index:int):reset());body.add_child(difficulty)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",17);status.add_theme_color_override("font_color",_ink);body.add_child(status)
	grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(grid)
	var restart:=Button.new();restart.name="memory_restart";restart.text=L.text("Neue Karten mischen");restart.custom_minimum_size.y=52;restart.pressed.connect(func():if DragScroll.click_allowed():reset());body.add_child(restart)
	reset()

func reset()->void:
	state=Rules.new_match([4,6,8][difficulty.selected],rng);_remaining=0
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	cells.clear()
	for index in range(state.deck.size()):
		var cell:=Button.new();cell.name="memory_card_%d" % index;cell.custom_minimum_size=Vector2(0,70);cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cell.focus_mode=Control.FOCUS_NONE;cell.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cell.add_theme_font_size_override("font_size",15)
		var chosen:int=index
		cell.pressed.connect(func():
			if DragScroll.click_allowed():flip(chosen))
		grid.add_child(cell);cells.append(cell)
	_redraw()

func flip(index:int)->void:
	if not Rules.flip(state,index):return
	if state.open.size()==2:_remaining=0.85
	if state.done:
		var previous:int=_best.get(int(state.pairs),1000000)
		_best[int(state.pairs)]=mini(previous,int(state.moves))
	_redraw()

func _redraw()->void:
	for i in range(cells.size()):
		var revealed:bool=i in state.open or i in state.matched
		cells[i].text=L.text(str(SYMBOLS[int(state.deck[i])])) if revealed else "?"
		cells[i].disabled=bool(state.done) or i in state.matched or i in state.open or state.open.size()==2
		var background:=StyleBoxFlat.new();background.bg_color=_light if i in state.matched else _base;background.border_color=_accent;background.set_border_width_all(2);background.set_corner_radius_all(9)
		var ink:Color=_ink
		if Contrast.contrast_ratio(ink,background.bg_color)<4.5:ink=Color.BLACK if Contrast.contrast_ratio(Color.BLACK,background.bg_color)>Contrast.contrast_ratio(Color.WHITE,background.bg_color) else Color.WHITE
		for style in ["normal","hover","pressed","disabled"]:cells[i].add_theme_stylebox_override(style,background)
		for setting in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:cells[i].add_theme_color_override(setting,ink)
	status.text=L.text("Gefunden %d / %d · Züge %d") % [state.matched.size()/2,int(state.pairs),int(state.moves)]
	if state.done:status.text=L.text("Alle Paare gefunden! %d Züge · dein Bestwert %d") % [int(state.moves),int(_best[int(state.pairs)])]
	elif state.open.size()==2:status.text+="\n"+L.text("Diese Karten passen nicht zusammen. Merke dir ihre Position.")
	else:status.text+="\n"+L.text("Tippe zwei Karten an. Kein Zeitlimit und kein Geldeinsatz.")

func _process(delta:float)->void:
	if not is_visible_in_tree() or _remaining<=0:return
	_remaining-=delta
	if _remaining<=0:Rules.cover(state);_redraw()
