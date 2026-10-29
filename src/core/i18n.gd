extends RefCounted
## German source messages with a complete English gettext catalog.
const Catalog = preload("res://src/core/catalog.gd")
static var installed := false
static var language := "de"
static var _launch_system_locale := OS.get_locale()
static var _launch_engine_locale := TranslationServer.get_locale()
class Literal extends RefCounted:
	var value: String
	func _init(message: String) -> void: value=message
	func _to_string() -> String: return value

static func verbatim(message: String) -> RefCounted:
	return Literal.new(message)

static func locale_for(system_locale: String) -> String:
	return "de" if system_locale.replace("-","_").to_lower().get_slice("_",0) == "de" else "en"

static func configure(preference: String = "system") -> void:
	_install()
	language=locale_for(system_locale() if preference == "system" else preference)
	TranslationServer.set_locale(language)

static func system_locale() -> String:
	var result := OS.get_locale()
	# Godot consumes --language before exposing script arguments. Capture its
	# initial locale before any in-game choice; Android follows the live system.
	if OS.get_name() != "Android" and locale_for(_launch_engine_locale) != locale_for(_launch_system_locale):
		result=_launch_engine_locale
	return result

static func _install() -> void:
	if not installed:
		language=locale_for(TranslationServer.get_locale())
		TranslationServer.add_translation(load("res://translations/en.po"))
		installed=true

static func text(message: String) -> String:
	_install()
	return str(TranslationServer.translate(message))

static func args(value: Variant) -> Variant:
	if value is String or value is StringName: return text(str(value))
	if value is Array: return value.map(func(item): return text(str(item)) if item is String or item is StringName else item)
	return value

static func format_message(message: String, arguments: Variant) -> String:
	return text(message) % args(arguments)

static func day_suffix(days: int) -> String:
	return "" if days == 1 else ("e" if language == "de" else "s")

static func asset_name(item: Dictionary) -> String:
	var title: String=item.get("name","")
	if item.get("custom_name",false): return title
	if item.has("difficulty"):
		var original: String=["Blaue Piste","Rote Piste","Schwarze Piste"][int(item.difficulty)]
		if title == "%s %d" % [original,int(item.number)]: return "%s %d" % [text(original),int(item.number)]
	if item.has("bottom") and Catalog.LIFTS.has(item.get("kind")):
		var original: String=Catalog.LIFTS[item.kind].name
		if title == "%s %d" % [original,int(item.id)]: return "%s %d" % [text(original),int(item.id)]
	if item.get("kind") == "walkway" and title == "Fußweg %d" % int(item.id): return format_message("Fußweg %d",int(item.id))
	return text(title)
