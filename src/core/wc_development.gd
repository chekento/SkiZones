extends RefCounted
## One public facility, 100 persistent projects with actual bounded effects.
## The five original research IDs remain valid in all historical saves.
const STAGES := [
	{"name":"Portable Toilet","width":6.4,"depth":6.8,"height":9.5,"places":1,"volume":18.0,"upkeep":15.0,"footprint":[8,8]},
	{"name":"Winterkabinen","width":11.0,"depth":9.0,"height":10.5,"places":2,"volume":34.0,"upkeep":28.0,"footprint":[12,10]},
	{"name":"Sanitärmodul","width":17.0,"depth":12.0,"height":11.0,"places":4,"volume":72.0,"upkeep":80.0,"footprint":[18,13]},
	{"name":"Alpines Sanitärhaus","width":23.0,"depth":17.0,"height":13.0,"places":8,"volume":150.0,"upkeep":180.0,"footprint":[24,19]},
	{"name":"Premium-Sanitärzentrum","width":30.0,"depth":22.0,"height":16.0,"places":16,"volume":340.0,"upkeep":420.0,"footprint":[32,24]}
]
static func visual_index(kind:String,level:int=1) -> int:
	return clampi(level-1,0,4) if kind=="wc_dixi" else ["wc_dixi","wc_cabin","wc_module","wc_house","wc_luxury"].find(kind)

const GROUPS = [
	{
		"id": "architecture",
		"name": "Ausbau & Architektur",
		"nodes": [
			"wc_logistics",
			"sanitation",
			"wc_winter",
			"wc_hygiene",
			"wc_comfort",
			"wc_arch_01",
			"wc_arch_02",
			"wc_arch_03",
			"wc_arch_04",
			"wc_arch_05"
		]
	},
	{
		"id": "tanks",
		"name": "Tank & Kapazität",
		"nodes": [
			"wc_tanks_01",
			"wc_tanks_02",
			"wc_tanks_03",
			"wc_tanks_04",
			"wc_tanks_05",
			"wc_tanks_06",
			"wc_tanks_07",
			"wc_tanks_08",
			"wc_tanks_09",
			"wc_tanks_10"
		]
	},
	{
		"id": "hygiene",
		"name": "Hygiene & Oberflächen",
		"nodes": [
			"wc_hygiene_01",
			"wc_hygiene_02",
			"wc_hygiene_03",
			"wc_hygiene_04",
			"wc_hygiene_05",
			"wc_hygiene_06",
			"wc_hygiene_07",
			"wc_hygiene_08",
			"wc_hygiene_09",
			"wc_hygiene_10"
		]
	},
	{
		"id": "service",
		"name": "Wartung & Einsatzplanung",
		"nodes": [
			"wc_service_01",
			"wc_service_02",
			"wc_service_03",
			"wc_service_04",
			"wc_service_05",
			"wc_service_06",
			"wc_service_07",
			"wc_service_08",
			"wc_service_09",
			"wc_service_10"
		]
	},
	{
		"id": "aging",
		"name": "Haltbarkeit & Schutz",
		"nodes": [
			"wc_aging_01",
			"wc_aging_02",
			"wc_aging_03",
			"wc_aging_04",
			"wc_aging_05",
			"wc_aging_06",
			"wc_aging_07",
			"wc_aging_08",
			"wc_aging_09",
			"wc_aging_10"
		]
	},
	{
		"id": "flow",
		"name": "Besucherfluss",
		"nodes": [
			"wc_flow_01",
			"wc_flow_02",
			"wc_flow_03",
			"wc_flow_04",
			"wc_flow_05",
			"wc_flow_06",
			"wc_flow_07",
			"wc_flow_08",
			"wc_flow_09",
			"wc_flow_10"
		]
	},
	{
		"id": "cleaning",
		"name": "Reinigungsverfahren",
		"nodes": [
			"wc_cleaning_01",
			"wc_cleaning_02",
			"wc_cleaning_03",
			"wc_cleaning_04",
			"wc_cleaning_05",
			"wc_cleaning_06",
			"wc_cleaning_07",
			"wc_cleaning_08",
			"wc_cleaning_09",
			"wc_cleaning_10"
		]
	},
	{
		"id": "disposal",
		"name": "Entsorgungsverfahren",
		"nodes": [
			"wc_disposal_01",
			"wc_disposal_02",
			"wc_disposal_03",
			"wc_disposal_04",
			"wc_disposal_05",
			"wc_disposal_06",
			"wc_disposal_07",
			"wc_disposal_08",
			"wc_disposal_09",
			"wc_disposal_10"
		]
	},
	{
		"id": "economy",
		"name": "Betrieb & Ressourcen",
		"nodes": [
			"wc_economy_01",
			"wc_economy_02",
			"wc_economy_03",
			"wc_economy_04",
			"wc_economy_05",
			"wc_economy_06",
			"wc_economy_07",
			"wc_economy_08",
			"wc_economy_09",
			"wc_economy_10"
		]
	},
	{
		"id": "winter",
		"name": "Frost & Winterbetrieb",
		"nodes": [
			"wc_winter_01",
			"wc_winter_02",
			"wc_winter_03",
			"wc_winter_04",
			"wc_winter_05",
			"wc_winter_06",
			"wc_winter_07",
			"wc_winter_08",
			"wc_winter_09",
			"wc_winter_10"
		]
	}
]
const PROJECTS = {
	"wc_logistics": {
		"name": "Mobile WC-Logistik",
		"cost": 3200,
		"points": 1,
		"days": 1,
		"requires": [],
		"effect": "Ausbau auf Stufe 2 mit zwei Kabinen freischalten.",
		"modifier": "unlock",
		"amount": 2
	},
	"sanitation": {
		"name": "Sanitärtechnik",
		"cost": 14000,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Ausbau auf Stufe 3 zum Sanitärmodul freischalten.",
		"modifier": "unlock",
		"amount": 3
	},
	"wc_winter": {
		"name": "Frostsichere Entsorgung",
		"cost": 8500,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Winterisolierung für öffentliche Toiletten aktivieren.",
		"modifier": "unlock",
		"amount": 0
	},
	"wc_hygiene": {
		"name": "Sanitärhygiene",
		"cost": 26000,
		"points": 4,
		"days": 2,
		"requires": [
			"sanitation"
		],
		"effect": "Ausbau auf Stufe 4 zum alpinen Sanitärhaus freischalten.",
		"modifier": "unlock",
		"amount": 4
	},
	"wc_comfort": {
		"name": "Premium-Sanitärversorgung",
		"cost": 49000,
		"points": 6,
		"days": 2,
		"requires": [
			"wc_hygiene",
			"wc_winter"
		],
		"effect": "Ausbau auf Stufe 5 zum Premium-Sanitärzentrum freischalten.",
		"modifier": "unlock",
		"amount": 5
	},
	"wc_arch_01": {
		"name": "Standardisierte Fundamente",
		"cost": 800,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Ausbaukosten öffentlicher Toiletten um weitere 3 % senken.",
		"modifier": "construction",
		"amount": 0.03
	},
	"wc_arch_02": {
		"name": "Modulare Anschlussraster",
		"cost": 1600,
		"points": 1,
		"days": 1,
		"requires": [
			"sanitation",
			"wc_arch_01"
		],
		"effect": "Ausbaukosten öffentlicher Toiletten um weitere 3 % senken.",
		"modifier": "construction",
		"amount": 0.03
	},
	"wc_arch_03": {
		"name": "Wiederverwendbare Bauteile",
		"cost": 2400,
		"points": 2,
		"days": 1,
		"requires": [
			"sanitation",
			"wc_arch_02"
		],
		"effect": "Ausbaukosten öffentlicher Toiletten um weitere 3 % senken.",
		"modifier": "construction",
		"amount": 0.03
	},
	"wc_arch_04": {
		"name": "Verdichtete Bauabläufe",
		"cost": 3200,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_hygiene",
			"wc_arch_03"
		],
		"effect": "Ausbaukosten öffentlicher Toiletten um weitere 3 % senken.",
		"modifier": "construction",
		"amount": 0.03
	},
	"wc_arch_05": {
		"name": "Vorgefertigte Premiumflächen",
		"cost": 4000,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_comfort",
			"wc_arch_04"
		],
		"effect": "Ausbaukosten öffentlicher Toiletten um weitere 3 % senken.",
		"modifier": "construction",
		"amount": 0.03
	},
	"wc_tanks_01": {
		"name": "Belüfteter Vorratstank",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_02": {
		"name": "Verstärkte Tankwände",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_tanks_01"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_03": {
		"name": "Sedimentfreier Ablauf",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_tanks_02"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_04": {
		"name": "Kaskadierte Speicher",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_tanks_03"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_05": {
		"name": "Doppelte Sammelkammer",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_tanks_04",
			"sanitation"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_06": {
		"name": "Optimierte Tankgeometrie",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_tanks_05"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_07": {
		"name": "Getrennte Rücklaufkammer",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_tanks_06"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_08": {
		"name": "Kompakte Speichermodule",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_tanks_07",
			"wc_hygiene"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_09": {
		"name": "Überlaufsicherer Puffer",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_tanks_08"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_tanks_10": {
		"name": "Maximiertes Nutzvolumen",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_tanks_09",
			"wc_comfort"
		],
		"effect": "Tankvolumen um weitere 4 % der Grundkapazität erhöhen.",
		"modifier": "volume",
		"amount": 0.04
	},
	"wc_hygiene_01": {
		"name": "Abwaschbare Türflächen",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_02": {
		"name": "Berührungsarme Griffe",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_hygiene_01"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_03": {
		"name": "Versiegelte Sitzflächen",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_hygiene_02"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_04": {
		"name": "Fugenarme Innenwände",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_hygiene_03"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_05": {
		"name": "Geschützte Papierhalter",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_hygiene_04",
			"sanitation"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_06": {
		"name": "Glatter Bodenabschluss",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_hygiene_05"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_07": {
		"name": "Spritzgeschützte Armaturen",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_hygiene_06"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_08": {
		"name": "Hygienische Ablageflächen",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_hygiene_07",
			"wc_hygiene"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_09": {
		"name": "Nahtlose Innenauskleidung",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_hygiene_08"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_hygiene_10": {
		"name": "Verschleißfeste Hygieneflächen",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_hygiene_09",
			"wc_comfort"
		],
		"effect": "Hygieneverbrauch pro Besuch um weitere 2,5 % senken.",
		"modifier": "hygiene",
		"amount": 0.025
	},
	"wc_service_01": {
		"name": "Service-Werkzeugset",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_02": {
		"name": "Gebündelte Wartungswege",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_service_01"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_03": {
		"name": "Mobile Servicestation",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_service_02"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_04": {
		"name": "Sortierte Ersatzteilsätze",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_service_03"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_05": {
		"name": "Digitale Wartungslisten",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_service_04",
			"sanitation"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_06": {
		"name": "Geteilte Servicefahrten",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_service_05"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_07": {
		"name": "Planbare Einsatzfenster",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_service_06"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_08": {
		"name": "Zentrale Wartungslogistik",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_service_07",
			"wc_hygiene"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_09": {
		"name": "Bedarfsgerechte Servicerunden",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_service_08"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_service_10": {
		"name": "Koordinierte Premiumwartung",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_service_09",
			"wc_comfort"
		],
		"effect": "Reinigungs- und Entsorgungsservice um weitere 2 % vergünstigen.",
		"modifier": "service",
		"amount": 0.02
	},
	"wc_aging_01": {
		"name": "Dichte Türabschlüsse",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_02": {
		"name": "Geschützte Entlüftung",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_aging_01"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_03": {
		"name": "Robuste Bodendichtung",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_aging_02"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_04": {
		"name": "Abgedeckte Fugen",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_aging_03"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_05": {
		"name": "Schneefeste Dachkanten",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_aging_04",
			"sanitation"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_06": {
		"name": "Windgeschützte Eingänge",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_aging_05"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_07": {
		"name": "Beständige Innenverkleidung",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_aging_06"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_08": {
		"name": "Feuchtesichere Wandmodule",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_aging_07",
			"wc_hygiene"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_09": {
		"name": "Langlebige Schutzbeschichtung",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_aging_08"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_aging_10": {
		"name": "Alpine Dauerabdichtung",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_aging_09",
			"wc_comfort"
		],
		"effect": "Täglichen Hygieneverschleiß um weitere 3 % senken.",
		"modifier": "aging",
		"amount": 0.03
	},
	"wc_flow_01": {
		"name": "Eindeutige Belegungsanzeige",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_02": {
		"name": "Lesbare Kabinenschilder",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_flow_01"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_03": {
		"name": "Leichtgängige Verriegelung",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_flow_02"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_04": {
		"name": "Griffbereite Ausstattung",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_flow_03"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_05": {
		"name": "Getrennte Zu- und Abgänge",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_flow_04",
			"sanitation"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_06": {
		"name": "Übersichtliche Waschnischen",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_flow_05"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_07": {
		"name": "Wartefreie Ausgangszone",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_flow_06"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_08": {
		"name": "Schnelle Kabinenfreigabe",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_flow_07",
			"wc_hygiene"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_09": {
		"name": "Optimierter Kabinengrundriss",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_flow_08"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_flow_10": {
		"name": "Durchgehender Besucherfluss",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_flow_09",
			"wc_comfort"
		],
		"effect": "Kabinennutzungszeit um weitere 2 % verkürzen.",
		"modifier": "minutes",
		"amount": 0.02
	},
	"wc_cleaning_01": {
		"name": "Dosierte Reinigungsmittel",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_02": {
		"name": "Vorsortierte Reinigungssätze",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_cleaning_01"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_03": {
		"name": "Breite Reinigungskanten",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_cleaning_02"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_04": {
		"name": "Leicht erreichbare Ecken",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_cleaning_03"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_05": {
		"name": "Modulare Bürstensysteme",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_cleaning_04",
			"sanitation"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_06": {
		"name": "Sparsame Spülreinigung",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_cleaning_05"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_07": {
		"name": "Schnell trocknende Flächen",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_cleaning_06"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_08": {
		"name": "Wiederbefüllbare Servicepacks",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_cleaning_07",
			"wc_hygiene"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_09": {
		"name": "Standardisierte Reinigungsfolge",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_cleaning_08"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_cleaning_10": {
		"name": "Effiziente Komplettreinigung",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_cleaning_09",
			"wc_comfort"
		],
		"effect": "Kosten jeder Reinigung um weitere 3 % senken.",
		"modifier": "cleaning",
		"amount": 0.03
	},
	"wc_disposal_01": {
		"name": "Schneller Tankanschluss",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_02": {
		"name": "Dichte Schlauchkupplungen",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_disposal_01"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_03": {
		"name": "Geschützte Entnahmestutzen",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_disposal_02"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_04": {
		"name": "Restarme Absaugführung",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_disposal_03"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_05": {
		"name": "Standardisierte Sammeladapter",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_disposal_04",
			"sanitation"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_06": {
		"name": "Kurze Entsorgungswege",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_disposal_05"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_07": {
		"name": "Gebündelte Tankabfuhr",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_disposal_06"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_08": {
		"name": "Druckoptimierte Absaugung",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_disposal_07",
			"wc_hygiene"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_09": {
		"name": "Rückstandsarme Tankentleerung",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_disposal_08"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_disposal_10": {
		"name": "Effiziente Entsorgungszentrale",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_disposal_09",
			"wc_comfort"
		],
		"effect": "Kosten jeder Tankentleerung um weitere 3 % senken.",
		"modifier": "emptying",
		"amount": 0.03
	},
	"wc_economy_01": {
		"name": "Sparsame Verbrauchsartikel",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_logistics"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_02": {
		"name": "Langlebige Türbeschläge",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_economy_01"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_03": {
		"name": "Robuste Lüftungsgitter",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_economy_02"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_04": {
		"name": "Wartungsarme Dachmodule",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_economy_03"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_05": {
		"name": "Bedarfsgerechte Beleuchtung",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_economy_04",
			"sanitation"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_06": {
		"name": "Effiziente Betriebsplanung",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_economy_05"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_07": {
		"name": "Gemeinsame Ersatzteilhaltung",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_economy_06"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_08": {
		"name": "Langlebige Sanitärbauteile",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_economy_07",
			"wc_hygiene"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_09": {
		"name": "Optimierter Materialkreislauf",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_economy_08"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_economy_10": {
		"name": "Ressourcenschonender Dauerbetrieb",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_economy_09",
			"wc_comfort"
		],
		"effect": "Tägliche WC-Betriebskosten um weitere 2,5 % senken.",
		"modifier": "upkeep",
		"amount": 0.025
	},
	"wc_winter_01": {
		"name": "Gedämmte Tankabdeckung",
		"cost": 370,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_winter"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_02": {
		"name": "Geschützte Leitungsführung",
		"cost": 730,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_winter_01"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_03": {
		"name": "Doppelte Bodenisolierung",
		"cost": 1330,
		"points": 1,
		"days": 1,
		"requires": [
			"wc_winter_02"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_04": {
		"name": "Wärmegedämmte Fugen",
		"cost": 2170,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_winter_03"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_05": {
		"name": "Isolierte Entsorgungsventile",
		"cost": 3250,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_winter_04",
			"sanitation"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_06": {
		"name": "Geschützte Außenanschlüsse",
		"cost": 4570,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_winter_05"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_07": {
		"name": "Kältearme Entlüftung",
		"cost": 6130,
		"points": 2,
		"days": 1,
		"requires": [
			"wc_winter_06"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_08": {
		"name": "Winddichter Tankraum",
		"cost": 7930,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_winter_07",
			"wc_hygiene"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_09": {
		"name": "Thermisch getrennte Bodenplatte",
		"cost": 9970,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_winter_08"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	},
	"wc_winter_10": {
		"name": "Alpines Frostschutzsystem",
		"cost": 12250,
		"points": 3,
		"days": 2,
		"requires": [
			"wc_winter_09",
			"wc_comfort"
		],
		"effect": "Zusätzlichen Hygieneverschleiß bei starkem Frost und Kosten der Winterisolierung um weitere 5 % senken.",
		"modifier": "frost",
		"amount": 0.05
	}
}
static func modifiers(researched: Array) -> Dictionary:
	var result:Dictionary={"volume":1.0,"hygiene":1.0,"service":1.0,"aging":1.0,"minutes":1.0,"cleaning":1.0,"emptying":1.0,"upkeep":1.0,"frost":1.0,"construction":1.0}
	for id in researched:
		if not PROJECTS.has(id):continue
		var spec:Dictionary=PROJECTS[id]
		if spec.modifier=="unlock":continue
		result[spec.modifier]+=float(spec.amount)*(1.0 if spec.modifier=="volume" else -1.0)
	return result
