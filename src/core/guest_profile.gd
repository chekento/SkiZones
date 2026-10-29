extends RefCounted
const L = preload("res://src/core/i18n.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const HOMES := ["Hamburg", "München", "Wien", "Salzburg", "Innsbruck", "Stuttgart", "Bremen", "Berlin", "Graz", "Köln"]
const MOTIVES := ["Den Winter genießen", "Neue Abfahrten entdecken", "Schöne Schwünge üben", "Aussicht und Hütteneinkehr", "Einen sportlichen Tag verbringen"]

static func describe(model: RefCounted, guest: Dictionary) -> Dictionary:
	var id: int = guest.id
	var sport: String = guest.get("sport", "ski")
	var personal := Motion.style(id, guest.ability, sport)
	var needs := Needs.values(guest,model.weather().temperature)
	var energy: float=needs.energy
	var hunger: float=needs.hunger
	var warmth: float=needs.warmth
	var patience := 12 + (id * 13) % 25
	var mood := "content"
	var emotion := L.text("Zufrieden")
	var emoji := "🙂"
	var reason := L.text("Ein Wintertag in den Bergen – mal sehen, wohin die nächste Fahrt führt.")
	var activity := L.text("Auf dem Heimweg")
	var kind := ""
	var climbing := false
	if guest.phase != "leaving" and guest.leg < guest.route.legs.size():
		kind = guest.route.legs[guest.leg].kind
		activity = {"ski": L.text("Auf der Piste"), "walk": L.text("Zu Fuß unterwegs"), "lift": L.text("Fährt bergauf"), "visit": L.text("Genießt eine Pause")}.get(kind, L.text("Unterwegs"))
		if kind=="visit": activity=L.text("Besucht %s") % L.args(model.asset(guest.route.legs[guest.leg].id).get("name",L.text("ein Gebäude")))
	if kind == "ski" and Motion.hiking(guest.get("ski_motion",guest.route.legs[guest.leg].get("motion",[])),guest.elapsed/guest.duration):
		activity = L.text("Stapft den Gegenanstieg hinauf")
		climbing = true
	if guest.phase == "queue":
		activity = L.text("Wartet auf den Lift")
	elif guest.get("heading_home", false):
		activity = L.text("Auf dem Rückweg ins Tal")
	if guest.phase == "queue" and guest.wait > patience:
		mood = "impatient"; emotion = L.text("Ungeduldig"); emoji = "😤"; reason = L.text("Ich warte schon %d Minuten. Ein Lift mit mehr Kapazität wäre schön.") % L.args(guest.wait)
	elif warmth < 45:
		mood = "cold"; emotion = L.text("Durchgefroren"); emoji = "🥶"; reason = L.text("Zeit für einen warmen Ort und eine kleine Pause.")
	elif hunger > 65:
		mood = "hungry"; emotion = L.text("Hungrig"); emoji = "😋"; reason = L.text("Nach den vielen Stunden draußen könnte ich eine Stärkung gebrauchen.")
	elif energy < 35:
		mood = "tired"; emotion = L.text("Müde Beine"); emoji = "😮‍💨"; reason = L.text("Das war ein sportlicher Tag. Die nächste Runde darf gemütlicher werden.")
	elif kind == "visit":
		mood = "cozy"; emotion = L.text("Gut aufgehoben"); emoji = "😊"; reason = L.text("Eine schöne Einkehr gehört für mich zum Skitag dazu.")
	elif guest.get("runs", 0) >= 2:
		mood = "excited"; emotion = L.text("Begeistert"); emoji = "🤩"; reason = L.text("%d Abfahrten geschafft! Ich würde gern noch mehr vom Resort entdecken.") % L.args(guest.runs)
	elif kind == "ski" and climbing:
		mood = "focused"; emotion = L.text("Schritt für Schritt"); emoji = "🙂"; reason = L.text("Hier reicht mein Schwung nicht. Ich stapfe das Stück hinauf; danach geht es wieder bergab.")
	elif kind == "ski":
		mood = "focused"; emotion = L.text("Konzentriert"); emoji = "😎"; reason = L.text("Ich suche meine eigene Linie und genieße die Schwünge.")
	elif kind == "lift" and guest.phase == "moving":
		mood = "relaxed"; emotion = L.text("Entspannt"); emoji = "😌"; reason = L.text("Beine ausruhen, Aussicht genießen und langsam wieder hinauf.")
	var score := clampf(78 + guest.get("runs", 0) * 2 - guest.total_wait * 0.17 - maxf(0, hunger - 60) * 0.2, 5, 100)
	return {"name": Motion.name_for(id), "years": 18 + (id * 17) % 58, "home": HOMES[(id * 7) % HOMES.size()], "motive": MOTIVES[(id * 11) % MOTIVES.size()], "mood": mood, "emotion": emotion, "emoji": emoji, "reason": reason, "activity": activity, "energy": energy, "hunger": hunger, "warmth": warmth, "score": score, "sport": sport, "equipment": Motion.SPORT_NAMES[sport], "style": personal.name, "speed": personal.speed, "patience": patience, "spending": guest.get("spending", guest.get("ticket_paid", 0))}
