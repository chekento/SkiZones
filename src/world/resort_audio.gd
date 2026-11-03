extends Node
## Built-in original procedural placeholder sounds. No third-party tracks,
## no recording of NPC voices, no hidden streaming and no external services.
const Design=preload("res://src/core/audio_design.gd")
const SAMPLE_RATE := 12000
const LOOP_SECONDS := 8
const LAYERS := ["wind","crowd","machinery"]
var scene: Node3D
var preferences: RefCounted
var players: Dictionary={}
var _cache: Dictionary={}
var _poll := 0.0
var active_zone := "wilderness"
var current_genre := "off"
var preview_genre := false
var _level_targets := {"wind":0.0,"crowd":0.0,"machinery":0.0,"music":0.0}
var _level_current := {"wind":0.0,"crowd":0.0,"machinery":0.0,"music":0.0}
var _retiring_music: AudioStreamPlayer
var _track_crossfade := 1.0
const CROSSFADE_SECONDS := 1.3

func setup(resort_view: Node3D, prefs: RefCounted) -> void:
	scene=resort_view
	preferences=prefs
	for layer in LAYERS+["music"]:
		var player:=AudioStreamPlayer.new()
		player.name="SkiZones "+layer
		player.bus="Master"
		player.volume_db=-60.0
		add_child(player)
		players[layer]=player
	var alternate:=AudioStreamPlayer.new()
	alternate.name="SkiZones music alternate"
	alternate.bus="Master"
	alternate.volume_db=-60.0
	add_child(alternate)
	players["music_alt"]=alternate
	for kind in LAYERS:
		players[kind].stream=_create(kind)
		players[kind].play()
	set_genre(str(preferences.music_genre))
	sync()

func _waveform(t: float, mode: String, frame: int) -> float:
	var beat:=fposmod(t,0.5)
	var step:=int(t*2.0)%16
	var pulse:=exp(-beat*12.0)
	var p:=t*TAU
	var notes: Array=[57,60,64,67,62,64,69,67,57,62,65,69,60,64,67,72]
	var n:int=notes[step]
	var hz:float=440.0*pow(2.0,(n-69)/12.0)
	var s:=sin(p*hz)
	var bass:=sin(p*hz*0.5)
	var tri:=2.0*absf(fposmod(hz*t,1.0)-0.5)-0.5
	match mode:
		"alpine":
			return s*0.22+sin(p*hz*2.0)*0.075+bass*0.13+sin(p*4.5)*0.02
		"techno":
			return bass*0.24+tri*0.08+pulse*sin(p*(75.0-40.0*beat))*0.22
		"hiphop":
			return bass*0.30+s*0.07+sin(p*82.0)*pulse*0.21
		"punk":
			var distorted:float=clampf(s*2.8,-0.6,0.6)
			return distorted*0.33+pulse*sin(p*90.0)*0.17
		"classical":
			return s*0.20+sin(p*hz*1.5)*0.10+sin(p*hz*0.5)*0.08
		"meditative":
			return sin(p*hz*0.5)*0.17+sin(p*hz)*0.12+sin(p*hz*1.003)*0.05
		"wind":
			var noise:=sin(float(frame)*19.813)*sin(float(frame)*4.5317)
			return noise*(0.11+0.065*sin(t*TAU*0.13))
		"crowd":
			var noise:=sin(float(frame)*8.917)*sin(float(frame)*2.737)
			var mumble:=sin(p*132.0+sin(p*3.1)*5.0)*0.11
			return (noise*0.07+mumble)*(0.45+0.55*absf(sin(p*0.63)))
		"machinery":
			return sin(p*69.0)*0.14+sin(p*138.0)*0.055+sin(p*25.0)*0.043
	return 0.0

func _create(mode: String) -> AudioStreamWAV:
	if _cache.has(mode):return _cache[mode]
	var wav:=AudioStreamWAV.new()
	var sample_count:int=SAMPLE_RATE*LOOP_SECONDS
	var bytes:=PackedByteArray()
	bytes.resize(sample_count*2)
	for i in range(sample_count):
		var t:float=float(i)/SAMPLE_RATE
		var value:float=_waveform(t,mode,i)
		# Smooth join without a click. The source is original and generated locally.
		var end_fade:float=clampf(minf(float(i),float(sample_count-1-i)) / (SAMPLE_RATE*0.09),0,1)
		var pcm:int=clampi(roundi(value*end_fade*28000.0),-32768,32767)
		bytes.encode_s16(i*2,pcm)
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=SAMPLE_RATE
	wav.stereo=false
	wav.data=bytes
	wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin=0
	wav.loop_end=sample_count
	_cache[mode]=wav
	return wav

func set_genre(id: String, preview: bool = false) -> void:
	var wanted:String=Design.genre_valid(id)
	preview_genre=preview
	if current_genre==wanted and players.has("music") and (wanted=="off" or players.music.playing):
		return
	var primary:AudioStreamPlayer=players.get("music")
	var standby:AudioStreamPlayer=players.get("music_alt")
	if primary==null:return
	current_genre=wanted
	_track_crossfade=0.0
	if wanted=="off":
		# Off is immediate, not a long fade: audio opt-out should feel certain.
		primary.stop()
		if standby!=null:standby.stop()
		_retiring_music=null
		sync()
		return
	if standby!=null:
		standby.stop()
		if primary.playing:
			_retiring_music=primary
			players["music"]=standby
			players["music_alt"]=primary
		else:
			_retiring_music=null
	var incoming:AudioStreamPlayer=players.get("music")
	incoming.stream=_create(wanted)
	incoming.volume_db=-60.0
	incoming.play()
	sync()

func sync() -> void:
	if preferences==null:return
	var saved_station:String=Design.genre_valid(str(preferences.music_genre))
	if not preview_genre and saved_station!=current_genre:
		set_genre(saved_station)
	var volume_music:float=clampf(float(preferences.music_volume),0.0,1.0)
	var volume_ambient:float=clampf(float(preferences.ambient_volume),0.0,1.0)
	_level_targets=Design.zone_levels(active_zone,volume_music,volume_ambient,current_genre!="off")

func _process(delta: float) -> void:
	if scene==null or preferences==null or scene.model==null:return
	var elapsed:float=clampf(delta,0.0,0.25)
	_poll+=maxf(0.0,delta)
	if _poll>=0.35:
		_poll=0.0
		var area:Dictionary=Design.nearby(scene.model,scene.focus)
		active_zone=str(area.kind)
		sync()
	_track_crossfade=clampf(_track_crossfade+elapsed/CROSSFADE_SECONDS,0,1)
	for layer in LAYERS+["music"]:
		var current:float=float(_level_current.get(layer,0))
		var target:float=float(_level_targets.get(layer,0))
		var next:float=Design.mix_step(current,target,elapsed,1.35)
		_level_current[layer]=next
		var player:AudioStreamPlayer=players.get(layer)
		if player==null:continue
		var audible:float=next*(_track_crossfade if layer=="music" else 1.0)
		player.volume_db=linear_to_db(maxf(0.001,audible))
	if is_instance_valid(_retiring_music):
		if _track_crossfade>=1.0:
			_retiring_music.stop()
			_retiring_music=null
		else:
			_retiring_music.volume_db=linear_to_db(maxf(0.001,float(_level_current.music)*(1.0-_track_crossfade)))
