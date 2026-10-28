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
	"kiosk": {"name": "Punschstand", "cost": 9500, "upkeep": 85, "income": 3.0, "appeal": 4, "color": "b96c4e", "description": "Eine kleine warme Pause: günstiger Einstieg in die Verpflegung mit zusätzlichen Serviceerlösen."},
	"viewpoint": {"name": "Panoramaterrasse", "cost": 14000, "upkeep": 90, "income": 0.0, "appeal": 10, "color": "739a9d", "description": "Sitzplätze und Fernrohr für den Gipfelblick. Erhöht den Komfort nahe einer Station."},
	"shelter": {"name": "Wärmeunterstand", "cost": 12500, "upkeep": 70, "income": 0.0, "appeal": 6, "color": "a6a17b", "description": "Eine geschützte Pause im Holzunterstand verbessert den Komfort ohne große Betriebskosten."},
	"snowpark": {"name": "Snowpark", "cost": 45000, "upkeep": 370, "income": 2.0, "appeal": 14, "color": "c98a59", "description": "Ein Freizeitangebot mit Rails und kleinen Schneekickern. Verbessert Komfort und Serviceerlöse; benötigt Schneemanagement."},
	"spa": {"name": "Alpen-Spa", "cost": 65000, "upkeep": 600, "income": 8.0, "appeal": 12, "color": "7babb3", "description": "Wellness mit Außenbecken ergänzt das Hotelangebot. Erhöht Komfort und Serviceerlöse; benötigt Alpine Hotellerie."},
	"bus": {"name": "Skibus-Terminal", "cost": 30000, "upkeep": 220, "income": 0.0, "appeal": 8, "color": "649dad", "description": "Mehr Nachfrage durch bessere Anbindung. Nur im Tal bauen; ein Terminal genügt für den Nachfragebonus."},
	"lodge": {"name": "Berghütte", "cost": 18500, "upkeep": 180, "income": 0.0, "appeal": 7, "color": "cf8e63", "description": "Ruhe und Wärme erhöhen die Zufriedenheit. Im Tal oder nahe einer Station bauen."},
	"restaurant": {"name": "Restaurant", "cost": 32000, "upkeep": 300, "income": 7.0, "appeal": 6, "color": "c36a56", "description": "Verpflegt Gäste nach einer Skirunde; zusätzliche Einnahmen."},
	"rental": {"name": "Skiverleih", "cost": 22000, "upkeep": 150, "income": 5.0, "appeal": 4, "color": "dfb66c", "description": "Zusätzliche Einnahmen und ein attraktiver Einstieg für Tagesgäste."},
	"school": {"name": "Skischule", "cost": 28000, "upkeep": 220, "income": 4.0, "appeal": 9, "color": "58aeb0", "description": "Mehr Komfort und zusätzliche Serviceerlöse. Gut erreichbare blaue Pisten bleiben notwendig."},
	"snowmaker": {"name": "Beschneiung", "cost": 26000, "upkeep": 340, "income": 0.0, "appeal": 1, "color": "8baac4", "description": "Verbessert die Schneelage bei Temperaturen bis −1 °C. Die Pistenmitte muss innerhalb von 150 m liegen."},
	"maintenance": {"name": "Pistenraupengarage", "cost": 48000, "upkeep": 440, "income": 0.0, "appeal": 2, "color": "e6a650", "description": "Verbessert die nächtliche Präparierung des gesamten Resorts."},
	"hotel": {"name": "Berghotel", "cost": 95000, "upkeep": 750, "income": 11.0, "appeal": 16, "color": "b2bcc2", "description": "Mehr Gäste und zusätzliche Erlöse pro Skirunde; höherer täglicher Betrieb."},
	"first_aid": {"name": "Bergwacht", "cost": 24000, "upkeep": 210, "income": 0.0, "appeal": 8, "color": "dd6c70", "description": "Erhöht das Sicherheitsgefühl und die Zufriedenheit auf schweren Pisten."}
}

const WEATHER := [
	{"name": "Sonnig", "temperature": -5.0, "wind": 12.0, "snowfall": 0.0, "demand": 1.2},
	{"name": "Schneefall", "temperature": -8.0, "wind": 26.0, "snowfall": 9.0, "demand": 0.9},
	{"name": "Nebel", "temperature": -2.0, "wind": 9.0, "snowfall": 0.0, "demand": 0.7},
	{"name": "Sturm", "temperature": -9.0, "wind": 58.0, "snowfall": 13.0, "demand": 0.42},
	{"name": "Tauwetter", "temperature": 4.0, "wind": 16.0, "snowfall": 0.0, "demand": 0.65}
]
