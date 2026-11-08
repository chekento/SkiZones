extends RefCounted
## Versioned, checksum-protected custom-map registry. Each player-created
## terrain owns a stable map ID; existing saves retain their old geometry.
const Creator=preload("res://src/core/map_creator_040.gd")
const Maps=preload("res://src/core/maps.gd")
const PATH:="user://skizones_custom_maps_040.json"
const MAX_MAPS:=8

static func _validated_map_table(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.size()>MAX_MAPS:return {}
	var table:Dictionary={}
	for id in raw:
		if not id is String or not raw[id] is Dictionary:return {}
		var known:=false
		for slot in range(1,MAX_MAPS+1):
			if id==Maps.custom_id(slot):known=true;break
		if not known:return {}
		var checked:Dictionary=Creator.validate(raw[id])
		if not checked.ok:return {}
		table[id]=checked.settings
	return table

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {"ok":false,"maps":{}}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>64000:return {"ok":false,"maps":{}}
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary:return {"ok":false,"maps":{}}
	var envelope:Dictionary=parser.data
	if envelope.get("schema")!=1 or not envelope.get("payload") is String:return {"ok":false,"maps":{}}
	if envelope.payload.length()>48000 or envelope.get("sha256")!=str(envelope.payload).sha256_text():return {"ok":false,"maps":{}}
	if parser.parse(envelope.payload)!=OK or not parser.data is Dictionary:return {"ok":false,"maps":{}}
	var source:Dictionary=parser.data
	if source.has("maps") and source.maps is Dictionary:
		var validated:Dictionary=_validated_map_table(source.maps)
		if validated.size()==source.maps.size():return {"ok":true,"maps":validated}
	return {"ok":false,"maps":{}}

static func read_registry() -> Dictionary:
	for candidate in [PATH,PATH+".bak"]:
		var read:Dictionary=_read(candidate)
		if read.ok:return read
	return {"ok":not FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH+".bak"),"maps":{}}

static func install() -> bool:
	var library:Dictionary=read_registry()
	if not library.ok:return false
	for id in library.maps:
		if not Maps.register_custom(str(id),library.maps[id]):return false
	return true

static func entries() -> Array:
	var library:Dictionary=read_registry()
	if not library.ok:return []
	var result:Array=[]
	for slot in range(1,MAX_MAPS+1):
		var id:=Maps.custom_id(slot)
		if library.maps.has(id):
			var options:Dictionary=library.maps[id]
			result.append({"id":id,"name":options.name,"size":options.size,"landform":options.landform,"seed":options.seed})
	return result

static func _write(maps: Dictionary) -> bool:
	var checked:Dictionary=_validated_map_table(maps)
	if checked.size()!=maps.size():return false
	var payload:=JSON.stringify({"maps":checked})
	var envelope:=JSON.stringify({"schema":1,"payload":payload,"sha256":payload.sha256_text()})
	var temp:=PATH+".tmp"
	var file:=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if FileAccess.file_exists(PATH) and _read(PATH).ok:
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH),ProjectSettings.globalize_path(PATH+".bak"))!=OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(PATH))!=OK:
		return false
	return true

## No overwrite/delete yet: a map is permanent while its game saves exist.
## Players can create eight distinct custom landscapes and resume each later.
static func create(options: Dictionary) -> Dictionary:
	var checked:Dictionary=Creator.validate(options)
	if not checked.ok:return checked
	var stored:Dictionary=read_registry()
	if not stored.ok:return {"ok":false,"error":"Damaged map library; original preserved"}
	var maps:Dictionary=stored.maps.duplicate(true)
	var selected:=""
	for slot in range(1,MAX_MAPS+1):
		var id:=Maps.custom_id(slot)
		if not maps.has(id):selected=id;break
	if selected=="":return {"ok":false,"error":"All eight custom map slots are occupied"}
	maps[selected]=checked.settings
	if not _write(maps):return {"ok":false,"error":"Could not save custom map library"}
	if not Maps.register_custom(selected,checked.settings):
		return {"ok":false,"error":"Could not register custom terrain"}
	return {"ok":true,"id":selected}
