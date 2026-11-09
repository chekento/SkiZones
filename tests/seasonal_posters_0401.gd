extends SceneTree
## Release gate for all ten actual PMDD 4.0 landscape billboards and their
## localized overlays. Calendar is OS-local; no save-game clock affects it.
const Posters=preload("res://src/core/holiday_poster_catalog.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0

func _init()->void:call_deferred("run")
func check(ok: bool, name: String) -> void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)

func run()->void:
	var all: Array=Posters.all_paths()
	check(all.size()==10,"Ten different PMDD 4.0 pictures are registered")
	var seen:Dictionary={}
	for path in all:
		check(not seen.has(path),"Unique image path: "+str(path))
		seen[path]=true
		var exists: bool=ResourceLoader.exists(path)
		check(exists,"Original WebP texture available: "+str(path))
		if not exists:continue
		var tex: Texture2D=load(path) as Texture2D
		check(tex!=null and tex.get_width()==1280 and tex.get_height()==720,"Landscape 1280 x 720 asset: "+str(path))
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
		check(bytes.size()>=32768 and bytes.size()<=262144,"Compact, nonempty WebP image (<=256 KiB): "+str(path))
	check(Posters.CHRISTMAS.size()==7 and Posters.ADVENT.size()==2 and Posters.NEW_YEAR.size()==1,"Seven Christmas, two Advent and one New Year visual")
	check(Posters.pool("november_poster").size()==9 and not Calendar.visible({"year":2026,"month":11,"day":30}),"November previews Christmas and Advent images without starting the calendar")
	check(Posters.pool("advent").size()==9 and Calendar.unlocked({"year":2026,"month":12,"day":1},1),"Advent scenes begin on December 1 with calendar day 1")
	check(Posters.pool("christmas").size()==7 and not Posters.pool("christmas").has(Posters.ADVENT[0]),"December 25 and 26 use only Christmas imagery")
	check(Posters.pool("new_year_eve").size()==1 and Calendar.season({"year":2026,"month":12,"day":27})=="new_year_eve","New Year campaign starts on December 27")
	check(Posters.pool("new_year").size()==1 and Calendar.season({"year":2027,"month":1,"day":2})=="","New Year art is limited to January 1")
	L.configure("de")
	check(Posters.headline("november_poster",Posters.ADVENT[0])=="ADVENTSKALENDER · AB 1. DEZEMBER","November Advent teaser is correctly labelled in German")
	L.configure("en")
	check(Posters.headline("november_poster",Posters.ADVENT[0])=="ADVENT CALENDAR · FROM DECEMBER 1","Text is localized without changing a single art file")
	check(Posters.headline("new_year_eve",Posters.NEW_YEAR[0])=="NEW YEAR'S EVE IN THE MOUNTAINS","New Year has its own English caption")
	L.configure("de")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
