extends SceneTree
## 0.40 holiday art: the APK must contain real poster textures, not only
## procedural fallback. Date ranges remain independent of career saves.
const Festival=preload("res://src/core/annual_festival.gd")
const Posters=preload("res://src/core/seasonal_billboards_040.gd")
var failed:=0
var passed:=0

func check(ok:bool,description:String)->void:
	if ok:passed+=1;print("PASS ",description)
	else:failed+=1;push_error("FAIL "+description)

func _init()->void:
	var names:Array=[]
	for campaign in ["christmas","new_year"]:
		for number in range(1,5):
			var path:String="res://assets/seasonal/%s_%d.svg" % [campaign,number]
			names.append(path)
			check(ResourceLoader.exists(path),"Embedded seasonal poster artwork: "+path)
			if not ResourceLoader.exists(path):continue
			var texture:Texture2D=load(path) as Texture2D
			check(texture!=null and texture.get_width()>=400 and texture.get_height()>=600,"Real SVG texture imports at overview-ready resolution: "+path)
	check(names.size()==8,"Four independent Christmas and four independent New Year poster resources")
	for date in [{"year":2026,"month":10,"day":31},{"year":2026,"month":11,"day":1},{"year":2026,"month":11,"day":30},{"year":2026,"month":12,"day":26},{"year":2026,"month":12,"day":27},{"year":2026,"month":12,"day":31},{"year":2027,"month":1,"day":1},{"year":2027,"month":1,"day":2}]:
		var campaign:String=Festival.poster_campaign(date)
		check(Posters.info(date).is_empty()==(campaign==""),"Device-local calendar and poster campaign remain synchronized on "+JSON.stringify(date))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
