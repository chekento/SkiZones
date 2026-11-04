extends RefCounted
## Contextual business micro-simulations. Five decisions per shift, daily reward cap
## remains in BuildingActivities. Choices teach operating tradeoffs rather than reflex clicks.
const CASES := {
	"transport": [
		{"prompt":"Hotelgäste, Skischüler und eine Liftstation verlangen gleichzeitig einen Shuttle. Was priorisierst du?","choices":["Nach Ankunftszeit und Anschluss sortieren","Alle Busse zur gleichen Haltestelle schicken","Den Fahrplan unverändert lassen"],"answer":0,"metric":"Anschlussqualität"},
		{"prompt":"Eine winterliche Straße ist gesperrt. Die Talstation droht zu überfüllen.","choices":["Fahrten abbrechen und niemanden informieren","Sichere Ausweichroute und Gästeinformation organisieren","Shuttles ohne Freigabe über die gesperrte Straße schicken"],"answer":1,"metric":"Betriebssicherheit"},
		{"prompt":"Eine Gruppe hat viel Gepäck und benötigt barrierearmen Einstieg.","choices":["Nur die schnellste Verbindung wählen","Die Gruppe auf mehrere beliebige Busse verteilen","Passendes Fahrzeug reservieren und Umstieg abstimmen"],"answer":2,"metric":"Gästeservice"}
	],
	"maintenance": [
		{"prompt":"Eine Seilbahn meldet unregelmäßige Laufgeräusche unter Last.","choices":["Betrieb sichern und Lager sowie Rollen prüfen","Weiterfahren und erst morgen dokumentieren","Nur die Lautstärke der Warnmeldung absenken"],"answer":0,"metric":"Anlagensicherheit"},
		{"prompt":"Ein Pistenraupenfahrer bemerkt Neuschnee auf einem stark befahrenen Hang.","choices":["Sofort ungeprüft mitten unter Gästen präparieren","Piste absperren, Lage prüfen und Präparierung planen","Bis zur nächsten Saison ignorieren"],"answer":1,"metric":"Pistenzustand"},
		{"prompt":"Die Ersatzteilreserve schrumpft vor dem Wochenende.","choices":["Keinerlei Dokumentation führen","Jedes Teil unabhängig vom Bedarf bestellen","Kritische Verschleißteile nach Risikoklasse disponieren"],"answer":2,"metric":"Betriebseffizienz"}
	],
	"snow": [
		{"prompt":"Die Schneekanonen könnten bei grenzwertigen Temperaturen anlaufen.","choices":["Feuchtkugeltemperatur und Energiebedarf prüfen","Immer volle Leistung unabhängig von Bedingungen","Wasser- und Energiekosten nicht beachten"],"answer":0,"metric":"Schneequalität"},
		{"prompt":"Ein Schneefeld zeigt Eisstellen und eine unerwartete Verdichtung.","choices":["Kunstschnee unkontrolliert darauf verteilen","Oberfläche kontrollieren, präparieren und bei Bedarf sperren","Wartezeiten der Gäste erhöhen, bis es schmilzt"],"answer":1,"metric":"Pistensicherheit"},
		{"prompt":"Die Energiepreise steigen während einer langen Kälteperiode.","choices":["Alle Kanonen dauerhaft laufen lassen","Speicher und Pumpen ignorieren","Beschneiungsfenster nach Temperatur, Bedarf und Kosten planen"],"answer":2,"metric":"Ressourceneffizienz"}
	],
	"rescue": [
		{"prompt":"Eine verletzte Person liegt an einer abgelegenen roten Piste.","choices":["Unfallstelle sichern, Ersteinschätzung und Rettungskette starten","Nur eine Durchsage machen und abwarten","Die Strecke ohne Absicherung offen lassen"],"answer":0,"metric":"Rettungsqualität"},
		{"prompt":"Mehrere Meldungen gehen zugleich ein. Ein Gast ist bewusstseinsgetrübt.","choices":["Nach Reihenfolge des Eingangs abarbeiten","Medizinisch priorisieren und zusätzliche Kräfte anfordern","Zufällig einen Einsatz wählen"],"answer":1,"metric":"Triage"},
		{"prompt":"Starker Wind erschwert die Bergung mit dem Lift.","choices":["Windwarnung ignorieren","Das Wetter als irrelevant abtun","Sicheren alternativen Rettungsweg abstimmen"],"answer":2,"metric":"Sicherheit"}
	],
	"rental": [
		{"prompt":"Ein Anfänger verlangt ein schnelles Raceboard, hat aber kaum Erfahrung.","choices":["Sicherheitsorientiert beraten und passendes Material anbieten","Ohne Nachfrage das teuerste Material verleihen","Die Bindungseinstellung nicht kontrollieren"],"answer":0,"metric":"Ausrüstungsqualität"},
		{"prompt":"Ein Ski ist mit beschädigter Kante zurückgekommen.","choices":["Sofort erneut ausgeben","Sperren, Werkstattauftrag und Ersatz anbieten","Schaden nicht dokumentieren"],"answer":1,"metric":"Materialprüfung"},
		{"prompt":"Eine Familie kommt gleichzeitig mit einer Schulklasse zur Ausleihe.","choices":["Alle ungeordnet warten lassen","Helmgrößen zufällig vergeben","Ausgabe nach Reservierung, Größe und Können organisieren"],"answer":2,"metric":"Wartezeit"}
	],
	"school": [
		{"prompt":"Ein Gast möchte vom Übungshang sofort auf eine schwarze Piste.","choices":["Können einschätzen und passende Lernroute planen","Den Wunsch ohne Rücksicht auf Können erfüllen","Die Gruppe ohne Aufsicht fahren lassen"],"answer":0,"metric":"Lernerfolg"},
		{"prompt":"Die Sicht wird schlechter und einige Kinder sind erschöpft.","choices":["Unterricht unverändert verlängern","Tempo reduzieren, Sammelpunkt wählen und Pause einlegen","Alle getrennt weiterschicken"],"answer":1,"metric":"Gruppensicherheit"},
		{"prompt":"Eine Snowboardgruppe will Kurventechnik und Parkregeln üben.","choices":["Zuerst nur hohe Sprünge trainieren","Sicherheitsregeln weglassen","Progression aus Kantenkontrolle, Blickführung und Parketikette anbieten"],"answer":2,"metric":"Trainingsqualität"}
	],
	"park": [
		{"prompt":"Vor Öffnung des Snowparks steht eine Rail locker.","choices":["Feature sperren und vor Freigabe kontrollieren","Nur einen Warnhinweis ohne Sperre anbringen","Nichts ändern"],"answer":0,"metric":"Park-Sicherheit"},
		{"prompt":"Anfänger und Profis drängen auf dieselbe Sprunglinie.","choices":["Keine Streckenkennzeichnung benutzen","Schwierigkeitslinien und Wartezonen trennen","Mehr Geschwindigkeit auf der Anfängerlinie fördern"],"answer":1,"metric":"Parkfluss"},
		{"prompt":"Nach Schneefall sind die Landungen uneben.","choices":["Ohne Kontrolle weiterfahren lassen","Alle zu schwierigeren Sprüngen schicken","Landungen präparieren und Absprungzonen prüfen"],"answer":2,"metric":"Parkqualität"}
	],
	"hospitality": [
		{"prompt":"Frühstücksservice und Restaurant haben eine unerwartet lange Warteschlange.","choices":["Nachfrage prognostizieren und zusätzliches Servicepersonal einsetzen","Nur die Preise erhöhen","Gäste ohne Auskunft warten lassen"],"answer":0,"metric":"Servicefluss"},
		{"prompt":"Ein Gast meldet eine ernste Lebensmittelunverträglichkeit.","choices":["Zutaten ignorieren","Rezeptur prüfen, Kreuzkontakt vermeiden und Alternative anbieten","Die Speisekarte nicht kontrollieren"],"answer":1,"metric":"Gästevertrauen"},
		{"prompt":"Ein Schneesturm verzögert die Warenlieferung.","choices":["Bestellungen unverändert versprechen","Ohne Rücksicht auf Vorräte weiterverkaufen","Menü mit vorhandenen Zutaten planen und Gäste informieren"],"answer":2,"metric":"Betriebsplanung"}
	],
	"nightlife": [
		{"prompt":"Die Après-Ski-Bar erreicht die zulässige Kapazität.","choices":["Einlass steuern und sichere Wege freihalten","Noch mehr Gäste ohne Prüfung hereinlassen","Die Fluchtwege zustellen"],"answer":0,"metric":"Sicherer Betrieb"},
		{"prompt":"Eine Gruppe möchte nach Liftbetrieb noch lange feiern.","choices":["Personal und Nachtruhe ignorieren","Spätbetrieb, Personal und sicheren Rücktransport abstimmen","Den gesamten Busverkehr abschalten"],"answer":1,"metric":"Nachtlogistik"},
		{"prompt":"An einem Gast werden deutliche Beeinträchtigungen bemerkt.","choices":["Weiter Alkohol anbieten","Eine riskante Abfahrt empfehlen","Verantwortungsvoll reagieren und sichere Heimfahrt unterstützen"],"answer":2,"metric":"Gästewohl"}
	],
	"wellness": [
		{"prompt":"Pool und Spa benötigen Pflege, während Gäste eintreffen.","choices":["Wasserqualität prüfen und Belegung passend steuern","Kontrollen aussetzen","Einen zu kalten Bereich ohne Hinweis öffnen"],"answer":0,"metric":"Hygiene"},
		{"prompt":"Zu viele Gäste haben denselben Ruhebereich reserviert.","choices":["Alle ohne Begrenzung hineinlassen","Kapazität und Zeitfenster behutsam neu planen","Reservierungen unangekündigt löschen"],"answer":1,"metric":"Komfort"},
		{"prompt":"Im Fitnessraum braucht ein Anfänger Unterstützung.","choices":["Maximale Belastung vorgeben","Sicherheitsanweisung überspringen","Bewegungsprofil und sichere Belastung abstimmen"],"answer":2,"metric":"Gesundheit"}
	],
	"retail": [
		{"prompt":"Ein neuer Auftrag trifft kurz vor Ladenschluss ein.","choices":["Material, Personal und Lieferzeit realistisch abgleichen","Ungeprüfte Lieferung garantieren","Alle Aufträge ohne System mischen"],"answer":0,"metric":"Auftragsqualität"},
		{"prompt":"Ein Kunde reklamiert einen fehlerhaften Artikel.","choices":["Reklamation ignorieren","Qualitätskontrolle und passende Nachbesserung veranlassen","Den Fehler nicht dokumentieren"],"answer":1,"metric":"Produktqualität"},
		{"prompt":"Ein gefragtes Produkt droht auszuverkaufen.","choices":["Bedarf ignorieren","Unbegrenzt auf Kredit nachkaufen","Bestand prüfen und Nachfrage sinnvoll nachbestellen"],"answer":2,"metric":"Bestandsplanung"}
	]
}
const TYPE_GROUPS := {
	"transport":["bus"],
	"maintenance":["repair_office","maintenance"],
	"snow":["snowmaker"],
	"rescue":["first_aid"],
	"rental":["rental"],
	"school":["school"],
	"park":["snowpark"],
	"hospitality":["restaurant","pizzeria","kiosk","cocoa","schmarrn","lodge","shelter"],
	"nightlife":["bar","disco"],
	"wellness":["spa","pool","fitness"],
	"retail":["printing_press","newsstand","souvenir","watchmaker","craftshop","viewpoint"]
}

static func group(kind: String) -> String:
	for key in TYPE_GROUPS:
		if kind in TYPE_GROUPS[key]: return str(key)
	return ""

static func challenge(model: RefCounted, building: Dictionary, session: Dictionary) -> Dictionary:
	var category: String = group(str(building.get("kind","")))
	if category.is_empty(): return {}
	var situations: Array = CASES[category]
	var step: int = int(session.get("step",0))
	var index: int = posmod(step + int(session.get("day",0)) % 3,situations.size())
	var situation: Dictionary = situations[index]
	var waiting: int = model.queue_size()
	var guests: int = model.present_guests()
	var conditions: String = "Hohe Nachfrage" if waiting > 20 else "Regelbetrieb"
	return {
		"mode":"decision","target":0.0,"answer":int(situation.answer),
		"choices":situation.choices.duplicate(),"prompt":str(situation.prompt),
		"metric":str(situation.metric),"sector":category,
		"context":"%s · %d Gäste im Gebiet · %d Gäste warten" % [conditions,guests,waiting]
	}
