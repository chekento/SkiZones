extends SceneTree
## 0.40: pure operational diagnostics, including historic guest shapes.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Pulse=preload("res://src/core/resort_pulse_040.gd")
var passed:=0
var failed:=0

func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func _init() -> void:call_deferred("run")

func run() -> void:
	var model:=Resort.new()
	model.new_game(true,20261108,"sonnenhang")
	var first: Dictionary=Pulse.inspect(model)
	check(first.total_lifts==model.lifts.size() and first.visitors==model.present_guests(),"The control room uses real installed lifts and present visitors")
	check(first.alerts is Array and first.lifts is Array and first.money==model.money,"The read-only report includes sortable real data")
	check(first.waiting==model.queue_size(),"The waiting count comes from current lift queues")
	var before: String=JSON.stringify(model.snapshot())
	Pulse.inspect(model)
	check(before==JSON.stringify(model.snapshot()),"Inspecting diagnostics never changes saved progression or geometry")
	Ops.enable(model)
	model.lifts[0].fault="motor"
	model.guests.append({"id":991,"phase":"waiting","group_size":4,"needs":{"warmth":12.0,"hunger":8.0,"bladder":91.0,"energy":15.0}})
	var urgent:Dictionary=Pulse.inspect(model)
	check(urgent.faults>=1 and urgent.alerts.any(func(a):return a.kind=="fault"),"A real broken lift is a high-priority maintenance alert")
	check(urgent.cold>=4 and urgent.hungry>=4 and urgent.bathroom>=4 and urgent.low_energy>=4,"Warmth, hunger, bathroom and energy are counted from current guest needs")
	check(urgent.alerts.size()>=4 and int(urgent.alerts[0].severity)==3,"Critical alerts precede informational hints")
	check(urgent.lifts.size()==model.lifts.size() and urgent.lifts[0].severity>=2,"The lift monitor prioritises affected real assets")
	check(model.lifts[0].fault=="motor" and model.guests[-1].needs.warmth==12.0,"Inspection never repairs assets or edits guest needs by itself")
	print("0.40 RESORT PULSE: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
