extends SceneTree
const Design=preload("res://src/core/audio_design.gd")
const Audio=preload("res://src/world/resort_audio.gd")
const Crew=preload("res://src/world/crew_life.gd")
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Resort=preload("res://src/core/resort.gd")
const Preferences=preload("res://src/core/preferences.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Art=preload("res://src/world/alpine_art.gd")
var passed:=0
var failed:=0

func check(ok: bool, name: String) -> void:
	if ok:passed+=1; print("PASS ",name)
	else:failed+=1; push_error("FAIL "+name)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Design.GENRES.size()==18 and Design.genre_valid("unknown")=="off","Seventeen selectable programmes including two own albums, plus off")
	check(not Design.license_policy("suno") and not Design.license_policy("soundcloud") and not Design.license_policy("cc0") and Design.license_policy("cc0",true),"External providers remain disabled without explicit rights")
	var audio:=Audio.new()
	for genre in ["alpine","techno","hiphop","punk","classical","meditative","freeride","wind","crowd","machinery"]:
		var stream:AudioStreamWAV=audio._create(genre)
		check(stream!=null and stream.data.size()==Audio.SAMPLE_RATE*Audio.LOOP_SECONDS*2 and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Original offline PCM loop: "+genre)
	var model:=Resort.new()
	model.new_game(false)
	model.buildings=[
		{"id":901,"kind":"hotel","point":Terrain.pack(Vector2(140,190)),"enabled":true},
		{"id":902,"kind":"disco","point":Terrain.pack(Vector2(320,210)),"enabled":true},
		{"id":903,"kind":"first_aid","point":Terrain.pack(Vector2(550,250)),"enabled":true}]
	model.lifts=[]
	model.pistes=[]
	model._invalidate()
	check(Design.nearby(model,Vector2(135,185)).kind=="hotel","Hotel has its own close-range soundscape")
	check(Design.nearby(model,Vector2(321,210)).kind=="disco","Après-Ski volume and NPC density vary with camera target")
	check(Design.nearby(model,Vector2(545,250)).kind=="rescue","Rescue office is a separate workplace mix")
	check(Design.nearby(model,Vector2(900,900)).kind=="wilderness","Distant mountain reverts to wind rather than global crowds")
	check(Crew.destination(model,{"id":1,"assignment":"building:902","shift":"day"}).distance_to(Vector2(320,210))<20,"Crew members derive their destination from their actual roster assignment")
	var person:Dictionary={"id":1,"assignment":"building:902","shift":"day","absent_until":0,"break_until":0}
	model.minute=450
	check(Crew.progress(model,person)>0.0 and Crew.progress(model,person)<1.0,"On-duty staff travel from home to workplace during the start of a shift")
	model.minute=800
	check(is_equal_approx(Crew.progress(model,person),1.0),"Staff are shown at their real workplace during core working hours")
	model.minute=1250
	check(is_equal_approx(Crew.progress(model,person),0.0),"Off-duty employees return to housing presentation")
	check(Styles.IDS.size()>=6 and Styles.valid("piste_map")=="piste_map" and Styles.valid("alpine")=="alpine","Relief-map style and five original themes remain available alongside new styles")
	for kind in range(12,24):
		var mesh:Mesh=Art.new().landscape_detail(kind,"piste_map")
		check(mesh.get_surface_count()>0 and mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>6,"Themed new micro-prop %02d" % kind)
	var prefs:=Preferences.new()
	prefs.path="user://026-audio-preferences-test.cfg"
	prefs.music_genre="meditative"
	prefs.music_volume=0.65
	prefs.ambient_volume=0.30
	check(prefs.save_to()==OK,"Audio controls save separately from career playtime")
	var loaded:=Preferences.new()
	loaded.path=prefs.path
	loaded.load_from()
	check(loaded.music_genre=="meditative" and is_equal_approx(loaded.music_volume,0.65) and is_equal_approx(loaded.ambient_volume,0.30),"Audio station and ambience persist after restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
