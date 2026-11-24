extends SceneTree
## An event host only reacts to the *real* resort's rendered foot traffic.
const Market=preload("res://src/world/holiday_plaza_043.gd")
var passed:=0
var failed:=0
func check(ok:bool,detail:String)->void:
	if ok:passed+=1;print("PASS ",detail)
	else:failed+=1;push_error("FAIL "+detail)
func _init()->void:call_deferred("run")

func run()->void:
	check(Market.event_for({"year":2026,"month":12,"day":6})=="nikolaus","Nikolaus host occurs on December 6")
	for day in [24,25,26]:
		check(not Market.event_for({"year":2026,"month":12,"day":day}).is_empty(),"Christmas plaza is active on day "+str(day))
	check(Market.event_for({"year":2026,"month":12,"day":7})=="" and Market.event_for({"year":2026,"month":11,"day":30})=="","Ordinary and November dates create no event host")
	var walkers:Array=[
		{"id":1,"phase":"moving","leg":0,"route":{"legs":[{"kind":"walk"}]}},
		{"id":2,"phase":"moving","leg":0,"route":{"legs":[{"kind":"visit"}]}},
		{"id":3,"phase":"moving","leg":0,"route":{"legs":[{"kind":"ski"}]}},
		{"id":4,"phase":"moving","leg":0,"route":{"legs":[{"kind":"walk"}]},"incident":6},
		{"id":5,"phase":"leaving","leg":0,"route":{"legs":[{"kind":"walk"}]}},
		{"id":6,"phase":"moving","leg":0,"route":{"legs":[{"kind":"lift"}]}},
		{"id":7,"phase":"waiting","leg":0,"route":{"legs":[{"kind":"visit"}]}}
	]
	var before:Array=walkers.duplicate(true)
	var positions:Dictionary={1:Vector3(8,0,7),2:Vector3(45,0,20),3:Vector3(10,0,15),4:Vector3(2,0,2),5:Vector3(1,0,1),6:Vector3(2,0,0),7:Vector3(4,0,4)}
	var plaza:=Vector3.ZERO
	check(Market.nearby_visitors(walkers,positions,plaza,60.0)==2,"Only two physically present pedestrians activate the market")
	check(Market.nearby_visitors(walkers,positions,plaza,12.0)==1,"Audience proximity uses real world positions, not visitor totals")
	check(Market.nearby_visitors(walkers,positions,plaza,0.0)==0 and Market.nearby_visitors(walkers,positions,plaza,-4.0)==0,"No invalid radius can activate celebrations")
	check(Market.nearby_visitors(walkers,{},plaza,60.0)==0,"No attendance without actual rendered guests")
	check(walkers==before,"Checking plaza attendance is side-effect free for all careers")
	var nikolaus:=Market.make("alpine","nikolaus",StandardMaterial3D.new())
	var xmas:=Market.make("monochrome","christmas_day",StandardMaterial3D.new())
	check(nikolaus.get_meta("festival_event","")=="nikolaus" and xmas.get_meta("festival_event","")=="christmas_day","Plaza displays proper dated event stages")
	check(nikolaus.get_node_or_null("celebration_sculpture") is MeshInstance3D and xmas.get_node_or_null("celebration_sculpture") is MeshInstance3D,"Each theme has original actual 3D celebration sculpture")
	check(not nikolaus.visible and not xmas.visible,"Plaza hosts are hidden until real audience arrives")
	Market.animate(nikolaus,true,1.5)
	check(nikolaus.visible and nikolaus.scale!=Vector3.ONE,"Real audience can reveal a gently animated Nikolaus host")
	Market.animate(nikolaus,false,2.2)
	check(not nikolaus.visible,"Empty plaza hides event host rather than faking a crowd")
	nikolaus.free()
	xmas.free()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
