extends SceneTree
const Saves=preload("res://src/core/save_store.gd")
const Resort=preload("res://src/core/resort.gd")
const Passport=preload("res://src/core/passport.gd")
var passed:=0
var failed:=0
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Use an isolated skizones-test data directory");quit(1);return
	for slot in range(1,5):
		Saves.active_slot=slot
		var model:=Resort.new();model.new_game(true);model.money=100000+slot*1000;model.day=slot
		check(Saves.save_game(model,Saves.path_for_map("sonnenhang")).ok,"Save independent career "+str(slot))
		var passbook:=Passport.new();passbook.record(model);passbook.data.records.sonnenhang.guests=slot*123
		check(passbook.save_to(Saves.passport_path()),"Save independent unlocks "+str(slot))
	for slot in range(1,5):
		var loaded:=Resort.new()
		check(Saves.load_game(loaded,Saves.path_for_map("sonnenhang",slot)).ok and loaded.day==slot and loaded.money==100000+slot*1000,"Career "+str(slot)+" retains its own actual resort")
		var passbook:=Passport.new();passbook.load_from(Saves.passport_path(slot))
		check(passbook.totals().guests==slot*123,"Career "+str(slot)+" does not inherit another slot's unlocks")
		var summary:=Saves.summary(slot)
		check(summary.occupied and summary.day==slot,"Career card "+str(slot)+" reads actual saved metadata")
	Saves.active_slot=0
	var free:=Resort.new();free.new_game(false);free.money=777777
	check(Saves.save_game(free,Saves.path_for_map("sonnenhang")).ok and Saves.path_for_map("sonnenhang")!=Saves.path_for_map("sonnenhang",1),"Free build uses its own persistent files")
	check(Saves.path_for_map("filzmoos",1)==Saves.path_for_map("filzmoos",4),"Optional scenarios stay independent of all four careers")
	Saves.active_slot=2
	var path:=Saves.path_for_map("sonnenhang");var model:=Resort.new();Saves.load_game(model,path);model.money=222222;Saves.save_game(model,path)
	var damaged:=FileAccess.open(path,FileAccess.WRITE);damaged.store_string("damaged");damaged.close()
	var copy:=Resort.new()
	check(Saves.load_game(copy,path).ok and copy.money==102000,"A damaged main file recovers the correct career's own backup")
	var legacy:=Resort.new();legacy.new_game(true,20261027,"fichtenkamm");legacy.money=444444
	Saves.save_game(legacy,Saves.legacy_path("fichtenkamm"))
	check(Saves.migrate_legacy() and FileAccess.file_exists(Saves.legacy_path("fichtenkamm")),"Legacy migration copies valid data and preserves the original file")
	copy=Resort.new()
	check(Saves.load_game(copy,Saves.path_for_map("fichtenkamm",1)).ok and copy.money==444444 and copy.map_id=="fichtenkamm","The previous career becomes career slot one")
	check(Saves.migrate_legacy() and Saves.load_game(copy,Saves.path_for_map("sonnenhang",3)).ok and copy.money==103000,"Repeated migration cannot replace an existing career")
	check(Saves.archive_slot(3) and not Saves.summary(3).occupied,"An explicitly restarted career is archived before its active files are cleared")
	check(Saves.summary(1).occupied and Saves.summary(4).occupied and Saves.summary(0).occupied,"Restarting one slot preserves every other career and free build")
	check(not Saves.archive_slot(0) and not Saves.archive_slot(5),"Invalid career slots cannot erase unrelated save files")
	print("CAREER SLOTS: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
