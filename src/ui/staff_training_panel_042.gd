extends VBoxContainer
## One visible, pausing practical course; fees and qualifications live in model.
const L=preload("res://src/core/i18n.gd")
const Training=preload("res://src/core/staff_training_042.gd")
var hud:CanvasLayer
var asset_id:=-1
var session:Dictionary={}
var choices:Array[Button]=[]
var selected:OptionButton
var feedback:Label
var content:VBoxContainer
var employees:Array=[]
var _held_pause:=false
var _was_paused:=false
var _pending_action:=false

func setup(owner_hud:CanvasLayer,id:int)->void:
	hud=owner_hud;asset_id=id
	name="staff_academy"
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	visibility_changed.connect(_visibility)
	_rebuild()

func _label(parent:Node,text_value:String,size_value:int=17)->Label:
	return hud._label(parent,text_value,size_value,hud.INK,true)

func _button(parent:Node,text_value:String,action:Callable)->Button:
	var button:Button=hud._button(parent,text_value,func():
		if _pending_action:return
		_pending_action=true
		_dispatch_action.call_deferred(action)
	,true)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y=54
	return button

func _dispatch_action(action:Callable)->void:
	if is_inside_tree():action.call()
	_pending_action=false

func _clear()->void:
	choices.clear()
	for child in get_children():remove_child(child);child.queue_free()

func _rebuild()->void:
	_clear()
	_label(self,L.text("MITARBEITER-AKADEMIE"),22)
	_label(self,L.text("Drei Praxisfälle · direkte Erklärungen · dauerhafte Qualifikation. Die Resortzeit pausiert während des Trainings."),16)
	employees=Training.roster(hud.game.model,hud.game.model.asset(asset_id))
	if employees.is_empty():
		_label(self,L.text("Stelle zuerst passende Fachkräfte für diese Anlage ein."));return
	selected=OptionButton.new();selected.name="academy_employee"
	selected.fit_to_longest_item=false;selected.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	selected.custom_minimum_size.y=52
	for person in employees:selected.add_item(str(person.name)+" · "+L.text(str(hud.game.model.Ops.ROLES[person.role].name)))
	add_child(selected)
	selected.item_selected.connect(func(_index:int):_employee_details())
	content=VBoxContainer.new();content.add_theme_constant_override("separation",10);add_child(content)
	_employee_details()

func _employee_details()->void:
	for child in content.get_children():content.remove_child(child);child.queue_free()
	var person:Dictionary=employees[selected.selected]
	var state:Dictionary=person.get("training",{})
	_label(content,L.text("Qualifikation %d · Erfahrung %d / 240 · Bestwert %d %%") % [int(person.qualification),int(state.get("xp",0)),int(state.get("best",0))])
	var progress:=ProgressBar.new();progress.max_value=240;progress.value=mini(240,int(state.get("xp",0)));progress.show_percentage=false;progress.custom_minimum_size.y=14;content.add_child(progress)
	_label(content,L.text("Qualifikation 2 ab 100 Erfahrung, Stufe 3 ab 240. Passende Fachkräfte verbessern den Service; Technikkenntnisse beschleunigen echte Reparaturen. Maximal zwei Kurse pro Person und Tag."),15)
	_label(content,L.text("90 € Kursgebühr bei Beginn; im freien Modus kostenlos. Ein Abbruch beendet den bezahlten Versuch ohne Erfahrung."),15)
	var start:=_button(content,L.text("Praxis-Training starten · 90 €"),_start)
	start.name="academy_start"
	feedback=_label(content,"")

func _start()->void:
	session=Training.start(hud.game.model,int(employees[selected.selected].id))
	if not session.get("ok",false):feedback.text=str(session.get("message",""));return
	_was_paused=hud.game.paused;_held_pause=not _was_paused;hud.game.paused=true
	_save()
	_show_task()

func _show_task()->void:
	var task:Dictionary=Training.challenge(hud.game.model,session)
	_clear()
	if task.is_empty():_release_pause();_rebuild();return
	_label(self,L.text("PRAXISFALL %d / 3") % (int(session.step)+1),21)
	var employee:Dictionary=Training.person(hud.game.model,int(session.person))
	_label(self,str(employee.name)+" · "+L.text(str(hud.game.model.Ops.ROLES[employee.role].name)),16)
	var progress:=ProgressBar.new();progress.max_value=3;progress.value=int(session.step);progress.show_percentage=false;progress.custom_minimum_size.y=14;add_child(progress)
	_label(self,L.text(str(task.prompt)),22)
	for index in range(3):
		var chosen:int=index
		var button:=_button(self,L.text(str(task.choices[index])),func():_answer(chosen))
		button.name="academy_choice_%d" % index;choices.append(button)
	_button(self,L.text("Training abbrechen"),func():session.clear();_release_pause();_rebuild())

func _answer(index:int)->void:
	var result:Dictionary=Training.answer(hud.game.model,session,index)
	if not result.get("ok",false):session.clear();_release_pause();_rebuild();return
	_clear()
	_label(self,L.text("Gut entschieden") if int(result.score)==100 else L.text("Hier lohnt sich ein anderer Weg"),22)
	_label(self,L.text(str(result.correct)),19)
	_label(self,L.text(str(result.explanation)),18)
	if result.finished:
		_release_pause();_save()
		_label(self,L.text("Kurs abgeschlossen · %d %% · +%d Erfahrung · Qualifikation %d") % [int(result.average),int(result.earned),int(result.qualification)],20)
		_button(self,L.text("Zurück zum Team"),func():session.clear();_rebuild()).name="academy_done"
	else:
		_button(self,L.text("Verstanden · nächster Praxisfall"),_show_task).name="academy_continue"

func _save()->void:
	if hud.game.has_game:hud.game.save_game()

func _release_pause()->void:
	if _held_pause and is_instance_valid(hud) and is_instance_valid(hud.game):hud.game.paused=_was_paused
	_held_pause=false

func _visibility()->void:
	if not is_visible_in_tree() and not session.is_empty():
		session.clear();_release_pause();_rebuild()

func _exit_tree()->void:_release_pause()
