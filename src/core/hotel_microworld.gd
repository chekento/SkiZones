extends RefCounted
## Five linked, hotel-specific encounters. A scenario is staff training,
## not an artificial booking: real room occupancy and accounting stay with
## Hospitality, while the existing bounded daily activity bonus is retained.
const Hospitality = preload("res://src/core/hospitality.gd")

const GUESTS := [
	{"name":"Familie Fuchs","intro":"Zwei Erwachsene und ihre Kinder kommen mit roten Wangen vom Skibus.","wish":"Sie möchten zusammenbleiben, warm ankommen und morgens früh auf die Piste."},
	{"name":"Mila & Freunde","intro":"Eine kleine Gruppe bringt Snowboards und viel Vorfreude in die Lobby.","wish":"Sie lieben unkomplizierten Service und einen frühen Start in den Snowpark."},
	{"name":"Herr Bergmann","intro":"Ein müder Winterwanderer schüttelt den Schnee von seiner Jacke.","wish":"Er wünscht sich ein ruhiges Zimmer und Hilfe mit seinem Gepäck."},
	{"name":"Die Schneekinder","intro":"Eine fröhliche Familie kommt mit Schlitten und einem riesigen Teddy.","wish":"Die Kinder freuen sich auf Kakao, die Eltern auf einen entspannten Urlaub."}
]
const TITLES := ["Ankunft im Schnee","Ein Zuhause auf Zeit","Frühstück im Berglicht","Eine kleine Überraschung","Bis zum nächsten Winter"]
const SCENES := ["arrival","room","breakfast","service","farewell"]

static func challenge(model: RefCounted, building: Dictionary, session: Dictionary) -> Dictionary:
	var step := clampi(int(session.get("step",0)),0,4)
	var guest: Dictionary = GUESTS[posmod(int(building.id)*11+int(session.get("day",model.day))*3, GUESTS.size())]
	var config := Hospitality.config(building)
	var rooms := Hospitality.dashboard(model,building)
	var result := {
		"mode":"hotel_story","scene":SCENES[step],"step":step,
		"title":TITLES[step],"guest":guest.name,"intro":guest.intro,
		"wish":guest.wish,"target":0.0,"choices":[],"answer":0,"partial":-1,
		"prompt":"","reaction":""
	}
	match step:
		0:
			if int(rooms.occupied) >= int(rooms.capacity):
				result.prompt = "Dein Haus ist ausgebucht. Wie empfängst du die Gäste?"
				result.choices = ["Trotzdem ein belegtes Zimmer zuweisen","Belegung erklären und ein freies Haus der Hotelkette prüfen","Gäste ohne Erklärung wegschicken"]
				result.answer = 1
			else:
				result.prompt = "Die Gäste betreten deine Lobby. Was ist der beste Empfang?"
				result.choices = ["Freies passendes Zimmer prüfen, persönlich begrüßen","Ohne Zimmerprüfung einen Schlüssel aushändigen","Bis morgen vertrösten"]
				result.answer = 0
		1:
			if float(config.cleanliness) < 75.0:
				result.prompt = "Das gewünschte Zimmer ist noch nicht richtig sauber."
				result.choices = ["Trotzdem sofort belegen","Reinigung durchführen und das Zimmer erst danach freigeben","Den Gästen ein schlechtes Zimmer ohne Hinweis berechnen"]
				result.answer = 1
			else:
				result.prompt = "Das Zimmer ist vorbereitet. Was verbessert den Einzug?"
				result.choices = ["Heizung und Ausstattung prüfen, Gepäckservice anbieten","Die Zimmertür verschlossen lassen","Ohne Begrüßung die Gäste allein suchen lassen"]
				result.answer = 0
		2:
			if bool(config.breakfast):
				result.prompt = "Ein neuer Skitag beginnt. Die Gäste wollen frühstücken."
				result.choices = ["Rechtzeitig Buffet, warme Getränke und Plätze vorbereiten","Das Frühstück erst nach Liftschluss anbieten","Ohne Vorbereitung die Rechnung erhöhen"]
				result.answer = 0
			else:
				result.prompt = "Dein Haus bietet aktuell kein eigenes Frühstück an."
				result.choices = ["Ein nicht vorhandenes Buffet versprechen","Die Gäste ungefragt zur Skipiste schicken","Ehrlich informieren und geeignete erreichbare Alternativen nennen"]
				result.answer = 2
		3:
			result.prompt = "Im Zimmer wird es kalt. Die Gäste melden ein Problem."
			result.choices = ["Beschwerde ignorieren","Problem prüfen, Reparatur organisieren und Zwischenlösung anbieten","Nur den Zimmerpreis erhöhen"]
			result.answer = 1
		4:
			result.prompt = "Der Urlaub geht zu Ende. Wie sorgst du für Wiederkehr?"
			result.choices = ["Freundlich verabschieden, Rückmeldung einholen und Wünsche notieren","Ohne Abrechnung die Tür schließen","Die Gäste zu einer positiven Bewertung zwingen"]
			result.answer = 0
	result.reaction = "Ein warmes Lächeln – deine Gäste fühlen sich willkommen."
	return result

static func score(task: Dictionary, choice: Variant) -> int:
	if not choice is int or choice < 0 or choice >= task.choices.size(): return 0
	if choice == int(task.answer): return 100
	return 30 if choice == int(task.get("partial",-1)) else 5

static func chapter_progress(building: Dictionary) -> Dictionary:
	var activity: Dictionary = building.get("activity",{})
	var xp: int = maxi(0,int(activity.get("hotel_story_xp",0)))
	return {"visits":maxi(0,int(activity.get("hotel_story_visits",0))),
		"xp":xp,"level":mini(20,1 + xp/300),"best":maxi(0,int(activity.get("hotel_story_best",0)))}
