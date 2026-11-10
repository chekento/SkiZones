extends SceneTree
## Ten unique language-neutral PMDD texture IDs; duplicate boards do not count.
## Legacy v0.40.1 saves must restore unchanged, and a completed collection
## must survive checksum-protected career snapshots.
const Book=preload("res://src/core/achievement_book.gd")
const Collection=preload("res://src/core/poster_collection.gd")
const Posters=preload("res://src/core/holiday_poster_catalog.gd")
const Scenery=preload("res://src/world/festival_scenery.gd")
const Resort=preload("res://src/core/resort.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0

func _init()->void:call_deferred("run")
func check(ok: bool,title: String)->void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)

func run()->void:
	L.configure("de")
	var model:=Resort.new()
	model.new_game(true)
	var assets: Array=Posters.all_paths()
	var advent_found: Dictionary={}
	for day in [1,2]:
		var day_art: Array=Posters.visible_on_day("advent",day)
		check(day_art.size()==6,"Exactly six different Advent/Christmas motifs appear on day %d" % day)
		for art in day_art:advent_found[art]=true
	check(advent_found.size()==9,"Daily rotation exposes all nine Advent and Christmas motifs across two dates")
	var christmas_found: Dictionary={}
	for day in [25,26]:
		for art in Posters.visible_on_day("christmas",day):christmas_found[art]=true
	check(christmas_found.size()==7,"The Christmas holiday days expose all seven Christmas pictures")
	check(Posters.visible_on_day("new_year_eve",27).size()==1 and Posters.visible_on_day("november_poster",1).size()==6,"New Year art is a distinct, date-gated tenth picture")
	for approach in [Vector2(1,0),Vector2(0,1),Vector2(-1,-1)]:
		var yaw: float=Scenery.sign_yaw(approach)
		var facing: Vector2=Vector2(sin(yaw),cos(yaw))
		check(facing.dot(approach.normalized())>0.90,"Slanted lift-area billboard faces approaching skiers, not away from them")

	check(assets.size()==10 and Collection.total()==10,"Exactly ten unique official poster images")
	check(Collection.valid([]) and Collection.valid(assets) and not Collection.valid(assets+[assets[0]]),"Discovery list validates 0..10 unique official IDs")
	check(not Collection.valid(["res://assets/seasonal/fake.webp"]) and not Collection.valid([assets[0],assets[0]]),"Unknown and duplicated textures are rejected")
	var legacy: Dictionary=model.snapshot()
	check(not legacy.campaign.has("poster_discoveries"),"Old career snapshots need no new mandatory data fields")
	var first: Dictionary=Collection.discover(model,assets[0])
	check(first.is_new and first.found==1 and first.total==10 and first.events.size()==1 and str(first.events[0].detail).contains("1 von 10"),"First discovery notifies one out of ten")
	var duplicate: Dictionary=Collection.discover(model,assets[0])
	check(not duplicate.is_new and duplicate.found==1 and duplicate.events.is_empty(),"Tapping same poster twice never duplicates progress/popups")
	var second: Dictionary=Collection.discover(model,assets[1])
	check(second.is_new and second.found==2 and second.events.size()==1 and str(second.events[0].detail).contains("2 von 10"),"Second distinct artwork notifies two out of ten")
	check(not model.achievements.has(Book.POSTER_COLLECTOR_ID),"Completion award stays locked after two")
	var invalid: Dictionary=Collection.discover(model,"res://assets/seasonal/unknown.webp")
	check(not invalid.is_new and invalid.found==2,"Unknown/poster fallback IDs do not grant collection credit")
	var restored:=Resort.new()
	check(restored.restore(model.snapshot()).ok and Collection.progress(restored).found==2,"Two discovered pictures persist in a validated save")
	check(Collection.progress(restored).total==10 and Collection.discovered(restored).size()==2,"Loaded progress correctly identifies ten motifs")
	for i in range(2,assets.size()-1):
		var r: Dictionary=Collection.discover(restored,assets[i])
		check(r.is_new and r.found==i+1 and not r.awarded,"Unique motif %d increments progress exactly once" % [i+1])
	var last: Dictionary=Collection.discover(restored,assets[-1])
	check(last.is_new and last.found==10 and last.complete and last.awarded and last.events.size()==2,"Tenth discovery unlocks a distinct achievement and a progress notification")
	check(restored.achievements.count(Book.POSTER_COLLECTOR_ID)==1,"Only one special collector medal exists beside the original thousand")
	check(not Collection.discover(restored,assets[-1]).is_new and restored.achievements.count(Book.POSTER_COLLECTOR_ID)==1,"Revisiting last board never gives a second medal")
	var finished:=Resort.new()
	check(finished.restore(restored.snapshot()).ok and Collection.progress(finished).complete and finished.achievements.has(Book.POSTER_COLLECTOR_ID),"The actual medal and all ten IDs survive a save/reload")
	var bad: Dictionary=finished.snapshot()
	bad.campaign.poster_discoveries.append(bad.campaign.poster_discoveries[0])
	check(not Resort.new().restore(bad).ok,"Duplicate discoveries cannot be injected into a career save")
	bad=legacy.duplicate(true)
	bad.achievements.append(Book.POSTER_COLLECTOR_ID)
	check(not Resort.new().restore(bad).ok,"A forged medal without ten official posters is rejected")
	check(Resort.new().restore(legacy).ok,"An original save without any collection fields is still compatible")
	L.configure("en")
	var english:=Resort.new()
	check(english.restore(finished.snapshot()).ok and Collection.progress(english).complete,"Changing to English does not modify collection IDs")
	check(str(Book.entry(Book.POSTER_COLLECTOR_ID).name)=="Winter Poster Collector","Collector is translated without embedding text into pictures")
	L.configure("de")
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
