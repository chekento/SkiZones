extends Control
## Annual Advent doors and New Year countdown use the OS local clock.
## No GPS permission, network request or game-time speedup is involved.
const L = preload("res://src/core/i18n.gd")
const AnnualFestival = preload("res://src/core/annual_festival.gd")
const FloatingFrame = preload("res://src/ui/floating_window.gd")
const AdventHouse = preload("res://src/world/advent_house_043.gd")
var hud: CanvasLayer
var archive := AnnualFestival.new()
var window := FloatingFrame.new()
var scroll := ScrollContainer.new()
var contents := VBoxContainer.new()
var clock_label: Label
var _was_paused := false
var _clock_bucket := -1
var _calendar_state := ""

## Keep the calendar aligned with the actual four-column, six-row 3D facade.
## Narrow phone widths use smaller touch-safe cells instead of clipping doors.
static func door_button_width(viewport_width:float)->float:
	return 64.0 if viewport_width<450.0 else 90.0

func current_date() -> Dictionary:
	return AnnualFestival.device_now()

func _calendar_key(date: Dictionary) -> String:
	return "%d-%d-%d:%d" % [int(date.year),int(date.month),int(date.day),int(AnnualFestival.can_celebrate(date))]

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color=Color(0.02,0.06,0.09,0.65)
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(window)
	window.setup(hud,L.text("Weihnachtszauber im SkiZones-Dorf"))
	window.close_requested.connect(close)
	window.body.add_child(scroll)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(contents)
	contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation",12)
	hide()

func open() -> void:
	if not AnnualFestival.visible(current_date()): return
	if not visible:
		_was_paused=hud.game.paused
		hud.game.paused=true
	_rebuild()
	show()
	window._fit()

## Opening a physical 3D door uses the same atomically stored claim as
## the menu; tapping a locked or previously opened door grants nothing.
func open_world_door(number:int)->bool:
	if number<1 or number>24 or not AnnualFestival.visible(current_date()):return false
	var answer:Dictionary=archive.claim(number,current_date())
	if bool(answer.get("ok",false)):
		hud.game.view.festival_scene.reveal_advent_door(number)
	hud.toast(L.text(str(answer.get("message",""))))
	open()
	return bool(answer.get("ok",false))

func close() -> void:
	if visible: hud.game.paused=_was_paused
	hide()
	hud.refresh()

func _clear() -> void:
	for child in contents.get_children():
		contents.remove_child(child)
		child.queue_free()

func _rebuild(date: Dictionary = {}) -> void:
	_clear()
	var now: Dictionary=current_date() if date.is_empty() else date
	_calendar_state=_calendar_key(now)
	var state: Dictionary=archive.overview(now)
	var stage: String=str(state.season)
	hud._label(contents,L.text("24 Türchen · jedes Jahr ein neuer Winter"),27,hud.TEAL,true)
	hud._label(contents,L.text("01.–24. Dezember. Vergangene Türchen bleiben bis Silvester einlösbar. Tür 6 und 24 enthalten besondere Geschenke."),16,hud.MUTED,true)
	hud._label(contents,L.text("Wintertaler: %d · Jahr %d") % [int(state.coins),int(state.year)],22,hud.INK,true)
	if stage=="advent" or stage=="christmas" or stage=="new_year_eve":
		var grid:=GridContainer.new()
		grid.columns=AdventHouse.COLUMNS
		contents.add_child(grid)
		for door in range(1,25):
			var number: int=door
			var owned: bool=state.claimed.has(number)
			var can_open: bool=AnnualFestival.unlocked(now,number) and not owned
			var button: Button=hud._button(grid,("★ " if number in [6,24] else "❄ ") + str(number) + (" ✓" if owned else ""),func(): pass)
			button.custom_minimum_size=Vector2(door_button_width(get_viewport_rect().size.x),68)
			# Wooden door panels with a distinct open/locked state instead
			# of bare text: the same 4-by-6 facade as the 3D Advent house.
			var panel:=StyleBoxFlat.new()
			panel.bg_color=Color("7b9a92") if owned else Color("ba9059") if number in [6,24] else Color("89614d")
			panel.border_color=Color("eee2be")
			panel.set_border_width_all(3)
			panel.set_corner_radius_all(5)
			panel.content_margin_left=10
			panel.content_margin_right=10
			button.add_theme_stylebox_override("normal",panel)
			button.add_theme_stylebox_override("disabled",panel)
			button.add_theme_color_override("font_color",Color("fff8e7"))
			button.add_theme_color_override("font_disabled_color",Color("e4d9c4"))
			button.disabled=not can_open
			button.pressed.connect(func():
				var answer=archive.claim(number,current_date())
				hud.toast(L.text(str(answer.message)))
				if bool(answer.get("ok",false)):
					hud.game.view.festival_scene.reveal_advent_door(number)
				_rebuild()
			)
	if stage=="new_year_eve":
		hud._label(contents,L.text("Silvester – gemeinsam in das neue Jahr!"),24,hud.TEAL,true)
		clock_label=hud._label(contents,L.text("Jahreswechsel am 31. Dezember") if int(now.day)<31 else "",32,hud.INK,true)
		_clock_bucket=-1
	elif stage=="new_year":
		hud._label(contents,L.text("Frohes neues Jahr!"),30,hud.TEAL,true)
	if stage in ["new_year_eve","new_year"]:
		var celebrate: Button=hud._button(contents,L.text("Jahreswechsel feiern · einmal im Jahr"),func():
			var result=archive.celebrate_new_year(current_date())
			hud.toast(L.text(str(result.message)))
			_rebuild()
		,true)
		celebrate.disabled=not AnnualFestival.can_celebrate(now) or bool(state.new_year_done)
	hud._label(contents,L.text("Dekorationswerkstatt · freigeschaltete Gegenstände erscheinen während der Feiertage automatisch an geeigneten Plätzen."),18,hud.TEAL,true)
	for kind in AnnualFestival.DECORATIONS:
		var key: String=kind
		var spec: Dictionary=AnnualFestival.DECORATIONS[kind]
		var already: bool=state.owned.has(key)
		var button: Button=hud._button(contents,L.text(str(spec.name)) + (" ✓" if already else L.text(" · %d Wintertaler") % int(spec.price)),func():
			var result=archive.buy_decoration(key)
			hud.toast(L.text(str(result.message)))
			_rebuild()
		)
		button.disabled=already or int(state.coins)<int(spec.price)
	hud._label(contents,L.text("Diese Feiern folgen der lokalen Gerätezeit. Standortberechtigung wird nicht angefordert oder benötigt. Reisende sollten ihre Zeitzone im Gerät prüfen."),14,hud.MUTED,true)

func _process(_delta: float) -> void:
	if not visible: return
	var now: Dictionary=current_date()
	if AnnualFestival.season(now)=="":
		close()
		return
	# Refresh daily unlocks and both edges of the celebration window even if
	# the player keeps this paused overlay open across a calendar transition.
	if _calendar_key(now)!=_calendar_state:
		_rebuild(now)
	var current_second:=int(now.get("second",0))
	if current_second==_clock_bucket: return
	_clock_bucket=current_second
	if AnnualFestival.season(now)=="new_year_eve" and is_instance_valid(clock_label):
		var remaining:=AnnualFestival.countdown(now)
		if remaining>=0:
			clock_label.text=L.text("Neujahr in %02d:%02d:%02d") % [remaining/3600,(remaining%3600)/60,remaining%60]
