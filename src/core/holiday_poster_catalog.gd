extends RefCounted
## Ten user-approved PMDD 4.0 holiday background pictures, with NO baked-in
## wording. All advertising text is rendered as translated Godot overlays.
## The images are delivered as a separate compact WEBP asset bundle.
const L=preload("res://src/core/i18n.gd")

const CHRISTMAS=[
	"res://assets/seasonal/christmas_poster_original.webp",
	"res://assets/seasonal/christmas_poster_alt_01.webp",
	"res://assets/seasonal/christmas_poster_alt_02.webp",
	"res://assets/seasonal/christmas_poster_alt_03.webp",
	"res://assets/seasonal/christmas_poster_alt_04.webp",
	"res://assets/seasonal/christmas_poster_alt_05.webp",
	"res://assets/seasonal/christmas_poster_alt_06.webp"
]
const ADVENT=[
	"res://assets/seasonal/advent_poster_original.webp",
	"res://assets/seasonal/advent_poster_alt_01.webp"
]
const NEW_YEAR=["res://assets/seasonal/new_year_poster_original.webp"]

static func all_paths() -> Array:
	return CHRISTMAS+ADVENT+NEW_YEAR

static func pool(stage: String) -> Array:
	match stage:
		"november_poster", "advent": return CHRISTMAS+ADVENT
		"christmas":return CHRISTMAS.duplicate()
		"new_year_eve", "new_year":return NEW_YEAR.duplicate()
	return []

static func available(stage: String) -> Array:
	var result: Array=[]
	for path in pool(stage):
		if ResourceLoader.exists(path):result.append(path)
	return result

static func is_advent(path: String) -> bool:
	return path in ADVENT

static func headline(stage: String, art_path: String = "") -> String:
	if stage=="november_poster":
		return L.text("ADVENTSKALENDER · AB 1. DEZEMBER") if is_advent(art_path) else L.text("WEIHNACHTSZAUBER · AB 1. DEZEMBER")
	if stage=="advent":
		return L.text("24 TÜRCHEN · JEDEN TAG NEU") if is_advent(art_path) else L.text("FROHE ADVENTSZEIT")
	if stage=="christmas":return L.text("FROHE WEIHNACHTEN")
	if stage=="new_year_eve":return L.text("SILVESTER AM BERG")
	if stage=="new_year":return L.text("FROHES NEUES JAHR")
	return ""

static func campaign_active(stage: String) -> bool:
	return stage in ["november_poster","advent","christmas","new_year_eve","new_year"]
