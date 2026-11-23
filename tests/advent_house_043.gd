extends SceneTree
## Each visible facade door has one unambiguous pick number; reward state is
## shared with the existing atomic annual-calendar archive, never the career.
const House=preload("res://src/world/advent_house_043.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const Scenery=preload("res://src/world/festival_scenery.gd")
const CalendarUI=preload("res://src/ui/winter_festival.gd")
var passed:int=0
var failed:int=0

func _init()->void:call_deferred("run")
func check(ok:bool,detail:String)->void:
	if ok:passed+=1;print("PASS ",detail)
	else:failed+=1;push_error("FAIL "+detail)

func run()->void:
	var recognized:Dictionary={}
	for number in range(1,25):
		var middle:Vector3=House.door_center(number)
		var selected:int=House.door_at(middle)
		check(selected==number and not recognized.has(selected),"Door %d has an individually pickable 3D center" % number)
		recognized[selected]=true
	check(recognized.size()==24,"All 24 doors are unique and mapped on the physical house")
	check(House.COLUMNS==4 and CalendarUI.door_button_width(360.0)==64.0 and CalendarUI.door_button_width(1280.0)==90.0,"Calendar uses narrow mobile touch cells while retaining the physical 4-column facade")
	check(House.door_at(Vector3(0,0,House.FRONT_Z))==0,"A tap on facade wood cannot grant a door reward")
	check(House.door_at(Vector3(40,20,House.FRONT_Z))==0,"Taps beyond the building select no holiday door")
	check(House.door_at(Vector3(0,20,0))==0,"3D picking rejects points behind the Advent facade")
	var n6:Vector3=House.door_center(6)
	check(House.door_at(n6+Vector3(House.DOOR_WIDTH*0.52,0,0))==0,"Taps between hinged doors cannot select the wrong day")
	var six:Dictionary={"year":2026,"month":12,"day":6,"hour":12,"minute":0,"second":0}
	var christmas:Dictionary={"year":2026,"month":12,"day":24,"hour":12,"minute":0,"second":0}
	check(Calendar.unlocked(six,6) and not Calendar.unlocked(six,7),"World-door unlocking uses real December days")
	var archive:=Calendar.new()
	archive.path="user://advent_house_043_qa.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive.path))
	var first:Dictionary=archive.claim(6,six)
	check(first.ok and not archive.claim(6,six).ok,"One door tapped from the map pays only once per calendar year")
	check(not archive.claim(24,six).ok and archive.claim(24,christmas).ok,"Christmas Eve door unlocks only on December 24")
	var facade:=House.create("alpine",[6,24],StandardMaterial3D.new())
	check(facade.get_child_count()==25 and facade.get_node_or_null("door_24")!=null,"3D Advent architecture has 24 individual hinged and numbered doors")
	var lanterns:=facade.get_node_or_null("advent_timber_roof/roof_fairy_lights") as MultiMeshInstance3D
	check(lanterns!=null and lanterns.multimesh.instance_count==36,"PMDD roof lights are batched into one hardware instancing draw")
	check(facade.get_node_or_null("door_8/advent_door_knob") is MeshInstance3D,"Each 3D door has a real metal handle attached to its hinge")
	var gift6:=facade.get_node_or_null("advent_timber_roof/reward_preview_6") as MeshInstance3D
	var gift7:=facade.get_node_or_null("advent_timber_roof/reward_preview_7") as MeshInstance3D
	check(gift6!=null and gift7!=null and gift6.visible and not gift7.visible,"Only archived open Advent doors reveal actual 3D presents")
	check(gift6!=null and gift7!=null and gift6.mesh==gift7.mesh,"All 24 Advent gift displays reuse one themed mesh")
	var opened:=facade.get_node_or_null("door_6") as Node3D
	var closed:=facade.get_node_or_null("door_7") as Node3D
	check(opened!=null and closed!=null and opened.rotation.y< -1.0 and is_zero_approx(closed.rotation.y),"Already claimed doors visually stay open after world reload")
	if closed!=null:
		House.reveal(facade,7)
		check(closed.rotation.y< -1.0,"Door opening updates the 3D hinge even before scene attachment")
		check(gift7!=null and gift7.visible,"Revealing an Advent door also displays its 3D present")
	facade.free()
	var mono:=House.create("monochrome",[],StandardMaterial3D.new())
	check(str(mono.get_meta("advent_style",""))=="monochrome","Advent depth facade retains its selected theme")
	House.reveal(mono,1)
	var mono_leaf:=mono.get_node_or_null("door_1/advent_door_leaf") as MeshInstance3D
	check(mono_leaf!=null and (mono_leaf.material_override as StandardMaterial3D).albedo_color==Color("b5b5b5"),"Opening a 3D door preserves monochrome rather than switching to alpine")
	mono.free()
	var new_year:=Calendar.new()
	new_year.path=archive.path
	check(new_year.overview(christmas).claimed.has(6) and new_year.overview(christmas).claimed.has(24),"World and UI doors share persistent rewards")
	check(new_year.claim(6,{"year":2027,"month":12,"day":6}).ok,"New Advent year has its own independent set of doors")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(archive.path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
