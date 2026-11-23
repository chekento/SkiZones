extends SceneTree
## Holiday visuals only follow existing simulator positions, no fake crowds.
const Hats=preload("res://src/world/holiday_guest_visual_043.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error("FAIL "+message)
func _init()->void:call_deferred("run")
func run()->void:
	var people:Array=[
		{"id":1,"phase":"moving","leg":0,"years":36,"route":{"legs":[{"kind":"walk"}]},
		 "family":[{"years":9},{"years":38},{"years":36}]},
		{"id":2,"phase":"moving","leg":0,"route":{"legs":[{"kind":"ski"}]}},
		{"id":3,"phase":"moving","leg":0,"route":{"legs":[{"kind":"lift"}]}},
		{"id":4,"phase":"waiting","leg":0,"route":{"legs":[{"kind":"visit"}]}},
		{"id":5,"phase":"moving","leg":0,"incident":18,"route":{"legs":[{"kind":"walk"}]}},
		{"id":6,"phase":"moving","leg":0,"route":{"legs":[{"kind":"visit"}]}},
		{"id":7,"phase":"leaving","leg":0,"route":{"legs":[{"kind":"walk"}]}}
	]
	var original:Array=people.duplicate(true)
	var positions:Dictionary={1:Vector3(1,2,3),2:Vector3(4,5,6),3:Vector3(7,8,9),
		4:Vector3(2,2,2),5:Vector3(8,8,8),6:Vector3(10,0,10),7:Vector3(11,0,11)}
	var family:Dictionary={1:[Vector3(1.1,2,3),Vector3(1.7,2,3)]}
	var hats:Array=Hats.collect(people,positions,family,"nikolaus")
	check(hats.size()==4,"Only the real walking family and a visiting guest receive holiday hats")
	check(hats[0].id==1 and hats[1].scale==0.72 and hats[2].scale==1.0 and hats[3].id==6,"Actual family poses and age-specific sizes are preserved")
	check(Hats.collect(people,positions,family,"christmas_eve").size()==4 and Hats.collect(people,positions,family,"boxing_day").size()==4,"Christmas dates use the same real model guests")
	check(Hats.collect(people,positions,family,"").is_empty(),"No festive hats outside event dates")
	check(Hats.collect(people,positions,family,"nikolaus",2).size()==2,"Visible guest hats have a strict Android performance cap")
	check(not Hats.eligible(people[4],positions,"nikolaus"),"Injured guests are not animated as regular festive visitors")
	check(not Hats.eligible(people[1],positions,"nikolaus") and not Hats.eligible(people[2],positions,"nikolaus"),"Skiing and lift riders do not receive floating pedestrian hats")
	check(not Hats.eligible(people[3],positions,"nikolaus") and not Hats.eligible(people[6],positions,"nikolaus"),"Hotel sleepers and leaving guests do not create holiday figures")
	check(people==original,"Holiday rendering never changes guest state, money, visits or save fields")
	var parent:=Node3D.new()
	root.add_child(parent)
	var visual:=Hats.new()
	visual.setup(parent,StandardMaterial3D.new())
	check(visual.node.multimesh.instance_count==Hats.MAX_VISIBLE and visual.node.multimesh.visible_instance_count==0,"Santa hats are one batched 3D draw call and initially invisible")
	parent.queue_free()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
