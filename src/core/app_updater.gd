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
var bridge: Variant
var activity: Variant
var download_path:=""
var installed_code:=22
var installed_version: String=str(ProjectSettings.get_setting("application/config/version"))
var progress:=0
func setup(controller: Node) -> void:
	game=controller
	request=HTTPRequest.new();request.timeout=40;request.use_threads=true
	add_child(request);request.request_completed.connect(_completed)
	if OS.get_name()=="Android" and Engine.has_singleton("AndroidRuntime"):
		activity=Engine.get_singleton("AndroidRuntime").getActivity()
		bridge=JavaClassWrapper.wrap("cloud.kosch.skizones.UpdateBridge")
		if bridge!=null:
			download_path=bridge.cachePath(activity)
			var info: Variant=JSON.parse_string(bridge.installedInfo(activity))
			if info is Dictionary:
				installed_code=int(info.get("code",22));installed_version=str(info.get("version",installed_version))
	if OS.get_name()=="Android" and not OS.has_feature("android_lifecycle_test"):
		var config:=ConfigFile.new();config.load("user://updates.cfg")
		var last: Variant=config.get_value("updates","last_check",0)
		if (last is int or last is float) and Time.get_unix_time_from_system()-float(last)>21600:
			call_deferred("check",false)
func _set_status(value: String, text: String, args: Array=[]) -> void:
	state=value;message_source=text;message_args=args;changed.emit()
func check(manual: bool=true) -> void:
	if state in ["checking","downloading"]:return
	candidate={};build={};progress=0
	stage="releases";request.download_file="";request.body_size_limit=1048576
	_set_status("checking","Suche nach neuen Versionen auf GitHub …")
	var error:=request.request(Catalog.API,["Accept: application/vnd.github+json","User-Agent: SkiZones/"+installed_version])
	if error!=OK:_failure()
	elif not manual:
		var config:=ConfigFile.new();config.set_value("updates","last_check",int(Time.get_unix_time_from_system()));config.save("user://updates.cfg")
func _failure() -> void:
	_set_status("error","Die Update-Prüfung war nicht möglich. Prüfe deine Internetverbindung und versuche es später erneut.")
func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		if stage=="apk":DirAccess.remove_absolute(download_path)
		_failure();return
	if stage=="releases":
		candidate=Catalog.select(JSON.parse_string(body.get_string_from_utf8()),installed_version)
		if candidate.is_empty():
			if not JSON.parse_string(body.get_string_from_utf8()) is Array:_failure()
			else:_set_status("current","Du hast die aktuelle veröffentlichte Version.")
			return
		stage="manifest"
		if request.request(candidate.manifest,["User-Agent: SkiZones/"+installed_version])!=OK:_failure()
	elif stage=="manifest":
		build=Catalog.manifest(JSON.parse_string(body.get_string_from_utf8()),candidate,installed_code)
		if build.is_empty():
			_set_status("error","Dieses Update konnte nicht geprüft werden. Bitte versuche es nach der nächsten Veröffentlichung erneut.");return
		_set_status("available","Version %s ist verfügbar. Deine vier Karrieren und die anderen Spielstände bleiben erhalten.",[candidate.version])
	elif stage=="apk":
		if not FileAccess.file_exists(download_path) or FileAccess.get_sha256(download_path)!=build.sha256:
			DirAccess.remove_absolute(download_path);_set_status("error","Der Download ist unvollständig oder beschädigt. Bitte lade das Update erneut herunter.");return
		var status: String=bridge.validate(activity,download_path,build.sha256,int(build.size_bytes),int(build.version_code)) if bridge!=null else "unavailable"
		if status!="ok":
			DirAccess.remove_absolute(download_path);_set_status("error","Das Update passt nicht zu dieser Installation. Deine Spielstände bleiben erhalten. Installiere die App nicht neu.");return
		progress=100;_set_status("ready","Das Update ist geprüft und bereit. Vor der Installation wird dein aktuelles Resort gespeichert.")
func download() -> void:
	if state!="available" or build.is_empty():return
	if bridge==null:
		OS.shell_open(candidate.release);return
	stage="apk";request.timeout=300;request.body_size_limit=int(build.size_bytes)
	request.download_file=download_path;progress=0
	_set_status("downloading","Update wird heruntergeladen …")
	if request.request(candidate.apk,["User-Agent: SkiZones/"+installed_version])!=OK:_failure()
func install() -> void:
	if state not in ["ready","permission"] or bridge==null:return
	# Recheck immediately before handing Android a read-only content URI.
	var status: String=bridge.validate(activity,download_path,build.sha256,int(build.size_bytes),int(build.version_code))
	if status!="ok":
		_set_status("error","Das Update passt nicht zu dieser Installation. Deine Spielstände bleiben erhalten. Installiere die App nicht neu.");return
	if game.has_game:
		var saved: bool=game.save_game()
		if not saved:
			_set_status("error","Dein Resort konnte nicht gespeichert werden. Die Installation wurde angehalten.");return
		game.app_session.save(game)
	var action: String=bridge.install(activity,download_path)
	if action=="permission":_set_status("permission","Erlaube Android einmalig, Updates aus SkiZones zu installieren. Kehre danach zurück und tippe erneut auf Installieren.")
	elif action=="installer":_set_status("ready","Bestätige das Update im Android-Installationsfenster. Dein Fortschritt bleibt erhalten.")
	else:_set_status("error","Android konnte die Installation nicht öffnen. Du kannst sie später erneut starten.")
func _process(_delta: float) -> void:
	if state!="downloading" or build.is_empty():return
	var value:=clampi(int(100.0*request.get_downloaded_bytes()/maxi(1,int(build.size_bytes))),0,99)
	if value!=progress:progress=value;changed.emit()
