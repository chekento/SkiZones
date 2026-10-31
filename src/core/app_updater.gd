extends Node
const Catalog=preload("res://src/core/update_catalog.gd")
const L=preload("res://src/core/i18n.gd")
signal changed
var game: Node
var state:="idle"
var message_source:=""
var message_args: Array=[]
var message: String:
	get:return L.text(message_source)%message_args if not message_args.is_empty() else L.text(message_source)
var candidate: Dictionary={}
var build: Dictionary={}
var request: HTTPRequest
var stage:=""
var installed_code:=23
var installed_version: String=str(ProjectSettings.get_setting("application/config/version"))
var link_opener: Callable
var last_opened_url:=""
func setup(controller: Node) -> void:
	game=controller
	request=HTTPRequest.new();request.timeout=40;request.use_threads=true
	add_child(request);request.request_completed.connect(_completed)
	# Retire only the old updater receipt; saves and session files stay untouched.
	if FileAccess.file_exists("user://pending-update.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://pending-update.json"))
	if OS.get_name()=="Android" and Engine.has_singleton("AndroidRuntime"):
		var activity: Variant=Engine.get_singleton("AndroidRuntime").getActivity()
		var bridge: Variant=JavaClassWrapper.wrap("cloud.kosch.skizones.AppInfoBridge")
		if bridge!=null:
			var info: Variant=JSON.parse_string(bridge.installedInfo(activity))
			if info is Dictionary:
				installed_code=int(info.get("code",23));installed_version=str(info.get("version",installed_version))
			bridge.clearLegacyUpdateCache(activity)
	if OS.get_name()=="Android" and not OS.has_feature("android_lifecycle_test"):
		var config:=ConfigFile.new();config.load("user://updates.cfg")
		var last: Variant=config.get_value("updates","last_check",0)
		if (last is int or last is float) and Time.get_unix_time_from_system()-float(last)>21600:
			call_deferred("check",false)
func _set_status(value: String, text: String, args: Array=[]) -> void:
	state=value;message_source=text;message_args=args;changed.emit()
func check(manual: bool=true) -> void:
	if state=="checking":return
	candidate={};build={};stage="releases";request.body_size_limit=1048576
	_set_status("checking","Suche nach neuen Versionen auf GitHub …")
	var error:=request.request(Catalog.API,["Accept: application/vnd.github+json","User-Agent: SkiZones/"+installed_version])
	if error!=OK:_failure()
	elif not manual:
		var config:=ConfigFile.new();config.set_value("updates","last_check",int(Time.get_unix_time_from_system()));config.save("user://updates.cfg")
func _failure() -> void:
	_set_status("error","Die Update-Prüfung war nicht möglich. Prüfe deine Internetverbindung und versuche es später erneut.")
func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:_failure();return
	var value: Variant=JSON.parse_string(body.get_string_from_utf8())
	if stage=="releases":
		if not value is Array:_failure();return
		candidate=Catalog.select(value,installed_version)
		if candidate.is_empty():_set_status("current","Du hast die aktuelle veröffentlichte Version.");return
		stage="manifest"
		if request.request(candidate.manifest,["User-Agent: SkiZones/"+installed_version])!=OK:_failure()
	elif stage=="manifest":
		build=Catalog.manifest(value,candidate,installed_code)
		if build.is_empty():
			_set_status("error","Dieses Update konnte nicht geprüft werden. Bitte versuche es nach der nächsten Veröffentlichung erneut.");return
		_set_status("available","Version %s ist verfügbar. Deine vier Karrieren und die anderen Spielstände bleiben erhalten.",[candidate.version])
func open_download() -> void:
	if state not in ["available","opened"]:return
	if Catalog.pending({"version":1,"candidate":candidate,"build":build},installed_version,installed_code).is_empty():
		_set_status("error","Dieses Update konnte nicht geprüft werden. Bitte versuche es nach der nächsten Veröffentlichung erneut.");return
	if game.has_game:
		if not game.save_game():
			_set_status("error","Dein Resort konnte nicht gespeichert werden. Der Download wurde noch nicht geöffnet.");return
		game.app_session.save(game)
	var error: int=link_opener.call(candidate.release) if link_opener.is_valid() else OS.shell_open(candidate.release)
	if error!=OK:
		_set_status("error","Der Browser konnte nicht geöffnet werden. Versuche es später erneut.");return
	last_opened_url=candidate.release
	_set_status("opened","GitHub wurde geöffnet. Lade dort die APK herunter und installiere sie über die vorhandene App. Danach über das App-Symbol weiterspielen.")
