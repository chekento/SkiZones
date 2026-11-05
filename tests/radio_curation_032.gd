extends SceneTree
## Guard the provenance, per-station minimum and shuffle-bag uniqueness.
const Design=preload("res://src/core/audio_design.gd")
const Radio=preload("res://src/world/resort_audio.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,name:String)->void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)
func run()->void:
	var radio:=Radio.new()
	root.add_child(radio)
	radio._load_cc0_library()
	var all_ids: Dictionary={}
	for station in Design.GENRES + Design.CONTEXT_STATIONS:
		if station=="off":continue
		var credits: Array=radio.track_credits(station)
		check(credits.size()>=10,station+" provides at least ten offline tracks")
		var local_ids: Dictionary={}
		for song in credits:
			check(str(song.get("license",""))=="CC0-1.0" and str(song.get("source_url","")).begins_with("https://") and ResourceLoader.exists(str(song.get("file",""))),station+" individual license, source and audio file")
			var id: String=str(song.get("id",""))
			check(not local_ids.has(id),station+" no same-song duplicate in the playlist")
			local_ids[id]=true
			all_ids[id]=true
		var shuffled: Dictionary={}
		for i in range(credits.size()):
			var stream: AudioStream=radio._radio_stream(station,i>0)
			check(stream!=null and not shuffled.has(radio._last_record_id),station+" shuffle bag gives an unseen recording")
			shuffled[radio._last_record_id]=true
		check(shuffled.size()==credits.size(),station+" complete shuffle cycle plays each title exactly once")
	# Objective station identity: no more than half of each programme can
	# duplicate the most similar generic counterpart.
	for pair in [["apres","techno",5],["glacier","meditative",6],["hiphop","lodge_lofi",6]]:
		var left: Array=radio.track_credits(pair[0])
		var right_ids: Dictionary={}
		for item in radio.track_credits(pair[1]):right_ids[str(item.id)]=true
		var overlap: int=left.filter(func(item):return right_ids.has(str(item.id))).size()
		check(overlap<=int(pair[2]),str(pair[0])+" has a recognizably distinct programme from "+str(pair[1]))
	check(all_ids.size()>=87,"All 87 individually documented CC0 recordings are referenced")
	check(radio.station_track_count("folk_alpine")>=10 and radio.station_track_count("folk_swedish")>=10,"Alpine and Nordic acoustic tracks reach 10 each")
	check(Design.EXTERNAL_STATIONS.is_empty() and radio.station_track_count("erg0sphere")==0 and radio.station_track_count("ska_album")==0,"No third-party SoundCloud station can be tuned, streamed or bundled")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
