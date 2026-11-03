extends Control
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

func _draw() -> void:
	if hud==null or hud.game==null or not hud.map_focus:return
	var style_id: String=str(hud.game.view.visual_style)
	var width_value:float=size.x
	var height_value:float=size.y
	if width_value<400 or height_value<300:return
	match style_id:
		"comic":
			# A fleeting split-panel frame on a sightseeing/camera view only.
			var phase:float=fposmod(float(Time.get_ticks_msec())/1000.0,29.0)
			if phase<2.6:
				draw_rect(Rect2(7,7,width_value-14,height_value-14),Color("162c4a",0.65),false,5)
				draw_line(Vector2(width_value*0.58,7),Vector2(width_value*0.49,height_value-7),Color("ffffff",0.55),10,true)
				draw_line(Vector2(width_value*0.58,7),Vector2(width_value*0.49,height_value-7),Color("1a2b44",0.8),3,true)
				draw_rect(Rect2(26,28,minf(220,width_value*0.32),40),Color("ffe15e",0.92))
				draw_string(ThemeDB.fallback_font,Vector2(40,56),"SKI! WOW!",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("182743"))
		"cinematic":
			draw_rect(Rect2(0,0,width_value,roundf(height_value*0.045)),Color("101821",0.65))
			draw_rect(Rect2(0,height_value-roundf(height_value*0.045),width_value,roundf(height_value*0.045)),Color("101821",0.65))
		"piste_map":
			var ink:=Color("556953",0.82)
			draw_rect(Rect2(9,9,width_value-18,height_value-18),ink,false,3)
			draw_rect(Rect2(21,20,minf(280,width_value*0.43),46),Color("f4f0dd",0.88))
			draw_string(ThemeDB.fallback_font,Vector2(35,50),"SKIZONES  |  PISTENATLAS",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("344e40"))
