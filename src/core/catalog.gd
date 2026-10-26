extends RefCounted

const LIFTS := {
	"drag": {"name": "Schlepplift", "cost": 42000, "per_m": 72, "capacity": 420, "speed": 135.0, "upkeep": 410, "wind_limit": 62.0},
	"chair": {"name": "4er-Sessellift", "cost": 82000, "per_m": 120, "capacity": 960, "speed": 210.0, "upkeep": 780, "wind_limit": 48.0},
	"gondola": {"name": "Gondelbahn", "cost": 155000, "per_m": 175, "capacity": 1800, "speed": 300.0, "upkeep": 1250, "wind_limit": 70.0}
}

const BUILDINGS := {
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
