extends SceneTree
const Creator=preload("res://src/core/map_creator_040.gd")
var failures:=0
var passes:=0
func check(condition: bool, label: String) -> void:
	if condition:passes+=1;print("PASS "+label)
	else:failures+=1;push_error("FAIL "+label)

func _init() -> void:
	var standard:Dictionary=Creator.generate()
	check(standard.ok,"Default map blueprint is valid")
	if not standard.ok:quit(1);return
	var spec:Dictionary=standard.map
	check(spec.peaks.size()==7,"Peak count matches controls")
	check(spec.bounds.size==Vector2(4200,4600),"Default size is standard")
	check(spec.map_creator and spec.schema==1,"Custom schema is versioned")
	check(Creator.generate()==Creator.generate(),"Same seed always generates identical blueprint")
	var different:Dictionary=Creator.generate({"seed":20261109})
	check(different.ok and different.map.peaks!=spec.peaks,"Different seeds change mountain layout")
	for shape in Creator.LANDFORMS:
		var result:Dictionary=Creator.generate({"landform":shape,"size":"compact","peak_count":12})
		check(result.ok and result.map.peaks.size()==12,"Valid map shape "+shape)
		if not result.ok:continue
		for peak in result.map.peaks:
			check(result.map.bounds.has_point(Vector2(peak[0],peak[1])),"Generated peak lies inside playable terrain")
	for size_id in Creator.SIZES:
		var result:Dictionary=Creator.generate({"size":size_id})
		check(result.ok and result.map.bounds.size==Creator.SIZES[size_id],"Map size "+size_id+" preserved")
	check(not Creator.generate({"peak_count":0}).ok,"Zero peaks rejected")
	check(not Creator.generate({"peak_count":200}).ok,"Unbounded peak count rejected")
	check(not Creator.generate({"peak_height":-100}).ok,"Negative elevation rejected")
	check(not Creator.generate({"forest":200}).ok,"Forest range enforced")
	check(not Creator.generate({"seed":INF}).ok,"Non-finite seeds rejected")
	check(not Creator.generate({"size":"planet"}).ok,"Unknown presets rejected")
	check(not Creator.generate({"unexpected":1}).ok,"Unrecognized settings rejected")
	var snowless:Dictionary=Creator.generate({"forest":0,"lake_count":0,"village_count":0})
	check(snowless.ok and snowless.map.tree_density==0 and snowless.map.lake_count==0,"Natural-feature counts preserve zero")
	var big:Dictionary=Creator.generate({"size":"grand","peak_count":24,"peak_height":2800,"forest":100})
	check(big.ok and big.map.peaks.size()==24,"Largest bounded map supports maximum mountain controls")
	print("RESULT: %d passed; %d failed" % [passes,failures])
	quit(1 if failures else 0)
