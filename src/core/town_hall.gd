extends RefCounted
## Civic chronicle and two-month public improvement ledger.
## No network request, no saves mutation for reading the Town Hall.
## The archive lists verified prior published releases only.
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Catalog=preload("res://src/core/catalog.gd")
const HISTORY: Array = [
	{"version":"0.1.1","date":"27.10.2026","topic":"Android Preview","story":"Der Stadtschreiber öffnete erstmals das Tor zur Android-Bergwelt. Noch war SkiZones ein kleines Experiment, aber der Grundstein war gelegt."},
	{"version":"0.2.0","date":"27.10.2026","topic":"Alpen und Karriere","story":"Der Gemeinderat beschloss die ersten Karrieren. Alpenlandschaft, Wirtschaft und Bauverwaltung erhielten eine gemeinsame Spielordnung."},
	{"version":"0.3.0","date":"27.10.2026","topic":"Spuren im Schnee","story":"Auf den ersten Pisten tauchten Spuren im Schnee auf. Die Bürger erzählten erstmals vom gelebten Winterbetrieb."},
	{"version":"0.4.0","date":"27.10.2026","topic":"Dein Verlauf entscheidet","story":"Das Bauamt lernt, dass jeder gesetzte Streckenpunkt zählt: Der Verlauf sollte fortan tatsächlich den Weg bestimmen."},
	{"version":"0.5.0","date":"27.10.2026","topic":"Lifte und Stationsplätze","story":"Die Liftaufsicht bezog die Stationsplätze. Damit wurden Aufstieg, Kapazität und Zugang zu einer echten Planungsfrage."},
	{"version":"0.6.0","date":"27.10.2026","topic":"Bauen und Bergleben","story":"Neue Gebäude brachten Leben zwischen die Abfahrten; das Skigebiet wuchs zum bewohnten Bergdorf."},
	{"version":"0.7.0","date":"28.10.2026","topic":"Flüssiger Betrieb und dein eigener Resortstil","story":"Die Gemeinde konnte ihren eigenen Stil wählen, während die Betriebe flüssiger durch den Tag arbeiteten."},
	{"version":"0.8.0","date":"28.10.2026","topic":"Ein Skitag geht wirklich zu Ende","story":"Der erste vollständig geregelte Skitag endete. Von nun an gehörten Abend, Nacht und neuer Morgen zum Dorfkalender."},
	{"version":"0.9.0","date":"28.10.2026","topic":"Wege, Schwung und Gegenanstiege","story":"Neue Wege, Gegenanstiege und Skischwünge brachten mehr Bewegungsfreiheit in die Schneeordnung."},
	{"version":"0.10.0","date":"28.10.2026","topic":"Eine kleine Winterwelt und verlässlich weiterspielen","story":"Der Stadtrat stellte die Sicherung der Fortschritte in den Mittelpunkt: Lieber eine kleinere Welt als verlorene Karrieren."},
	{"version":"0.11.0","date":"29.10.2026","topic":"Besser planen, echte Bedürfnisse, Deutsch und Englisch","story":"Zweisprachige Schilder und echte Bedürfnisse öffneten die Gemeinde für neue Gäste und Spielweisen."},
	{"version":"0.12.0","date":"29.10.2026","topic":"Präzise klicken, Breite wählen, Kurven glätten","story":"Das Tiefbauamt erlaubte präzisere Fingerpositionen, Pistenbreiten und weichere Kurven."},
	{"version":"0.13.0","date":"29.10.2026","topic":"Alpine Villages & Eight Resorts","story":"Acht Fantasieorte und alpine Promenaden wurden verbunden. Die Bergregion bekam erstmals ein größeres Ortsbild."},
	{"version":"0.14.0","date":"30.10.2026","topic":"Real Resorts & 24h Operations","story":"Die ersten vier realen Resort-Szenarien und ganztägige Betriebe wurden zum Gegenstand unserer Stadtplanung."},
	{"version":"0.14.1","date":"30.10.2026","topic":"Real Resorts & 24h Operations","story":"Das Rathaus bestätigte die neue Szenario- und Betriebsstruktur als frühen Ausbau des Gemeinwesens."},
	{"version":"0.14.2","date":"30.10.2026","topic":"Pistenpunkte und echte Anschlüsse","story":"Der Wegebau erhielt stabile Anschlussregeln; überlappende Strecken sollten nicht länger die Talstation verunstalten."},
	{"version":"0.14.3","date":"30.10.2026","topic":"Pistenpunkte und echte Anschlüsse","story":"Die Baukommission erlaubte versetzbare Pistenpunkte und saubere Verbindungen zwischen Abschnitten."},
	{"version":"0.15.0","date":"30.10.2026","topic":"Stabile Karte, klare Missionen und direkte Liftteams","story":"Missionskarten, direkte Mitarbeiterteams und stabilisierte Karten machten die Verwaltung übersichtlicher."},
	{"version":"0.16.0","date":"30.10.2026","topic":"Gäste mit eigenen Urlaubswünschen","story":"Gäste bekamen eigene Wünsche und unterschiedliche Wege durch das Dorf; unser Fremdenverkehrsamt musste mitdenken."},
	{"version":"0.17.0","date":"31.10.2026","topic":"Vier Karrieren, Updates und eigene Wege","story":"Vier unabhängige Karrieren wurden eingerichtet, dazu Updatekontrollen und selbstgeplante Fußwege."},
	{"version":"0.18.0","date":"31.10.2026","topic":"Anlagen direkt verwalten und leichter anschließen","story":"Werkstätten, Liftstationen und Betriebsräume wurden vom Gebäude aus direkt verwaltbar."},
	{"version":"0.19.0","date":"01.11.2026","topic":"PMDD-Winterbranding und vollflächiger Ladebildschirm","story":"Ein neuer winterlicher Auftritt mit PMDD-Ladebild und App-Zeichen wurde auf dem Rathausplatz enthüllt."},
	{"version":"0.20.0","date":"01.11.2026","topic":"kompakte Skiorte, mehrtägige Hotelgäste und fließender Pistenverkehr","story":"Kleine Skiorte, tatsächliche Übernachtungen und ein fließender Pistenverkehr machten das Dorf zum Ferienort."},
	{"version":"0.20.2","date":"02.11.2026","topic":"Hauptspiel vor Szenarien","story":"Im Rathausprotokoll steht: Zuerst gehört die Bühne dem Hauptspiel; Szenarien bleiben zusätzliche Abenteuer."},
	{"version":"0.21.0","date":"02.11.2026","topic":"Bergwelt, Spielgefühl und fünf Bildstile","story":"Fünf gestalterische Handschriften gaben dem Ort unterschiedliche Lichtstimmungen und Oberflächen."},
	{"version":"0.22.0","date":"03.11.2026","topic":"Lebendige Pisten, kreative Bergwelten und 1.000 Erfolge","story":"Tausend erreichbare Erfolge, fünfhundert Ränge und lebendigere Pisten wurden ins Gemeindealbum aufgenommen."},
	{"version":"0.23.0","date":"03.11.2026","topic":"Landschaft, Pistenwerkstatt und freiere Dorfplanung","story":"Neue Landschaftsdetails, freieres Bauen und eine Pistenwerkstatt verbesserten das Gelände und das Handwerk."},
	{"version":"0.24.0","date":"03.11.2026","topic":"Hotel-Mikrowelten und sechs neue Landschaftsdetails","story":"Häuser erhielten kleine eigene Geschichten; sechs neue Landschaftsminiaturen verschönerten die Wege."},
	{"version":"0.25.0","date":"03.11.2026","topic":"Lineare Hotelmodule und wiederkehrende Winterfeste","story":"Hotels wurden zu Ketten mit Modulen, und der jährliche Advents- und Silvesterkalender fand seinen Platz."},
	{"version":"0.26.0","date":"03.11.2026","topic":"Alpine Radio, Crewleben und illustrierter Pistenatlas","story":"Das alpine Radio, die Crew und illustrierte Pistenkarten brachten Klang und Orientierung in jeden Ort."},
	{"version":"0.27.0","date":"04.11.2026","topic":"Nahtlose Alpine-Radio-Klangwelt (erste Iteration)","story":"Die Musik durfte sanfter von Titel zu Titel reisen; gleichzeitig wurde die unerwünschte grelle FX-Klangquelle stillgelegt."},
	{"version":"0.30.0","date":"04.11.2026","topic":"Alte Karrieren, Radio und mobile Bedienung","story":"Die Gemeinde sicherte ihre alten Bauakten: frühere Karrieren und Sicherungen wurden wieder lesbar. Neue Radiosender, Hotellobby-Musik und bessere mobile Bedienung ergänzten den am 4. November veröffentlichten Hotfix."},
	{"version":"0.31.0","date":"04.11.2026","topic":"Winterkunst, Zeitung und Radiowerbung","story":"Die veröffentlichte APK führte neue künstlerische Winterstile, eine lebendigere Resortzeitung und Hinweise auf die Radiosender ein."},
	{"version":"0.32.0","date":"04.11.2026","topic":"Winterbetrieb und sichere Karrieren","story":"Der veröffentlichte Android-Build brachte fünf Karriere-Startstufen, Bewerbermarkt, Missionsverbesserungen und das originale breite SkiZones-Schriftlogo. Alte Spielstände und Android-Updates bestanden die Freigabetests."},
	{"version":"0.33.0","date":"04.11.2026","topic":"Spielbare Winterwelt und Wetter","story":"Neue Touch-Minispiele, klarere Wetterlagen und eine ruhigere Nacht ergänzten das Resortleben."},
	{"version":"0.33.1","date":"05.11.2026","topic":"Lesbare Alpine Arcade","story":"Der Arcade-Hotfix erhöhte Kontraste und machte die Spieltafeln auf kleinen Bildschirmen besser bedienbar."},
	{"version":"0.33.2","date":"05.11.2026","topic":"Alte Bauakten und vier freie Speicherplätze","story":"Der Sicherungsdienst erhielt vier freie Speicherplätze, eine deutlichere Speicheranzeige und die geschützte Wiederherstellung alter Resorts."},
	{"version":"0.34.0","date":"05.11.2026","topic":"Alpenwelt, Offline-Radio und direkte Bauansicht","story":"Neue freie Musik, persistente Schneespuren im laufenden Resort und die direkte Ansicht fertig gebauter Anlagen verbesserten den Winteralltag."},
	{"version":"0.34.1","date":"05.11.2026","topic":"Neue Tagesgäste und gestaffelte Hotelmorgen","story":"Der Tageswechsel lässt wieder echte Besucher anreisen. Hotelgäste starten verteilt zwischen sieben und neun Uhr; Familien bleiben zusammen."}
]
const DEVELOPMENT_NOTICE := "Die Chronik dokumentiert ausgewählte veröffentlichte Etappen. Der Bauplan ist eine Vorschau, kein Release-Nachweis; die neueste APK steht bei GitHub-Releases."
const ROADMAP: Array = [
	{"from":"04.11.2026","to":"17.11.2026","phase":"I · Release, Nacht und Wetter","target":"0.35+ · Stabilität und freie Resorts","status":"Umgesetzt und in Prüfung · dringende Fehler zuerst","deliverables":[
		"Alte Originalspielstände und freie Speicherplätze erhalten; jede APK mit echten Android-30/36-Installationen und unveränderter Signatur prüfen",
		"Seltenere, angekündigte Stürme statt gleichverteilter Wettertage; Windgrenzen und Liftsicherheit bleiben unverändert",
		"Sonne, Schneefall, Nebel und Sturm grafisch klarer unterscheiden, mit schonender Effektstärke für Android",
		"Abendruhe im Dorf: Gäste gehen zum Hotel, zur Bar oder nach Hause; kein ewiger Nachtverkehr, der den Zeitraffer blockiert",
		"Aufgestaute Nacht-Nachfrage am nächsten Morgen kontrolliert verteilen, ohne Besucher- oder Umsatzverdopplung",
		"Freies Bauen mit unbegrenztem Budget und ohne Forschungssperren; alte Pisten und Lifte mit sicheren Anschlüssen weiter nutzen"],
		"acceptance":"Öffentliche APK und Updatepfad nachgewiesen; 10 sichere Nächte, Wetter-/Sturmstatistik, Save-Migration und Android-30/36-Prüfungen"},
	{"from":"18.11.2026","to":"02.12.2026","phase":"II · Spielerisches Winterdorf und Advent","target":"Zimmerbetrieb, Touch-Spiele und Advent","status":"Teilweise umgesetzt · aktiv im Ausbau","deliverables":[
		"Tic-Tac-Toe und Reaktionsspiel sind spielbar; Kochspiele und weitere echte Touch-Minispiele weiter ausbauen",
		"Bar und Restaurants erhalten kleine grafische Barkeeper- und Kochspiele; Donut Ring Toss am Süßwarenstand als Prototyp",
		"Feste Zimmerbuchungen, Reinigung und mobiler Etagenplan sind in Entwicklung geprüft; Bettenbeziehen und Zimmeraufräumen weiter ausarbeiten",
		"Premium-Alpine- und Après-Ski-Design statt kindlicher Optik; Stil-Assets einschließlich Monochrom-Strichlinien konsequent unterscheiden",
		"Adventskalender ab 1. Dezember prüfen; November-Werbekästen und winterliche Ortsdekoration ohne Pistenkollision",
		"Neue Gäste-, Bau- und Gebäudeinteraktionen über klare Touch-Menüs erreichbar halten"],
		"acceptance":"Mindestens ein vollständig spielbares Touch-Minispiel mit KI/Regeln und Touch-Test; Advent-Datumswechsel, barrierearme Mobile-Ansicht und keine Save-Regression"},
	{"from":"03.12.2026","to":"17.12.2026","phase":"III · Resortleben, Betriebe und Szenarien","target":"Betriebs- und KI-Tiefe mit echten Routen","status":"Geplant · Qualität vor Umfang","deliverables":[
		"Hotellerie, Gastronomie, Nightlife und Personal stärker vernetzen: reale Kapazitäten, Öffnungszeiten und Gästewege",
		"Familien und Wintersportler bewegen sich ohne Pistenstau; Anreise, Bus-Shuttles, Liftstationen und Dorfwege besser abstimmen",
		"Szenariomissionen in Braunlage, Filzmoos, Kitzbühel und Seiser Alm auf erreichbare Ziele und komplette Fahrwege prüfen",
		"Fünf Karriere-Startstufen, Kosten, Gehälter, Wartung und Besucherzufriedenheit über mehrere Winter neu balancieren",
		"Billard-Prototyp für die Bar und spielerische Hotelaufgaben ausbauen; Schach und Blackjack ohne Echtgeld bleiben spätere Module",
		"Radio-Hardware, echte Warenkosten, eigene Pizzen und Kredite sind integriert; Betriebsfolgen und die Resortzeitung weiter verknüpfen"],
		"acceptance":"Reproduzierbare Szenario-Missions- und Routenchecks, 10 stabile Betriebstage, realistische Umsätze sowie geprüfte Musiklizenzen"},
	{"from":"18.12.2026","to":"04.01.2027","phase":"IV · Festtagsresort und Qualitätswinter","target":"Festtage, Kunststile und belastbare Qualität","status":"Geplant · abhängig von Tests","deliverables":[
		"Weihnachts- und Silvesterbetrieb mit Festgebäuden, Besucherschüben, Familien und stimmungsvollen Abendangeboten ausarbeiten",
		"Wetter- und Grafikeffekte sowie unterschiedliche Modelle für jeden Kunststil auf Mittelklasse-Android-Geräten optimieren",
		"Seilbahnen, Gondel-Zwischenstationen, Schneephysik, NPC-Routen und flüssige Kamera- sowie Pistenbau-Gesten final nachprüfen",
		"Resort-Kennzahlen, 1000 Erfolge und 500 Ränge auf faire Ziele, sichtbares Feedback und spielerische Motivation prüfen",
		"Rathaus-Chronik und Zeitung nur aus echten erreichten Meilensteinen und veröffentlichten APKs fortschreiben",
		"Alte Karrieren, Szenariospielstände, Bildschirmwechsel und In-App-Downloads über mehrere Android-Versionen erneut testen"],
		"acceptance":"Nachweisbarer veröffentlichter Android-Build, sichere Altspielstände und Updates, stabile FPS und keine kritischen Bau-, Audio- oder NPC-Fehler"}
]

static func history(newest_first: bool = true) -> Array:
	var ledger: Array = HISTORY.duplicate(true)
	if newest_first: ledger.reverse()
	return ledger

static func roadmap() -> Array:
	return ROADMAP.duplicate(true)

static func winter_ad(date: Dictionary) -> bool:
	return int(date.get("month",-1))==11 and int(date.get("day",0))>=1 and int(date.get("day",0))<=30

static func _suitable(model: RefCounted, at: Vector2, limit: float) -> bool:
	if not at.is_finite() or not model.terrain.contains(at): return false
	if model.terrain.slope_percent(at)>limit: return false
	for item in model.buildings:
		if Terrain.unpack(item.point).distance_to(at)<100.0: return false
	for lift in model.lifts:
		if at.distance_to(Terrain.unpack(lift.bottom))<75.0 or at.distance_to(Terrain.unpack(lift.top))<60.0: return false
	for piste in model.pistes:
		var points: Array=piste.get("points",[])
		for i in range(1,points.size()):
			if Geometry2D.get_closest_point_to_segment(at,Terrain.unpack(points[i-1]),Terrain.unpack(points[i])).distance_to(at)<34.0: return false
	return true

## Only new games are seeded with a free civic landmark.
## Existing imported save snapshots are never rewritten by this helper.
static func ensure_new_town(model: RefCounted) -> bool:
	if model.building_count("town_hall")>0:return true
	var anchors: Array=[Terrain.BASE]
	for item in model.buildings:
		if str(item.get("kind","")) in ["rental","hotel","guesthouse","restaurant","lodge","bus"]:
			anchors.push_front(Terrain.unpack(item.point))
	for anchor in anchors:
		for ring in [108.0,148.0,192.0]:
			for angle_index in range(16):
				var direction: Vector2=Vector2.from_angle(float(angle_index)*TAU/16.0)
				var pos: Vector2=anchor+direction*ring
				if not _suitable(model,pos,48.0): continue
				# Validate real footprints and pedestrian access; keep central
				# starter service lots clear for the player\'s first buildings.
				if not model.preview_building("town_hall",pos).ok: continue
				model.buildings.append({"id":model.next_id,"kind":"town_hall","point":Terrain.pack(pos),
					"cost":0,"enabled":true,"level":1,"upgrade_total":0.0,
					"name":str(Catalog.BUILDINGS.town_hall.name),"visits":0,"revenue":0.0,"rotation":0})
				model.next_id+=1
				model._invalidate()
				return true
	return false
