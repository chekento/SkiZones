extends RefCounted
const Motion = preload("res://src/core/ski_motion.gd")
const HOMES := ["Hamburg", "München", "Wien", "Salzburg", "Innsbruck", "Stuttgart", "Bremen", "Berlin", "Graz", "Köln"]
const MOTIVES := ["Den Winter genießen", "Neue Abfahrten entdecken", "Schöne Schwünge üben", "Aussicht und Hütteneinkehr", "Einen sportlichen Tag verbringen"]

static func describe(model: RefCounted, guest: Dictionary) -> Dictionary:
	var id: int = guest.id
	var personal := Motion.style(id, guest.ability)
	var energy := clampf(100 - guest.get("runs", 0) * 4.5 - guest.age * 0.045 + (15 if guest.spent else 0), 5, 100)
	var hunger := clampf(guest.age * 0.25 - (65 if guest.spent else 0), 0, 100)
	var warmth := clampf(85 + model.weather().temperature * 2 - guest.age * 0.055 + (20 if guest.spent else 0), 0, 100)
	var patience := 12 + (id * 13) % 25
	var mood := "content"
	var emotion := "Zufrieden"
	var emoji := "🙂"
	var reason := "Ein Wintertag in den Bergen – mal sehen, wohin die nächste Fahrt führt."
	var activity := "Auf dem Heimweg"
	var kind := ""
	if guest.phase != "leaving" and guest.leg < guest.route.legs.size():
		kind = guest.route.legs[guest.leg].kind
		activity = {"ski": "Auf der Piste", "walk": "Zu Fuß unterwegs", "lift": "Fährt bergauf", "visit": "Genießt eine Pause"}.get(kind, "Unterwegs")
	if guest.phase == "queue":
		activity = "Wartet auf den Lift"
	elif guest.get("heading_home", false):
		activity = "Auf dem Rückweg ins Tal"
	if guest.phase == "queue" and guest.wait > patience:
		mood = "impatient"; emotion = "Ungeduldig"; emoji = "😤"; reason = "Ich warte schon %d Minuten. Ein Lift mit mehr Kapazität wäre schön." % guest.wait
	elif warmth < 45:
		mood = "cold"; emotion = "Durchgefroren"; emoji = "🥶"; reason = "Zeit für einen warmen Ort und eine kleine Pause."
	elif hunger > 65:
		mood = "hungry"; emotion = "Hungrig"; emoji = "😋"; reason = "Nach den vielen Stunden draußen könnte ich eine Stärkung gebrauchen."
	elif energy < 35:
		mood = "tired"; emotion = "Müde Beine"; emoji = "😮‍💨"; reason = "Das war ein sportlicher Tag. Die nächste Runde darf gemütlicher werden."
	elif kind == "visit":
		mood = "cozy"; emotion = "Gut aufgehoben"; emoji = "😊"; reason = "Eine schöne Einkehr gehört für mich zum Skitag dazu."
	elif guest.get("runs", 0) >= 2:
		mood = "excited"; emotion = "Begeistert"; emoji = "🤩"; reason = "%d Abfahrten geschafft! Ich würde gern noch mehr vom Resort entdecken." % guest.runs
	elif kind == "ski":
		mood = "focused"; emotion = "Konzentriert"; emoji = "😎"; reason = "Ich suche meine eigene Linie und genieße die Schwünge."
	elif kind == "lift" and guest.phase == "moving":
		mood = "relaxed"; emotion = "Entspannt"; emoji = "😌"; reason = "Beine ausruhen, Aussicht genießen und langsam wieder hinauf."
	var score := clampf(78 + guest.get("runs", 0) * 2 - guest.total_wait * 0.17 - maxf(0, hunger - 60) * 0.2, 5, 100)
	return {"name": Motion.name_for(id), "years": 18 + (id * 17) % 58, "home": HOMES[(id * 7) % HOMES.size()], "motive": MOTIVES[(id * 11) % MOTIVES.size()], "mood": mood, "emotion": emotion, "emoji": emoji, "reason": reason, "activity": activity, "energy": energy, "hunger": hunger, "warmth": warmth, "score": score, "style": personal.name, "speed": personal.speed, "patience": patience, "spending": guest.get("spending", guest.get("ticket_paid", 0))}
