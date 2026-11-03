extends Node
## Copyright-safe, original, slowly evolving procedural alpine sound sketches.
## This first pass uses synthesized soft-key notes/pads, not released recordings.
## One low-rate stream avoids multiple decoders on Android.
const RATE := 22050.0
const STATIONS := ["piano","panorama","village","nature"]
const CHORDS := [[0,3,7,12],[5,9,12,16],[7,10,14,17],[3,7,10,15]]
var generator := AudioStreamGenerator.new()
var player := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var station := "piano"
var previous_station := "piano"
var fade := 1.0
var sound_enabled := true
var volume := 0.60
var wilderness := false
var wilderness_mix := 0.0
var time := 0.0
var delay := PackedFloat32Array()
var delay_index := 0
var _surrounding_timer := 0.0

func _ready() -> void:
	generator.mix_rate=RATE
	generator.buffer_length=0.42
	delay.resize(5909)
	add_child(player)
	player.stream=generator
	player.volume_db=-6.0
	player.play()
	playback=player.get_stream_playback() as AudioStreamGeneratorPlayback

func configure(preferences: RefCounted) -> void:
	var chosen: String=str(preferences.radio_station)
	if chosen not in STATIONS: chosen="piano"
	if station!=chosen:
		previous_station=station
		station=chosen
		fade=0.0
	sound_enabled=bool(preferences.sound_enabled)
	volume=clampf(float(preferences.sound_volume)/100.0,0.0,1.0)

func follow_view(view: Node3D) -> void:
	if view.model==null or view.terrain==null: return
	_surrounding_timer+=0.5
	var distance:=INF
	for building in view.model.buildings:
		if not building.enabled: continue
		distance=minf(distance,view.focus.distance_to(preload("res://src/core/terrain.gd").unpack(building.point)))
	wilderness=distance>210.0

static func _frequency(semitone: int) -> float:
	return 220.0*pow(2.0,float(semitone)/12.0)

static func _keys(t: float) -> float:
	# Original restrained 4-chord progression, with a long non-identical
	# arpeggio across measures and gentle changing overtones.
	var bpm:=68.0
	var beat_seconds:=60.0/bpm
	var beat:=int(floor(t/beat_seconds))
	var chord: Array=CHORDS[int(beat/12)%CHORDS.size()]
	var note: int=int(chord[[0,2,1,3,1,2,0,3][beat%8]])
	var freq:=_frequency(note)
	var local:=fmod(t,beat_seconds)
	var envelope:=exp(-5.0*local/beat_seconds)*(1.0-exp(-70.0*local))
	var key_sound:=sin(TAU*freq*t)*0.52+sin(TAU*freq*2.0*t)*0.23+sin(TAU*freq*3.0*t)*0.07
	var pad_root:=_frequency(int(chord[0])-12)
	var pad:=sin(TAU*pad_root*t)*0.15+sin(TAU*_frequency(int(chord[2])-12)*t)*0.08
	var slow:=0.83+0.17*sin(TAU*t/43.0)
	return (key_sound*envelope*0.18+pad*0.12)*slow

static func _panorama(t: float) -> float:
	var root: int=[-5,-2,0,3][int(t/21.0)%4]
	var f:=_frequency(root)
	return (sin(TAU*f*t)+sin(TAU*f*1.502*t)*0.33+sin(TAU*f*2.003*t)*0.16)*(0.048+0.01*sin(t*0.17))

static func _village(t: float) -> float:
	var note: int=[0,7,12,5,3,10,7,12][int(t*1.9)%8]
	var interval:=fmod(t,1.0/1.9)
	var env:=exp(-interval*7.0)
	return (sin(TAU*_frequency(note+12)*t)*0.13+sin(TAU*_frequency(note+24)*t)*0.04)*env+_panorama(t)*0.4

static func _nature(t: float) -> float:
	# Distant, deliberately abstract small bird chirps and breeze; no speech,
	# sampled animals or unlicensed recordings are asserted.
	var pulse:=fmod(t,9.7)
	var chirp:=0.0
	if pulse<0.22:
		chirp=sin(TAU*(1150.0*t+1450.0*pulse*pulse))*exp(-pulse*17.0)*0.023
	var breeze:=sin(0.25*t)*0.006+sin(0.63*t)*0.004
	return chirp+breeze

static func _station_value(id: String,t: float) -> float:
	match id:
		"piano": return _keys(t)
		"panorama": return _panorama(t)
		"village": return _village(t)
	return 0.0

func _process(delta: float) -> void:
	if playback==null: return
	fade=minf(1.0,fade+maxf(0.0,delta)/3.0)
	wilderness_mix=move_toward(wilderness_mix,1.0 if wilderness or station=="nature" else 0.0,maxf(0.0,delta)/4.0)
	var available: int=mini(playback.get_frames_available(),3072)
	if available<=0: return
	var buffer:=PackedVector2Array()
	buffer.resize(available)
	for i in range(available):
		time+=1.0/RATE
		var old_value:=_station_value(previous_station,time)
		var new_value:=_station_value(station,time)
		var musical:=lerpf(old_value,new_value,fade)*(1.0-wilderness_mix)
		var natural:=_nature(time)*wilderness_mix
		var dry: float=(musical+natural)*volume*(1.0 if sound_enabled else 0.0)
		# A restrained short room tail. No long unbounded buffers or FX buses.
		var echo: float=delay[delay_index]
		delay[delay_index]=dry+echo*0.23
		delay_index=(delay_index+1)%delay.size()
		var final_sample:=clampf(dry+echo*0.27,-0.75,0.75)
		buffer[i]=Vector2(final_sample,final_sample)
	playback.push_buffer(buffer)
