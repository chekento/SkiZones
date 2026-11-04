extends Node
## Offline Alpine Radio: vetted third-party CC0 OGG songs, plus original fallback WAVs.
## Music is bundled in APK, never streamed or generated over a network.
const Design=preload("res://src/core/audio_design.gd")
const MUSIC_TRACKS := {
	"alpine": preload("res://assets/music/alpine.wav"),
	"techno": preload("res://assets/music/techno.wav"),
	"hiphop": preload("res://assets/music/hiphop.wav"),
	"punk": preload("res://assets/music/punk.wav"),
	"classical": preload("res://assets/music/classical.wav"),
	"meditative": preload("res://assets/music/meditative.wav")
}
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
var current_track_title := ""
var current_track_artist := ""
var _cc0_loaded := false
var _cc0_stations: Dictionary = {}
var _song_positions: Dictionary = {}
var active := true
var preview_settings: Dictionary = {}
var _targets: Dictionary = {}
var _levels: Dictionary = {}
var _crowd_gain := 0.0
var _machinery_gain := 1.0
var _retiring_music: AudioStreamPlayer
var _crossfade := 1.0
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
	alternate.name="music_alt"
	alternate.bus="Master"
	alternate.volume_db=-60.0
	add_child(alternate)
	players["music_alt"]=alternate
	players["music"].finished.connect(_on_music_finished.bind(players["music"]))
	players["music_alt"].finished.connect(_on_music_finished.bind(players["music_alt"]))
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

## Load a real arranged music bed; keep the old synthesizer as a fallback for QA.
func _music_stream(id: String) -> AudioStream:
	var track: AudioStream = MUSIC_TRACKS.get(id)
	if track == null:
		return _create(id)
	if track is AudioStreamWAV:
		var wav: AudioStreamWAV = track
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# Imported WAV can be QOA-compressed; data bytes are not PCM frames.
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return track

## Load only tracks whose verified OGG files are already bundled with the app.
func _load_cc0_library() -> void:
	if _cc0_loaded:
		return
	_cc0_loaded = true
	var data_file: FileAccess = FileAccess.open("res://assets/music/cc0/library.json", FileAccess.READ)
	if data_file == null:
		return
	var parsed: Variant = JSON.parse_string(data_file.get_as_text())
	if not (parsed is Dictionary):
		return
	var all_stations: Dictionary = parsed.get("stations", {})
	for genre in Design.GENRES:
		if genre == "off":
			continue
		var entries: Array = all_stations.get(genre, [])
		var present: Array = []
		for item in entries:
			if not (item is Dictionary):
				continue
			if str(item.get("license", "")) != "CC0-1.0":
				continue
			var audio_path: String = str(item.get("file", ""))
			if audio_path.begins_with("res://assets/music/cc0/") and ResourceLoader.exists(audio_path):
				present.append(item)
		if not present.is_empty():
			_cc0_stations[genre] = present

func station_track_count(id: String) -> int:
	_load_cc0_library()
	return (_cc0_stations.get(id, []) as Array).size()

func track_credits(id: String) -> Array:
	_load_cc0_library()
	return (_cc0_stations.get(id, []) as Array).duplicate(true)

func now_playing() -> Dictionary:
	return {"genre": current_genre, "title": current_track_title, "artist": current_track_artist}

func _radio_stream(id: String, advance: bool = false) -> AudioStream:
	_load_cc0_library()
	var entries: Array = _cc0_stations.get(id, [])
	if entries.is_empty():
		current_track_title = id
		current_track_artist = ""
		return _music_stream(id)
	var index: int = int(_song_positions.get(id, 0))
	if advance:
		index = (index + 1) % entries.size()
	_song_positions[id] = index
	var record: Dictionary = entries[index]
	var music: AudioStream = load(str(record.get("file", ""))) as AudioStream
	if music == null:
		return _music_stream(id)
	# The player advances to the next real song; a short two-player crossfade
	# begins before end of song, rather than hard-looping a single track.
	if music is AudioStreamOggVorbis:
		(music as AudioStreamOggVorbis).loop = false
	current_track_title = str(record.get("title", id))
	current_track_artist = str(record.get("artist", ""))
	return music

func next_track() -> void:
	if current_genre != "off" and _crossfade >= 1.0:
		set_genre(current_genre, true)

func _on_music_finished(finished_player: AudioStreamPlayer) -> void:
	if active and current_genre != "off" and players.get("music") == finished_player:
		set_genre(current_genre, true)

func _maybe_advance_song() -> void:
	if not active or current_genre == "off" or _crossfade < 1.0:
		return
	var music_player: AudioStreamPlayer = players.get("music")
	if music_player == null or not music_player.playing or music_player.stream_paused:
		return
	if not (music_player.stream is AudioStreamOggVorbis):
		return
	var remaining: float = music_player.stream.get_length() - music_player.get_playback_position()
	if remaining > 0.0 and remaining <= CROSSFADE_SECONDS + 0.25:
		set_genre(current_genre, true)

func set_genre(id: String, next_song: bool = false) -> void:
	var wanted:String=Design.genre_valid(id)
	if current_genre==wanted and not next_song and (wanted=="off" or (players.has("music") and players.music.playing)):return
	var primary:AudioStreamPlayer=players.get("music")
	if primary==null:return
	current_genre=wanted
	if wanted=="off":
		current_track_title = ""
		current_track_artist = ""
		# Explicit opt-out must silence both streams without a fade.
		primary.stop()
		var standby:AudioStreamPlayer=players.get("music_alt")
		if standby!=null:standby.stop()
		_retiring_music=null
		_crossfade=1.0
		_levels["music"]=0.0
		return
	var alternate:AudioStreamPlayer=players.get("music_alt")
	if alternate!=null and primary.playing:
		alternate.stop()
		_retiring_music=primary
		players["music"]=alternate
		players["music_alt"]=primary
		primary=alternate
	else:
		if alternate!=null:alternate.stop()
		_retiring_music=null
	_crossfade=0.0
	primary.stream=_radio_stream(wanted, next_song)
	primary.volume_db=-60.0
	primary.play()
	primary.stream_paused=not active

func settings() -> Dictionary:
	var result := {"genre":"off","music":0.35,"ambient":0.45,"master":1.0,"enabled":true}
	if preferences!=null:
		result={"genre":preferences.music_genre,"music":preferences.music_volume,"ambient":preferences.ambient_volume,"master":preferences.master_volume,"enabled":preferences.sound_enabled}
	result.merge(preview_settings,true)
	return result

func set_preview(changes: Dictionary) -> void:
	preview_settings=changes.duplicate()
	sync()

func clear_preview() -> void:
	preview_settings.clear()
	sync()

func set_active(value: bool) -> void:
	if active==value: return
	active=value
	if not active:
		for layer in players:
			players[layer].stream_paused=true
			_levels[layer]=0.0
	else: sync()

func sync() -> void:
	if preferences==null:return
	var chosen := settings()
	var station: String=Design.genre_valid(str(chosen.genre))
	if station!=current_genre:set_genre(station)
	var master: float=clampf(float(chosen.master),0,1) if bool(chosen.enabled) and active else 0.0
	var ambient: float=clampf(float(chosen.ambient),0,1)*master
	var music: float=clampf(float(chosen.music),0,1)*master
	var profile: Dictionary=Design.SOUND_MIX.get(active_zone,Design.SOUND_MIX.wilderness)
	for layer in LAYERS:
		var target: float=ambient*float(profile.get(layer,0.0))
		if layer=="crowd":target*=_crowd_gain
		if layer=="machinery":target*=_machinery_gain
		_targets[layer]=target
	_targets.music=music*(0.22+float(profile.get("music",0))*0.72) if station!="off" else 0.0
	_mix(0.0)

func _mix(delta: float) -> void:
	_crossfade=clampf(_crossfade+maxf(0.0,delta)/CROSSFADE_SECONDS,0.0,1.0)
	for layer in LAYERS+["music"]:
		var target:float=float(_targets.get(layer,0.0)) if active else 0.0
		var level:float=Design.mix_step(float(_levels.get(layer,0.0)),target,delta)
		_levels[layer]=level
		var player:AudioStreamPlayer=players.get(layer)
		if player==null:continue
		# Muting immediately pauses the stream, even if the gain was fading.
		player.stream_paused=target<=0.00001
		var audible:float=level*(_crossfade if layer=="music" else 1.0)
		player.volume_db=linear_to_db(maxf(0.0001,audible))
	if is_instance_valid(_retiring_music):
		var target_music:float=float(_targets.get("music",0.0)) if active else 0.0
		if _crossfade>=1.0 or target_music<=0.00001:
			_retiring_music.stop()
			_retiring_music=null
		else:
			_retiring_music.stream_paused=false
			_retiring_music.volume_db=linear_to_db(maxf(0.0001,float(_levels.get("music",0.0))*(1.0-_crossfade)))

func population(focus: Vector2) -> int:
	if scene==null or scene.model==null:return 0
	var count := 0
	for guest in scene.model.guests:
		if guest.phase=="leaving" or (guest.phase=="waiting" and guest.get("waiting_reason","")=="hotel"):continue
		var at: Vector3=scene._guest_positions.get(guest.id,Vector3.INF)
		if int(guest.leg)<guest.route.legs.size() and guest.route.legs[int(guest.leg)].kind=="visit":
			var building: Dictionary=scene.model.asset(int(guest.route.legs[int(guest.leg)].id))
			if building.has("point"):
				var point := preload("res://src/core/terrain.gd").unpack(building.point)
				at=Vector3(point.x,0,point.y)
		if at.is_finite() and Vector2(at.x,at.z).distance_to(focus)<90:
			count+=int(guest.get("group_size",1))
	return count

func _process(delta: float) -> void:
	if scene==null or preferences==null or scene.model==null:return
	_mix(delta)
	_maybe_advance_song()
	if not active:return
	_poll+=maxf(0.0,delta)
	if _poll<0.35:return
	_poll=0.0
	var area: Dictionary=Design.nearby(scene.model,scene.focus)
	active_zone=str(area.kind)
	_crowd_gain=clampf(log(1.0+population(scene.focus))/log(16.0),0,1)
	_machinery_gain=1.0
	if active_zone=="lift":
		var lift: Dictionary=scene.model.asset(int(area.target_id))
		_machinery_gain=1.0 if not lift.is_empty() and scene.model.lift_running(lift) else 0.0
	sync()
