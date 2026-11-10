extends RefCounted
## 0.41: one discovery per UNIQUE PMDD holiday picture, not per billboard.
## Progress persists in the existing career campaign without changing the
## save schema or creating new JSON files. Legacy careers default to 0/10.
const Posters = preload("res://src/core/holiday_poster_catalog.gd")
const Book = preload("res://src/core/achievement_book.gd")
const L = preload("res://src/core/i18n.gd")

static func total() -> int:
	return Posters.all_paths().size()

static func valid(value: Variant) -> bool:
	if not value is Array or value.size()>total():return false
	var seen: Dictionary={}
	for art in value:
		if not art is String or art not in Posters.all_paths() or seen.has(art):return false
		seen[art]=true
	return true

static func discovered(model: RefCounted) -> Array:
	var found: Variant=model.campaign.get("poster_discoveries",[])
	return found.duplicate() if valid(found) else []

static func progress(model: RefCounted) -> Dictionary:
	var count: int=discovered(model).size()
	return {"found":count,"total":total(),"complete":count==total()}

## Caller must pass the exact artwork from the selected in-world board.
## Returning events does not display them; the HUD handles presentation.
static func discover(model: RefCounted, art: String) -> Dictionary:
	var old: Array=discovered(model)
	var result: Dictionary={"new":false,"found":old.size(),"total":total(),"complete":old.size()==total(),"awarded":false,"events":[]}
	if art not in Posters.all_paths() or old.has(art):return result
	old.append(art)
	model.campaign["poster_discoveries"]=old
	result.new=true
	result.found=old.size()
	result.complete=old.size()==total()
	result.events.append({"kind":"poster","title":L.text("Winterplakat entdeckt"),"detail":L.text("%d von %d Motiven entdeckt") % L.args([old.size(),total()])})
	if result.complete and not model.achievements.has(Book.POSTER_COLLECTOR_ID):
		model.achievements.append(Book.POSTER_COLLECTOR_ID)
		result.awarded=true
		var award: Dictionary=Book.entry(Book.POSTER_COLLECTOR_ID)
		result.events.append({"kind":"achievement","title":award.name,"detail":award.goal,"reward":0})
	return result
