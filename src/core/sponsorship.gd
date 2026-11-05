extends RefCounted
## Optional, player-chosen sponsorship. No real brands and no pay-to-win IAP.
## One seven-day contract at a time; income is booked at most once per day.
const L = preload("res://src/core/i18n.gd")
const CONTRACT_DAYS := 7
const OFFERS := {
	"winter_cocoa": {"name":"Winterkakao-Partner", "rep":0, "lifts":1, "daily":650,
		"detail":"Kleiner regionaler Partner. Stabiler Einstieg für dein junges Resort."},
	"alpine_craft": {"name":"Alpenhandwerk", "rep":52, "lifts":1, "daily":1200,
		"detail":"Ein gemütlicher Sponsor für liebevoll ausgebaute Berghütten."},
	"snow_trails": {"name":"Schneespuren-Club", "rep":63, "lifts":2, "daily":2300,
		"detail":"Belohnt ein vielfältiges Netz aus Liften und Pisten."},
	"peak_motion": {"name":"Gipfelbewegung", "rep":74, "lifts":3, "daily":3400,
		"detail":"Höhere Einnahmen für ein zuverlässig erreichbares Bergresort."},
	"aurora_days": {"name":"Aurora-Wintertage", "rep":85, "lifts":4, "daily":4900,
		"detail":"Prestigepartner für etablierte Resorts mit gutem Gästeruf."},
	"frostfunke": {"name":"Frostfunke · Bergbrause", "rep":42, "lifts":1, "daily":720, "business":"kiosk", "symbol":"✦", "mark_color":"52b8ed",
		"detail":"Eine erfundene Alpenlimonaden-Marke. Unterstützt einen echten Punschstand mit Getränkesortiment."},
	"bergperle": {"name":"Bergperle · Quellwasser", "rep":47, "lifts":1, "daily":850, "business":"restaurant", "symbol":"◈", "mark_color":"5ec8ba",
		"detail":"Fiktive Quellwasser-Partnerschaft für ein geöffnetes Resortrestaurant."},
	"kakaokomet": {"name":"KakaoKomet · Winterdrink", "rep":40, "lifts":1, "daily":610, "business":"cocoa", "symbol":"✺", "mark_color":"e8aa71",
		"detail":"Fiktive Kakaomarke mit warmen Getränken am Kakaoladen."},
	"gipfeltee": {"name":"Gipfeltee · Kräuterquelle", "rep":55, "lifts":2, "daily":1120, "business":"spa", "symbol":"❋", "mark_color":"9dc792",
		"detail":"Fiktive Tee-Partnerschaft für ein echtes Alpen-Spa mit Personal."},
	"pistenperle": {"name":"Pistenperle · Schneebar", "rep":62, "lifts":2, "daily":1580, "business":"bar", "symbol":"★", "mark_color":"ce9ed7",
		"detail":"Fiktive alkoholfreie Après-Ski-Marke. Benötigt eine aktive Alpenbar."}
}

static func active(state: Dictionary, day: int) -> bool:
	var sponsor: Dictionary = state.get("sponsor",{})
	return not sponsor.is_empty() and day <= int(sponsor.get("end",0))

static func check(model: RefCounted, id: String) -> Dictionary:
	if not OFFERS.has(id): return {"ok":false,"message":L.text("Sponsorangebot nicht gefunden.")}
	if active(model.campaign,model.day):
		return {"ok":false,"message":L.text("Ein Sponsorvertrag läuft bereits.")}
	var spec: Dictionary = OFFERS[id]
	if model.reputation < float(spec.rep):
		return {"ok":false,"message":L.text("Mindestens %d %% Ruf erforderlich.") % L.args(spec.rep)}
	if model.lifts.size() < int(spec.lifts):
		return {"ok":false,"message":L.text("Mindestens %d Lifte erforderlich.") % L.args(spec.lifts)}
	if spec.has("business") and not model.buildings.any(func(building): return str(building.kind) == str(spec.business) and bool(building.enabled)):
		return {"ok":false,"message":L.text("Erforderlicher Getränkebetrieb noch nicht gebaut oder geschlossen.")}
	return {"ok":true,"message":L.text("Vertrag kann abgeschlossen werden.")}

static func sign(model: RefCounted, id: String) -> Dictionary:
	var result: Dictionary = check(model,id)
	if not result.ok: return result
	model.campaign.sponsor = {"id":id, "start":model.day, "end":model.day+CONTRACT_DAYS-1,
		"last_paid":0, "earned":0.0}
	return {"ok":true,"message":L.text("Sponsorvertrag abgeschlossen: %s · %d Betriebstage.") % L.args([L.text(OFFERS[id].name),CONTRACT_DAYS])}

static func daily_reward(model: RefCounted) -> float:
	var sponsor: Dictionary = model.campaign.get("sponsor",{})
	if sponsor.is_empty() or not active(model.campaign,model.day): return 0.0
	if int(sponsor.get("last_paid",0)) >= model.day: return 0.0
	# A sponsor only pays for a resort that offers an actual running lift.
	if not model.lifts.any(func(lift): return bool(lift.enabled)): return 0.0
	var spec: Dictionary = OFFERS.get(str(sponsor.id),{})
	if spec.is_empty(): return 0.0
	# Only existing staffed retail venues can fund the new drink partnerships.
	# The original five sponsors keep their previous contract semantics.
	if spec.has("business") and not model.buildings.any(func(building): return str(building.kind) == str(spec.business) and bool(building.enabled) and model.Ops.building_open(model, building)):
		return 0.0
	var revenue: float = roundf(float(spec.daily)*(0.75+model.reputation/200.0))
	sponsor.last_paid = model.day
	sponsor.earned += revenue
	model.money += revenue
	model.report.rewards += revenue
	model.report["sponsor"] = float(model.report.get("sponsor",0.0))+revenue
	return revenue

static func valid(data: Variant, day: int) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if not OFFERS.has(data.get("id","")): return false
	for field in ["start","end","last_paid"]:
		if not data.has(field) or not (data[field] is int or data[field] is float) or data[field] != floorf(float(data[field])):
			return false
	if int(data.start) < 1 or int(data.end) != int(data.start)+CONTRACT_DAYS-1 or int(data.start) > day:
		return false
	if int(data.last_paid) < 0 or int(data.last_paid) > mini(day,int(data.end)):
		return false
	if not (data.get("earned") is float or data.get("earned") is int) or float(data.earned) < 0.0 or float(data.earned) > 10000000.0: return false
	return true
