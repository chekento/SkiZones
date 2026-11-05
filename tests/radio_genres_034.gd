extends SceneTree
## 0.34 Alpine Radio – actual, licensed OGG files and honest genre schedules.
const Design = preload("res://src/core/audio_design.gd")
const Radio = preload("res://src/world/resort_audio.gd")
const Preferences = preload("res://src/core/preferences.gd")

var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL "+title)

func run() -> void:
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/cc0/library.json"))
	var durations: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/cc0/durations.json"))
	check(library is Dictionary and durations is Dictionary,"Bundled offline library and measured duration index parse")
	if not (library is Dictionary and durations is Dictionary): quit(1); return
	var channels: Dictionary = library.get("stations",{})
	var seconds: Dictionary = durations.get("seconds",{})
	check(Design.GENRES.size()==16 and Design.CONTEXT_STATIONS==["hotel_lobby"],"Exactly 15 selectable winter channels plus off, and one hotel-only service")
	check(channels.size()==16 and not channels.has("ska_album") and not channels.has("erg0sphere"),"No SoundCloud station is indexed or exposed")
	check(Design.EXTERNAL_STATIONS.is_empty(),"The app no longer depends on remote streaming or external accounts")
	check(Design.genre_valid("ska_album")=="apres" and Design.genre_valid("erg0sphere")=="space","Old creator-playlist preferences migrate to appropriate live stations")
	for old_station in ["ska_album","erg0sphere"]:
		var old_prefs := Preferences.new()
		old_prefs.path="user://radio-034-"+old_station+".cfg"
		var config := ConfigFile.new()
		config.set_value("audio","music_genre",old_station)
		check(config.save(old_prefs.path)==OK,"Old station preference fixture can be written")
		old_prefs.load_from()
		check(old_prefs.music_genre==Design.genre_valid(old_station),"Legacy saved radio choice restores a genuinely playable channel")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old_prefs.path))
	var seen: Dictionary = {}
	var radio := Radio.new()
	root.add_child(radio)
	radio._load_cc0_library()
	for station in channels:
		check(station in Design.GENRES or station in Design.CONTEXT_STATIONS,"Only declared local genre is available: "+station)
		check(Design.GENRE_NAMES.has(station) and (station=="hotel_lobby" or Design.GENRE_MOODS.has(station)),"Station has its own accurate branding and programme identity")
		var local: Dictionary = {}
		for record in channels[station]:
			var id: String = str(record.get("id",""))
			var path: String = str(record.get("file",""))
			check(not local.has(id),"Station "+station+" does not repeat one song")
			local[id]=true
			check(str(record.get("license",""))=="CC0-1.0" and str(record.get("source_url","")).begins_with("https://"),"Documented source and individual CC0 rights: "+id)
			check(ResourceLoader.exists(path) and float(seconds.get(path,0))>0.0,"Real indexed Ogg recording with measured duration: "+id)
			var mirror: Dictionary=record.get("mirror",{})
			check(str(mirror.get("git_blob_sha1","")).length()==40 and int(mirror.get("bytes",0))>100000,"Original mirror pin retained: "+id)
			seen[path]=true
		check(local.size()>=10,"Station "+station+" has at least ten real songs")
		check(radio.station_track_count(station)==local.size(),"Station "+station+" is playable through the actual radio")
	check(seen.size()==87 and seconds.size()==87,"Exactly 87 real offline CC0 OGG files, including the eleven newly sourced recordings")
	for id in ["r34-etirwer","r34-apple-cider","r34-funked-up","r34-dj-synth-funk","r34-liquid-flame","r34-lost-snow-wave","r34-coffee-house-bump","r34-jazz-spring","r34-moon-unit","r34-going-home","r34-one-night-france"]:
		var path: String="res://assets/music/cc0/"+id+".ogg"
		var stream: AudioStream=load(path) as AudioStream
		check(stream is AudioStreamOggVorbis and absf(stream.get_length()-float(seconds.get(path,-10.0)))<0.001,"New real recording has exact playable airtime: "+id)
	for station in ["apres","techno","freeride","hiphop","lodge_lofi"]:
		check(not radio.programme_position(station).is_empty(),"Music runs on a live synchronized channel: "+station)
	var jukebox_code: String=FileAccess.get_file_as_string("res://src/ui/jukebox.gd")
	var design_code: String=FileAccess.get_file_as_string("res://src/core/audio_design.gd")
	check(not jukebox_code.contains("https://soundcloud.com/") and not design_code.contains("https://soundcloud.com/"),"No SoundCloud embed or link is reachable from radio UI")
	check(not FileAccess.file_exists("res://assets/licenses/SoundCloud.txt") and not FileAccess.file_exists("res://docs/embed/skaradise_lost.html"),"External playlist embeds and stale privacy boilerplate are gone from the application")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
