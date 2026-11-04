extends SceneTree
## Tests for real newspaper model, civic archive, strict calendar boundary and
## new town aesthetics; tests are read-only for existing saved careers.
const Styles=preload("res://src/core/visual_styles.gd")
const Resort=preload("res://src/core/resort.gd")
const Newspaper=preload("res://src/core/newspaper.gd")
const TownHall=preload("res://src/core/town_hall.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const Catalog=preload("res://src/core/catalog.gd")
const PosterArt=preload("res://src/ui/seasonal_poster_art.gd")
const NewspaperArt=preload("res://src/ui/newspaper_art.gd")
const RadioAd=preload("res://src/ui/radio_ad_art.gd")
const Scenery=preload("res://src/world/festival_scenery.gd")
const Dressing=preload("res://src/world/village_dressing.gd")
var passed:=0
var failed:=0

func check(ok: bool,title: String) -> void:
	if ok:
		passed+=1
		print("PASS ",title)
	else:
		failed+=1
		push_error("FAIL "+title)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Styles.IDS.size()==10 and Styles.IDS.has("neon_noir") and Styles.IDS.has("aurora_ink") and Styles.IDS.has("bauhaus"),"All ten creative themes are selectable")
	var distinct: Dictionary={}
	for id in Styles.IDS:
		var values: Dictionary=Styles.palette(id)
		var colors: Dictionary=Styles.ui_palette(id)
		var detail: Dictionary=Styles.detail_tints(id)
		check(values.has("snow") and values.has("rock") and colors.has("panel") and detail.has("wood"),"Complete world and UI art palette: "+id)
		distinct[str(values.top)+str(values.snow)+str(values.rock)] = true
	check(distinct.size()==10,"All ten world styles use distinct palette identity")
	var nov1: Dictionary={"year":2026,"month":11,"day":1}
	var nov30: Dictionary={"year":2026,"month":11,"day":30}
	var bad31: Dictionary={"year":2026,"month":11,"day":31}
	var dec1: Dictionary={"year":2026,"month":12,"day":1}
	check(Calendar.preview_poster(nov1) and Calendar.preview_poster(nov30),"Christmas campaign is visible from November 1 through November 30 inclusive")
	check(not Calendar.valid_date(bad31) and not Calendar.preview_poster(bad31),"November 31 is always rejected")
	check(not Calendar.preview_poster(dec1) and Calendar.unlocked(dec1,1) and not Calendar.unlocked(dec1,2),"December 1 removes posters and opens only Advent door one")
	check(TownHall.HISTORY.size()>=32 and str(TownHall.HISTORY[0].version)=="0.1.1" and str(TownHall.HISTORY[-1].version)=="0.30.0","Published 0.30 hotfix is in the archive while 0.31 remains the current candidate")
	check(TownHall.ROADMAP.size()==4 and str(TownHall.ROADMAP[0]["from"])=="04.11.2026" and str(TownHall.ROADMAP[-1]["to"])=="04.01.2027","Two-month roadmap has four delivery/acceptance phases")
	for phase in TownHall.ROADMAP:
		check(phase.deliverables.size()>=3 and not str(phase.acceptance).is_empty(),"Civic phase has concrete work and review gate")
	var model:=Resort.new()
	model.new_game(true,20261027,"sonnenhang",true)
	check(model.building_count("town_hall")==1,"New starter resort contains exactly one complimentary Rathaus")
	var original: Dictionary=model.snapshot()
	check(not model.build_access_message("town_hall",false).is_empty() and not model.build_building("town_hall",Vector2(300,300)).ok and model.snapshot()==original,"A free civic landmark cannot be duplicated to farm shift rewards")
	check(TownHall.ensure_new_town(model) and model.snapshot()==original,"Reopening City Hall never creates duplicate buildings or modifies careers")
	var newspaper: Dictionary=Newspaper.statistics(model)
	check(newspaper.issue==model.day and newspaper.district!="" and newspaper.sold==Newspaper.sold(model),"Newspaper reports only the live resort's real metrics")
	var spots: Array=Newspaper.radio_spots(model,6)
	var unique: Dictionary={}
	for ad in spots:
		unique[str(ad.id)]=true
		check(not str(ad.name).is_empty() and not str(ad.copy).is_empty(),"Ad source belongs to a registered real channel "+str(ad.id))
	check(spots.size()==6 and unique.size()==6,"Six rotating, distinct channel advertisements fill each edition")
	model.day+=1
	check(str(Newspaper.radio_spots(model,6)[0].id)!=str(spots[0].id),"Daily editorial schedule rotates independently of saved radio preference")
	check(Catalog.BUILDINGS.has("town_hall") and int(Catalog.BUILDINGS.town_hall.cost)>750 and model.buildings.filter(func(building): return building.kind=="town_hall")[0].cost==0,"Starter landmark is complimentary but manual replacement cannot farm free shift rewards")
	var head:=NewspaperArt.new()
	root.add_child(head)
	head.size=Vector2(345,200)
	head.setup("bauhaus",model.day,"Sonnenhang")
	check(head.custom_minimum_size.y>120.0 and head.style_id=="bauhaus","Newspaper header responds to mobile landscape and chosen theme")
	var ad_image:=RadioAd.new()
	root.add_child(ad_image)
	ad_image.size=Vector2(250,90)
	ad_image.set_station("ska_album","neon_noir")
	check(ad_image.style_id=="neon_noir" and ad_image.station_id=="ska_album","Radio ads inherit visual art direction")
	var poster:=PosterArt.new()
	root.add_child(poster)
	poster.size=Vector2(340,580)
	check(poster.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Seasonal poster never consumes gameplay touches itself")
	check(Scenery.new().hit_poster(Vector2.ZERO)==false,"No imaginary poster gets clicked outside campaign")
	var mesh:=Dressing.prop_mesh("sculpture","aurora_ink")
	check(mesh!=null and mesh.get_surface_count()>0,"Automatic town props create real artistic geometry")
	for node in [head,ad_image,poster]:
		node.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)

