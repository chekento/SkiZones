extends Control
const L=preload("res://src/core/i18n.gd")
## Non-interactive presentation, only when the player selected unobstructed
## map focus. This never changes camera geometry or captures touch input.
var hud: CanvasLayer
var _previous_state: String=""
var _tick:=0.0

func setup(parent_hud: CanvasLayer) -> void:
	hud=parent_hud
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode=Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if hud==null or hud.game==null:return
	_tick+=maxf(0,delta)
	if _tick<0.15:return
	_tick=0.0
	var status: String=str(hud.game.view.visual_style)+":"+str(hud.map_focus)+":"+str(int(Time.get_ticks_msec()/1000.0)%29)
	if status!=_previous_state:
		_previous_state=status
		queue_redraw()

func presentation_rect() -> Rect2:
	# Keep the style treatment inside the visible map, below real HUD panels.
	var top_value: float = 9.0 if hud.cinema_mode else hud.camera_bar.get_rect().end.y+10.0
	if not hud.cinema_mode:
		for panel in [hud.mission_panel,hud.slope_legend]:
			if panel.visible:top_value=maxf(top_value,panel.get_rect().end.y+10.0)
	var bottom_value := size.y-9.0
	if hud.plan_panel.visible:bottom_value=minf(bottom_value,hud.plan_panel.position.y-10.0)
	return Rect2(9.0,top_value,maxf(0.0,size.x-18.0),maxf(0.0,bottom_value-top_value))

func _draw() -> void:
	if hud==null or hud.game==null or not hud.map_focus or hud.menu.visible:return
	var style_id: String=str(hud.game.view.visual_style)
	var area := presentation_rect()
	var origin := area.position
	var width_value:float=area.size.x
	var height_value:float=area.size.y
	if width_value<400 or height_value<300:return
	match style_id:
		"comic":
			# A fleeting split-panel frame on a sightseeing/camera view only.
			var phase:float=fposmod(float(Time.get_ticks_msec())/1000.0,29.0)
			if phase<2.6:
				draw_rect(area,Color("162c4a",0.65),false,5)
				draw_line(origin+Vector2(width_value*0.58,0),origin+Vector2(width_value*0.49,height_value),Color("ffffff",0.55),10,true)
				draw_line(origin+Vector2(width_value*0.58,0),origin+Vector2(width_value*0.49,height_value),Color("1a2b44",0.8),3,true)
				draw_rect(Rect2(origin+Vector2(17,19),Vector2(minf(220,width_value*0.32),40)),Color("ffe15e",0.92))
				draw_string(ThemeDB.fallback_font,origin+Vector2(31,47),"SKI! WOW!",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("182743"))
		"cinematic":
			draw_rect(Rect2(origin,Vector2(width_value,roundf(height_value*0.045))),Color("101821",0.65))
			draw_rect(Rect2(origin+Vector2(0,height_value-roundf(height_value*0.045)),Vector2(width_value,roundf(height_value*0.045))),Color("101821",0.65))
		"piste_map":
			var ink:=Color("556953",0.82)
			draw_rect(area,ink,false,3)
			draw_rect(Rect2(origin+Vector2(12,11),Vector2(minf(280,width_value*0.43),46)),Color("f4f0dd",0.88))
			draw_string(ThemeDB.fallback_font,origin+Vector2(26,41),L.text("SKIZONES  |  PISTENATLAS"),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("344e40"))

