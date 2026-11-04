extends RefCounted
## Short optional shifts. The model evaluates actual input and caps daily rewards.
const L = preload("res://src/core/i18n.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
const HotelWorld = preload("res://src/core/hotel_microworld.gd")
const SectorCases = preload("res://src/core/sector_decisions.gd")
const ACTIVITIES := {
	"printing_press":{"title":"Druckerei-Schicht","mode":"orders","hint":"Bereite eine saubere Ausgabe für den Druck vor.","choices":["Papier","Druckplatte","Druckfarbe","Setzkasten"]},
	"newsstand":{"title":"Zeitungsstand","mode":"orders","hint":"Stelle die gewünschte Zeitung für den Gast bereit.","choices":["ExtraBlatt","Bergwetter","Pistenjournal","Dorfleben"]},
	"fitness":{"title":"Alpines Fitnessstudio","mode":"timing","hint":"Trainiere im gesunden Pulsbereich und betreue die Gäste.","choices":[]},
	"souvenir":{"title":"Souveniratelier","mode":"orders","hint":"Finde das passende Urlaubsandenken für deinen Gast.","choices":["Holzfigur","Kuhglocke","Postkarte","Schneekugel"]},
	"watchmaker":{"title":"Uhrmacherwerkstatt","mode":"orders","hint":"Prüfe eine feine Uhr und wähle das passende Ersatzteil.","choices":["Zeiger","Feder","Krone","Uhrglas"]},
	"craftshop":{"title":"Handwerksstube","mode":"orders","hint":"Stelle das bestellte traditionelle Andenken her.","choices":["Holzlöffel","Schnitzfigur","Alpenglocke","Bergmotiv"]},
	"pizzeria":{"title":"Pizza-Werkstatt", "mode":"orders", "hint":"Belege die bestellte Pizza mit genau den Zutaten deiner eigenen Karte.", "choices":["Tomate", "Käse", "Pilze", "Paprika"]},
	"school":{"title":"Slalom-Skischule", "mode":"slalom", "hint":"Fahre durch das markierte Tor. Fünf Schwünge ergeben eine Unterrichtsrunde.", "choices":["Links", "Mitte", "Rechts"]},
	"restaurant":{"title":"Restaurant-Service", "mode":"orders", "hint":"Merke dir die Bestellung und serviere das passende Gericht.", "choices":["Suppe", "Knödel", "Pasta", "Salat"]},
	"bar":{"title":"Bar-Schicht", "mode":"timing", "hint":"Stoppe den Ausschank im grünen Bereich. Fünf Getränke ergeben eine Schicht.", "choices":[]},
	"disco":{"title":"Après-Ski-Bar", "mode":"timing", "hint":"Triff den grünen Bereich und schenke die richtige Menge aus.", "choices":[]},
	"kiosk":{"title":"Snack-Bestellungen", "mode":"orders", "hint":"Stelle die richtige Snackbestellung für deinen Gast zusammen.", "choices":["Brezel", "Toast", "Punsch", "Apfelsaft"]},
	"schmarrn":{"title":"Kaiserschmarrn-Pfanne", "mode":"timing", "hint":"Wende den Teig im grünen Bereich, damit der Kaiserschmarrn goldbraun wird.", "choices":[]},
	"cocoa":{"title":"Kakao-Atelier", "mode":"orders", "hint":"Erfülle den Kakaowunsch deines Gastes.", "choices":["Sahne", "Zimt", "Marshmallows", "Vanille"]},
	"rental":{"title":"Ausrüstungs-Service", "mode":"orders", "hint":"Gib die gewünschte Wintersportausrüstung aus.", "choices":["Ski", "Snowboard", "Helm", "Schuhe"]},
	"repair_office":{"title":"Werkstatt-Prüfstand", "mode":"orders", "hint":"Wähle das angeforderte Ersatzteil am Prüfstand.", "choices":["Seilrolle", "Sensor", "Sicherung", "Lager"]},
	"maintenance":{"title":"Pistenraupen-Training", "mode":"slalom", "hint":"Lenke die Pistenraupe durch die markierten Schneefelder.", "choices":["Links", "Mitte", "Rechts"]},
	"snowmaker":{"title":"Schnee-Labor", "mode":"timing", "hint":"Stelle die Düse im grünen Bereich ein und erzeuge feinen Schnee.", "choices":[]},
	"bus":{"title":"Shuttle-Disposition", "mode":"orders", "hint":"Ordne den Hotel- und Stationswünschen die richtige Abfahrt zu.", "choices":["Talstation", "Hotel", "Skischule", "Dorfplatz"]},
	"first_aid":{"title":"Bergwacht-Logistik", "mode":"orders", "hint":"Packe das angeforderte Material in den Einsatzrucksack.", "choices":["Decke", "Funkgerät", "Trage", "Wärmepack"]},
	"snowpark":{"title":"Snowpark-Linie", "mode":"slalom", "hint":"Wähle die markierte Linie durch den Snowpark.", "choices":["Links", "Mitte", "Rechts"]},
	"pool":{"title":"Pool-Service", "mode":"timing", "hint":"Regle den Wasserkomfort im grünen Bereich.", "choices":[]},
	"spa":{"title":"Wellness-Rhythmus", "mode":"timing", "hint":"Triff den ruhigen grünen Bereich für eine perfekte Wellnessrunde.", "choices":[]},
	"lodge":{"title":"Hütten-Service", "mode":"orders", "hint":"Reiche deinen Gästen die richtige Hüttenbestellung.", "choices":["Tee", "Suppe", "Decke", "Kuchen"]},
	"shelter":{"title":"Wärmepause", "mode":"orders", "hint":"Versorge die wartenden Gäste mit dem gewünschten Komfort.", "choices":["Decke", "Tee", "Sitzkissen", "Handwärmer"]},
	"viewpoint":{"title":"Panorama-Fotos", "mode":"timing", "hint":"Löse die Kamera im grünen Bereich aus und fange das Bergpanorama ein.", "choices":[]}
}

static func spec(kind: String) -> Dictionary:
	if Hospitality.lodging(kind): return {"title":"Rezeption & Zimmerservice", "mode":"orders", "hint":"Erfülle die Wünsche deiner Übernachtungsgäste.", "choices":["Check-in", "Frühstück", "Handtücher", "Gepäck"]}
	return ACTIVITIES.get(kind, {})

static func start(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if not Catalog.BUILDINGS.has(building.get("kind", "")) or spec(str(building.kind)).is_empty() or not building.enabled: return {"ok":false, "message":L.text("Zuerst das Gebäude errichten und öffnen.")}
	return {"ok":true, "id":id, "day":model.day, "step":0, "score":0, "answers":[], "finished":false}

static func challenge(model: RefCounted, session: Dictionary) -> Dictionary:
	var building: Dictionary = model.asset(int(session.get("id", -1)))
	if building.is_empty() or int(session.get("step", 5)) >= 5: return {}
	var definition := spec(str(building.kind))
	var seed_value: int = int(building.id) * 31 + int(session.day) * 17 + int(session.step) * 13
	var choices: Array = definition.choices.duplicate()
	if Hospitality.lodging(str(building.kind)):
		return HotelWorld.challenge(model,building,session)
	if building.kind == "pizzeria":
		var pizza: Dictionary = Hospitality.menu(building)[posmod(seed_value, 3)]
		return {"mode":"pizza", "prompt":pizza.name, "toppings":pizza.toppings, "target":0.0, "choices":Hospitality.TOPPINGS.keys()}
	var operational_case: Dictionary = SectorCases.challenge(model,building,session)
	if not operational_case.is_empty():
		return operational_case
	var target: float = 0.30 + posmod(seed_value, 40) / 100.0
	return {"mode":definition.mode, "prompt":L.text(choices[posmod(seed_value, choices.size())]) if not choices.is_empty() else L.text("Im grünen Bereich stoppen"), "target":target, "answer":posmod(seed_value, maxi(1, choices.size())), "choices":choices}

static func answer(model: RefCounted, session: Dictionary, input: Variant) -> Dictionary:
	if not session.get("ok", false) or session.get("finished", false): return {"ok":false}
	var task := challenge(model, session)
	if task.is_empty(): return {"ok":false}
	var score := 0
	if task.mode == "hotel_story":
		score = HotelWorld.score(task,input)
	elif task.mode == "decision":
		if input is int and input >= 0 and input < task.choices.size():
			score = 100 if input == int(task.answer) else 20
	elif task.mode == "timing":
		if input is float or input is int:
			if is_finite(float(input)): score = roundi(clampf(1.0 - absf(float(input) - float(task.target)) / 0.22, 0, 1) * 100)
	elif task.mode == "pizza":
		if input is Array:
			var submitted := {}
			for topping in input:
				if topping is String and Hospitality.TOPPINGS.has(topping): submitted[topping] = true
			var required: Array = task.toppings
			var correct := 0
			for topping in submitted:
				correct += 1 if required.has(topping) else -1
			score = roundi(clampf(float(correct) / required.size(), 0, 1) * 100)
	elif input is int and input == int(task.answer): score = 100
	session.score = int(session.score) + score
	session.answers.append(score)
	session.step = int(session.step) + 1
	if int(session.step) < 5: return {"ok":true, "score":score, "finished":false}
	session.finished = true
	var building: Dictionary = model.asset(int(session.id))
	if building.is_empty() or not building.enabled: return {"ok":false, "finished":true, "message":L.text("Das Gebäude ist nicht mehr verfügbar.")}
	var previous: Dictionary = building.get("activity", {})
	var state := {"day":model.day, "plays":0, "best":0, "bonus":0, "rounds":int(previous.get("rounds", 0))}
	if int(previous.get("day", 0)) == model.day: state.merge(previous, true)
	var average := roundi(float(session.score) / 5.0)
	var reward := 0
	if int(state.plays) < 3 and int(session.day) == int(model.day):
		state.plays = int(state.plays) + 1
		state.best = maxi(int(state.best), average)
		state.bonus = roundi(int(state.best) * 0.2)
		reward = roundi(average * 2.5)
		model.money += reward
		model.report.rewards += reward
		model.campaign.xp += average * 0.5
	state.rounds = int(state.rounds) + 1
	# Five practical scenarios build lasting sector expertise. Service businesses
	# use this proficiency in Hospitality.service_multiplier for real guest income.
	if not SectorCases.group(str(building.kind)).is_empty():
		state["sector"] = SectorCases.group(str(building.kind))
		state["training_xp"] = mini(10000, int(previous.get("training_xp", 0)) + maxi(0, roundi(average / 4.0)))
		state["training_level"] = mini(20, int(int(state["training_xp"]) / 100))
		state["last_shift_quality"] = average
	if Hospitality.lodging(str(building.kind)):
		# Long-term narrative progression is earned even by unpaid practice;
		# cash and service bonuses still obey the existing three-round cap.
		state["hotel_story_xp"] = mini(6000,int(previous.get("hotel_story_xp",0)) + average)
		state["hotel_story_visits"] = mini(1000000,int(previous.get("hotel_story_visits",0)) + 1)
		state["hotel_story_best"] = maxi(int(previous.get("hotel_story_best",0)),average)
	building.activity = state
	return {"ok":true, "finished":true, "score":average, "reward":reward, "bonus":state.bonus, "message":L.text("Schicht beendet · %d Punkte · %d € Prämie · +%d %% Service heute") % [average, reward, int(state.bonus)]}

