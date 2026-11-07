extends RefCounted

const PLAZAS := {
	"walkway": {"name":"Fußweg planen","radius":4.0,"cost":252,"per_m":18,"description":"Start und Ziel verbinden: Liftzugang, Pistenende, Gebäude oder Platz."},
	"path": {"name": "Gehfläche", "radius": 26.0, "cost": 2400, "description": "Kleine geräumte Fläche. Mehrere Flächen verbinden sich zu einem Fußweg."},
	"plaza": {"name": "Stationsplatz", "radius": 48.0, "cost": 7200, "description": "Großer Treffpunkt für Umstiege, Pistenanschlüsse und neue Gebäude."},
	"promenade": {"name": "Resort-Promenade", "radius": 70.0, "cost": 14500, "description": "Weitläufiger Aufenthaltsbereich für ein wachsendes Resort."}
}

const LIFTS := {
	"carpet": {"name": "Zauberteppich", "family": "carpet", "seats": 1, "max_length": 250.0, "cost": 18000, "per_m": 38, "capacity": 600, "speed": 42.0, "upkeep": 160, "wind_limit": 85.0},
	"drag": {"name": "Teller-Schlepplift", "family": "drag", "seats": 1, "max_length": 700.0, "cost": 42000, "per_m": 72, "capacity": 420, "speed": 90.0, "upkeep": 410, "wind_limit": 62.0},
	"chair1": {"name": "1er-Sessellift", "family": "chair", "seats": 1, "max_length": 1400.0, "cost": 48000, "per_m": 86, "capacity": 360, "speed": 126.0, "upkeep": 450, "wind_limit": 46.0},
	"chair2": {"name": "2er-Sessellift", "family": "chair", "seats": 2, "max_length": 1800.0, "cost": 64000, "per_m": 100, "capacity": 600, "speed": 168.0, "upkeep": 590, "wind_limit": 47.0},
	"chair": {"name": "4er-Sessellift", "family": "chair", "seats": 4, "max_length": 2400.0, "cost": 82000, "per_m": 120, "capacity": 960, "speed": 210.0, "upkeep": 780, "wind_limit": 48.0},
	"chair6": {"name": "6er-Panoramasessel", "family": "chair", "seats": 6, "max_length": 2800.0, "cost": 126000, "per_m": 145, "capacity": 1500, "speed": 270.0, "upkeep": 1050, "wind_limit": 53.0},
	"chair8": {"name": "8er-Panoramasessel", "family": "chair", "seats": 8, "max_length": 3000.0, "cost": 188000, "per_m": 172, "capacity": 2400, "speed": 300.0, "upkeep": 1480, "wind_limit": 55.0},
	"gondola": {"name": "8er-Gondelbahn", "family": "gondola", "seats": 8, "max_length": 3200.0, "cost": 155000, "per_m": 175, "capacity": 1800, "speed": 300.0, "upkeep": 1250, "wind_limit": 70.0}
}

const BUILDINGS := {
	# Independent PUBLIC toilets; hotels and restaurants already include internal WCs.
	"wc_dixi": {"name":"Portable Toilet","cost":850,"upkeep":15,"income":0.0,"appeal":2,"color":"278fc6","description":"Eine kleine mobile Toilette. Durch Ausbau und Forschung wächst sie bis zum Premium-Sanitärzentrum. Reinigung und Entsorgung bleiben Teil des Betriebs."},
	"wc_cabin": {"name":"Winter-WC-Kabine","cost":2600,"upkeep":28,"income":0.0,"appeal":3,"color":"3d91b2","description":"Zwei robuste WC-Kabinen mit mehr Kapazität und günstiger Wartung."},
	"wc_module": {"name":"Sanitär-Container","cost":9800,"upkeep":80,"income":0.0,"appeal":5,"color":"6ba8bc","description":"Vier zugängliche Toiletten mit Ver- und Entsorgungsservice."},
	"wc_house": {"name":"Alpines WC-Haus","cost":24500,"upkeep":180,"income":0.0,"appeal":7,"color":"a9bdc2","description":"Beheizbares Sanitärhaus mit hoher Besucherleistung."},
	"wc_luxury": {"name":"Luxus-Sanitärzentrum","cost":65000,"upkeep":420,"income":0.0,"appeal":11,"color":"99b3b7","description":"Großes Premium-WC mit besonders viel Kapazität, Service und Komfort."},
	"cocoa": {"name":"Kakaoladen","cost":11500,"upkeep":90,"income":6.0,"appeal":5,"color":"a3775e","description":"Heiße Schokolade wärmt kalte Gäste. Ein günstiger Einstieg mit kurzen Pausen und Gastronomiepersonal."},
	"schmarrn": {"name":"Kaiserschmarrn-Laden","cost":17500,"upkeep":155,"income":9.0,"appeal":7,"color":"d9ab62","description":"Warmer Kaiserschmarrn stillt den Hunger und bietet Familien Platz für eine gemeinsame Pause."},
	"pizzeria": {"name":"Pizzeria","cost":26500,"upkeep":240,"income":15.0,"appeal":8,"color":"b9694e","description":"Sättigende Pizza und längere Mittagspausen. Benötigt Gastronomiepersonal und einen erreichbaren Eingang."},
	"repair_office": {"name": "Technik- und Reparaturzentrale", "cost": 38000, "upkeep": 180, "income": 0.0, "appeal": 0, "color": "6f99a5", "description": "Techniker und Elektriker einstellen, Ersatzteile bestellen und defekte Lifte reparieren."},
	"disco": {"name": "Après-Ski & Disco", "cost": 68000, "upkeep": 460, "income": 22.0, "appeal": 14, "color": "b785ba", "description": "Abendbetrieb von 18 bis 06 Uhr. Benötigt Gastronomiepersonal und Sicherheit."},
	"pool": {"name": "Beheizter Außenpool", "cost": 85000, "upkeep": 650, "income": 18.0, "appeal": 18, "color": "70bfc7", "description": "Erholung von 10 bis 23 Uhr mit Energiebedarf und Personal für Service und Sicherheit."},
	"kiosk": {"name": "Punschstand", "cost": 9500, "upkeep": 85, "income": 5.0, "appeal": 4, "color": "b96c4e", "description": "Eine kleine warme Pause: günstiger Einstieg in die Verpflegung mit zusätzlichen Serviceerlösen."},
	"viewpoint": {"name": "Panoramaterrasse", "cost": 14000, "upkeep": 90, "income": 0.0, "appeal": 10, "color": "739a9d", "description": "Sitzplätze und Fernrohr für den Gipfelblick. Erhöht den Komfort nahe einer Station."},
	"shelter": {"name": "Wärmeunterstand", "cost": 12500, "upkeep": 70, "income": 0.0, "appeal": 6, "color": "a6a17b", "description": "Eine geschützte Pause im Holzunterstand verbessert den Komfort ohne große Betriebskosten."},
	"snowpark": {"name": "Snowpark", "cost": 45000, "upkeep": 370, "income": 2.0, "appeal": 14, "color": "c98a59", "description": "Ein Freizeitangebot mit Rails und kleinen Schneekickern. Verbessert Komfort und Serviceerlöse; benötigt Schneemanagement."},
	"spa": {"name": "Alpen-Spa", "cost": 65000, "upkeep": 600, "income": 8.0, "appeal": 12, "color": "7babb3", "description": "Wellness mit Außenbecken ergänzt das Hotelangebot. Erhöht Komfort und Serviceerlöse; benötigt Alpine Hotellerie."},
	"bus": {"name": "Skibus-Terminal", "cost": 30000, "upkeep": 220, "income": 0.0, "appeal": 8, "color": "649dad", "description": "Mehr Nachfrage durch bessere Anbindung. Nur im Tal bauen; ein Terminal genügt für den Nachfragebonus."},
	"lodge": {"name": "Berghütte", "cost": 18500, "upkeep": 180, "income": 0.0, "appeal": 7, "color": "cf8e63", "description": "Ruhe und Wärme erhöhen die Zufriedenheit. Im Tal oder nahe einer Station bauen."},
	"restaurant": {"name": "Restaurant", "cost": 32000, "upkeep": 300, "income": 13.0, "appeal": 6, "color": "c36a56", "description": "Verpflegt Gäste nach einer Skirunde; zusätzliche Einnahmen."},
	"rental": {"name": "Skiverleih", "cost": 22000, "upkeep": 150, "income": 8.0, "appeal": 4, "color": "dfb66c", "description": "Zusätzliche Einnahmen und ein attraktiver Einstieg für Tagesgäste."},
	"school": {"name": "Skischule", "cost": 28000, "upkeep": 220, "income": 8.0, "appeal": 9, "color": "58aeb0", "description": "Mehr Komfort und zusätzliche Serviceerlöse. Gut erreichbare blaue Pisten bleiben notwendig."},
	"snowmaker": {"name": "Beschneiung", "cost": 26000, "upkeep": 340, "income": 0.0, "appeal": 1, "color": "8baac4", "description": "Verbessert die Schneelage bei Temperaturen bis −1 °C. Die Pistenmitte muss innerhalb von 150 m liegen."},
	"maintenance": {"name": "Pistenraupengarage", "cost": 48000, "upkeep": 440, "income": 0.0, "appeal": 2, "color": "e6a650", "description": "Verbessert die nächtliche Präparierung des gesamten Resorts."},
	"hotel": {"name": "Berghotel", "cost": 95000, "upkeep": 750, "income": 11.0, "appeal": 16, "color": "b2bcc2", "description": "Mehr Nachfrage und eine ausgiebige Pause mit Verpflegung, Wärme und Erholung. Erlöse entstehen nach dem Besuch."},
	"cabin":{"name":"Ferienhütte", "cost":12500, "upkeep":45, "income":0.0, "appeal":5, "color":"b98c64", "description":"Zwei gemütliche Ferienzimmer mit Selbst-Check-in. Ein günstiger Einstieg in mehrtägigen Skiurlaub."},
	"apartment":{"name":"Ferienapartments", "cost":28000, "upkeep":95, "income":0.0, "appeal":8, "color":"96adbb", "description":"Vier Ferienwohnungen mit Selbst-Check-in für einen längeren Aufenthalt im Dorf."},
	"chalet":{"name":"Alpenchalet", "cost":52000, "upkeep":210, "income":0.0, "appeal":12, "color":"bd9c79", "description":"Sechs hochwertige Ferienzimmer mit Selbst-Check-in, Komfortausbau und eigenem Preis."},
	"guesthouse":{"name":"Alpenpension", "cost":46000, "upkeep":180, "income":6.0, "appeal":11, "color":"d3b681", "description":"Zehn Gästezimmer mit Rezeption und Frühstück. Benötigt Hotelpersonal in allen Schichten."},
	"grand_hotel":{"name":"Grandhotel", "cost":195000, "upkeep":1250, "income":18.0, "appeal":25, "color":"a3b8cd", "description":"48 Zimmer mit umfassender Verwaltung, Familienangebot, Premiumzimmern und Hotelketten."},
	"bar":{"name":"Alpenbar", "cost":23500, "upkeep":160, "income":12.0, "appeal":9, "color":"a67a98", "description":"Abendliche Getränke, ein eigenes Ausschankspiel und zusätzliche Umsätze nach dem Skitag."},
	"fitness": {"name":"Fitnessstudio","cost":46500,"upkeep":370,"income":9.0,"appeal":10,"color":"72a1b5","description":"Trainingsraum mit Hantelstation, Fahrradergometer und Bergpanorama. Auch als Hotelmodul möglich."},
	"souvenir": {"name":"Alpiner Souvenirshop","cost":18500,"upkeep":155,"income":9.0,"appeal":9,"color":"be8c65","description":"Handgeschnitzte Andenken, kleine Kuhglocken und liebevolle Urlaubsmitbringsel."},
	"watchmaker": {"name":"Uhrmacher & Werkstatt","cost":27500,"upkeep":195,"income":10.0,"appeal":10,"color":"8c7f99","description":"Traditioneller Uhrmacher mit Miniatur-Zifferblättern, Reparaturen und Reiseandenken."},
	"craftshop": {"name":"Alpine Handwerksstube","cost":21500,"upkeep":170,"income":9.0,"appeal":11,"color":"aa885e","description":"Handgefertigte Schnitzereien, Holzwerkzeuge, lokale Souvenirs und Bergtradition."},
	"printing_press": {"name":"Druckerei & Zeitungsredaktion","cost":33500,"upkeep":230,"income":0.0,"appeal":8,"color":"877a8e","description":"Druckt ein ExtraBlatt mit den fünf neuesten Achievements. Erst danach können Kioske Zeitungen verkaufen."},
	"newsstand": {"name":"Alpiner Zeitungsstand","cost":8500,"upkeep":75,"income":5.0,"appeal":6,"color":"b89a7b","description":"Verkauft Zeitungen an Besucher, sofern eine geöffnete Dorfredaktion betrieben wird."},
	"town_hall": {"name":"Rathaus & Ortschronik","cost":18000,"upkeep":0,"income":0.0,"appeal":4,"color":"bc9a6e","description":"Das Stadtgedächtnis: alle veröffentlichten Versionen seit dem ersten Winter, die Bauakten des Gemeinderats und ein Zweimonatsplan für kommende Verbesserungen. In neuen Orten kostenfrei gesetzt."},
	"first_aid": {"name": "Bergwacht", "cost": 24000, "upkeep": 210, "income": 0.0, "appeal": 8, "color": "dd6c70", "description": "Ein warmer Rückzugsort für erschöpfte Gäste. Ein tatsächlicher Besuch hilft bei Kälte und Müdigkeit."}
}

const LODGING := {
	"cabin":{"rooms":2, "price":72},
	"apartment":{"rooms":4, "price":95},
	"chalet":{"rooms":6, "price":145},
	"guesthouse":{"rooms":10, "price":110},
	"hotel":{"rooms":24, "price":165},
	"grand_hotel":{"rooms":48, "price":210}
}

const WEATHER := [
	{"name": "Sonnig", "temperature": -5.0, "wind": 12.0, "snowfall": 0.0, "demand": 1.2},
	{"name": "Schneefall", "temperature": -8.0, "wind": 26.0, "snowfall": 9.0, "demand": 0.9},
	{"name": "Nebel", "temperature": -2.0, "wind": 9.0, "snowfall": 0.0, "demand": 0.7},
	{"name": "Sturm", "temperature": -9.0, "wind": 58.0, "snowfall": 13.0, "demand": 0.42},
	{"name": "Tauwetter", "temperature": 4.0, "wind": 16.0, "snowfall": 0.0, "demand": 0.65}
]

const FOOD_KINDS = ["kiosk", "cocoa", "schmarrn", "pizzeria", "restaurant", "lodge", "hotel"]
static func building_group(kind: String) -> String:
	if kind.begins_with("wc_"): return "Sanitär & Infrastruktur"
	if LODGING.has(kind): return "Unterkünfte & Hotels"
	if kind in FOOD_KINDS or kind == "shelter": return "Verpflegung & Wärme"
	if kind in ["repair_office", "maintenance", "snowmaker", "first_aid"]: return "Betrieb & Sicherheit"
	if kind in ["rental", "school", "bus", "souvenir", "watchmaker", "craftshop", "printing_press", "newsstand", "town_hall"]: return "Service & Anreise"
	return "Freizeit & Erholung"
static func purchasable(kind:String) -> bool:
	return BUILDINGS.has(kind) and kind not in ["wc_cabin","wc_module","wc_house","wc_luxury"]

static func building_order() -> Array:
	var result := BUILDINGS.keys().filter(func(kind):return purchasable(str(kind)))
	result.sort_custom(func(a, b): return BUILDINGS[a].cost < BUILDINGS[b].cost if BUILDINGS[a].cost != BUILDINGS[b].cost else a < b)
	return result


