extends RefCounted
## Named building offers, unlocks and deterministic completed-visit sales.
## Every existing building has its own actual baseline and 2+ unlockable
## items or service upgrades. This table does NOT mutate legacy save files.
const Catalog = preload("res://src/core/catalog.gd")
const MAX_LEVEL := 5
const OFFERS := {
	"wc_dixi": [
		{"id":"public_wc","name":"Öffentliche Toilettennutzung","level":1,"price":0,"cost":0,"category":"service","asset":"upgrade-wc_dixi-public_wc"},
		{"id":"extra_crew","name":"Mehr WC-Kapazität","level":2,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_dixi-extra_crew"},
		{"id":"large_tank","name":"Größerer Entsorgungstank","level":3,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_dixi-large_tank"},
		{"id":"hygiene_pack","name":"Verbesserte Hygieneausstattung","level":4,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_dixi-hygiene_pack"},
		{"id":"premium_upkeep","name":"Optimierte Wartungsabläufe","level":5,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_dixi-premium_upkeep"}
	],
	"wc_cabin": [
		{"id":"public_wc","name":"Öffentliche Toilettennutzung","level":1,"price":0,"cost":0,"category":"service","asset":"upgrade-wc_cabin-public_wc"},
		{"id":"extra_crew","name":"Mehr WC-Kapazität","level":2,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_cabin-extra_crew"},
		{"id":"large_tank","name":"Größerer Entsorgungstank","level":3,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_cabin-large_tank"},
		{"id":"hygiene_pack","name":"Verbesserte Hygieneausstattung","level":4,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_cabin-hygiene_pack"},
		{"id":"premium_upkeep","name":"Optimierte Wartungsabläufe","level":5,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_cabin-premium_upkeep"}
	],
	"wc_module": [
		{"id":"public_wc","name":"Öffentliche Toilettennutzung","level":1,"price":0,"cost":0,"category":"service","asset":"upgrade-wc_module-public_wc"},
		{"id":"extra_crew","name":"Mehr WC-Kapazität","level":2,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_module-extra_crew"},
		{"id":"large_tank","name":"Größerer Entsorgungstank","level":3,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_module-large_tank"},
		{"id":"hygiene_pack","name":"Verbesserte Hygieneausstattung","level":4,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_module-hygiene_pack"},
		{"id":"premium_upkeep","name":"Optimierte Wartungsabläufe","level":5,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_module-premium_upkeep"}
	],
	"wc_house": [
		{"id":"public_wc","name":"Öffentliche Toilettennutzung","level":1,"price":0,"cost":0,"category":"service","asset":"upgrade-wc_house-public_wc"},
		{"id":"extra_crew","name":"Mehr WC-Kapazität","level":2,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_house-extra_crew"},
		{"id":"large_tank","name":"Größerer Entsorgungstank","level":3,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_house-large_tank"},
		{"id":"hygiene_pack","name":"Verbesserte Hygieneausstattung","level":4,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_house-hygiene_pack"},
		{"id":"premium_upkeep","name":"Optimierte Wartungsabläufe","level":5,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_house-premium_upkeep"}
	],
	"wc_luxury": [
		{"id":"public_wc","name":"Öffentliche Toilettennutzung","level":1,"price":0,"cost":0,"category":"service","asset":"upgrade-wc_luxury-public_wc"},
		{"id":"extra_crew","name":"Mehr WC-Kapazität","level":2,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_luxury-extra_crew"},
		{"id":"large_tank","name":"Größerer Entsorgungstank","level":3,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_luxury-large_tank"},
		{"id":"hygiene_pack","name":"Verbesserte Hygieneausstattung","level":4,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_luxury-hygiene_pack"},
		{"id":"premium_upkeep","name":"Optimierte Wartungsabläufe","level":5,"price":0,"cost":0,"category":"upgrade","asset":"upgrade-wc_luxury-premium_upkeep"}
	],
	"cocoa": [
		{
			"id": "hot_chocolate",
			"name": "Heiße Schokolade",
			"level": 1,
			"price": 6,
			"cost": 2.2,
			"category": "drink",
			"asset": "upgrade-cocoa-hot_chocolate"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-cocoa-spring_water"
		},
		{
			"id": "chai",
			"name": "Würziger Alpen-Chai",
			"level": 2,
			"price": 7,
			"cost": 2.4,
			"category": "drink",
			"asset": "upgrade-cocoa-chai"
		},
		{
			"id": "cappuccino",
			"name": "Cappuccino",
			"level": 3,
			"price": 7,
			"cost": 1.6,
			"category": "drink",
			"asset": "upgrade-cocoa-cappuccino"
		},
		{
			"id": "mocha",
			"name": "Schoko-Mokka",
			"level": 4,
			"price": 8,
			"cost": 2.1,
			"category": "drink",
			"asset": "upgrade-cocoa-mocha"
		}
	],
	"schmarrn": [
		{
			"id": "kaiserschmarrn",
			"name": "Kaiserschmarrn",
			"level": 1,
			"price": 13,
			"cost": 4.2,
			"category": "food",
			"asset": "upgrade-schmarrn-kaiserschmarrn"
		},
		{
			"id": "coffee",
			"name": "Frischer Kaffee",
			"level": 1,
			"price": 4,
			"cost": 1.2,
			"category": "drink",
			"asset": "upgrade-schmarrn-coffee"
		},
		{
			"id": "churros",
			"name": "Churros",
			"level": 2,
			"price": 9,
			"cost": 2.5,
			"category": "food",
			"asset": "upgrade-schmarrn-churros"
		},
		{
			"id": "donuts",
			"name": "Berg-Donuts",
			"level": 3,
			"price": 6,
			"cost": 1.8,
			"category": "food",
			"asset": "upgrade-schmarrn-donuts"
		},
		{
			"id": "croissant",
			"name": "Frühstücks-Croissant",
			"level": 4,
			"price": 7,
			"cost": 2.2,
			"category": "food",
			"asset": "upgrade-schmarrn-croissant"
		},
		{
			"id": "fruit_juice",
			"name": "Fruchtsaft",
			"level": 4,
			"price": 5,
			"cost": 1.2,
			"category": "drink",
			"asset": "upgrade-schmarrn-fruit_juice"
		},
		{
			"id": "apple_pastry",
			"name": "Apfelgebäck",
			"level": 5,
			"price": 8,
			"cost": 2.6,
			"category": "food",
			"asset": "upgrade-schmarrn-apple_pastry"
		}
	],
	"pizzeria": [
		{
			"id": "margherita",
			"name": "Pizza Margherita",
			"level": 1,
			"price": 15,
			"cost": 4.8,
			"category": "food",
			"asset": "upgrade-pizzeria-margherita"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-pizzeria-spring_water"
		},
		{
			"id": "marinara",
			"name": "Pizza Marinara",
			"level": 2,
			"price": 14,
			"cost": 3.8,
			"category": "food",
			"asset": "upgrade-pizzeria-marinara"
		},
		{
			"id": "soda",
			"name": "Alpenlimonade",
			"level": 2,
			"price": 5,
			"cost": 1.1,
			"category": "drink",
			"asset": "upgrade-pizzeria-soda"
		},
		{
			"id": "pasta",
			"name": "Frische Pasta",
			"level": 3,
			"price": 16,
			"cost": 5,
			"category": "food",
			"asset": "upgrade-pizzeria-pasta"
		},
		{
			"id": "focaccia",
			"name": "Focaccia",
			"level": 4,
			"price": 10,
			"cost": 3,
			"category": "food",
			"asset": "upgrade-pizzeria-focaccia"
		},
		{
			"id": "gelato",
			"name": "Gelato",
			"level": 5,
			"price": 7,
			"cost": 2.1,
			"category": "food",
			"asset": "upgrade-pizzeria-gelato"
		}
	],
	"repair_office": [
		{
			"id": "repair",
			"name": "Lift- und Anlagenreparatur",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-repair_office-repair"
		},
		{
			"id": "stock",
			"name": "Ersatzteillager",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-repair_office-stock"
		},
		{
			"id": "diagnostics",
			"name": "Frühdiagnose",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-repair_office-diagnostics"
		},
		{
			"id": "training",
			"name": "Elektriker-Fortbildung",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-repair_office-training"
		},
		{
			"id": "response",
			"name": "Mobiler Sofortdienst",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-repair_office-response"
		}
	],
	"disco": [
		{
			"id": "dance",
			"name": "Après-Ski-Tanzfläche",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-disco-dance"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-disco-spring_water"
		},
		{
			"id": "soda",
			"name": "Gipfellimonade",
			"level": 2,
			"price": 6,
			"cost": 1.2,
			"category": "drink",
			"asset": "upgrade-disco-soda"
		},
		{
			"id": "mocktail",
			"name": "Berg-Mocktail",
			"level": 3,
			"price": 8,
			"cost": 2.2,
			"category": "drink",
			"asset": "upgrade-disco-mocktail"
		},
		{
			"id": "dj",
			"name": "Live-DJ-Bühne",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-disco-dj"
		},
		{
			"id": "late_snack",
			"name": "Mitternachts-Snack",
			"level": 5,
			"price": 10,
			"cost": 3.5,
			"category": "food",
			"asset": "upgrade-disco-late_snack"
		}
	],
	"pool": [
		{
			"id": "pool_entry",
			"name": "Schwimmen im Außenpool",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-pool-pool_entry"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-pool-spring_water"
		},
		{
			"id": "hot_drink",
			"name": "Warmer Kräutertee",
			"level": 2,
			"price": 5,
			"cost": 1.2,
			"category": "drink",
			"asset": "upgrade-pool-hot_drink"
		},
		{
			"id": "family",
			"name": "Familien-Beckenzeit",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-pool-family"
		},
		{
			"id": "heated",
			"name": "Energiespar-Wärmetechnik",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-pool-heated"
		}
	],
	"kiosk": [
		{
			"id": "punsch",
			"name": "Warmer Punsch",
			"level": 1,
			"price": 6,
			"cost": 1.8,
			"category": "drink",
			"asset": "upgrade-kiosk-punsch"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-kiosk-spring_water"
		},
		{
			"id": "pretzel",
			"name": "Brezel",
			"level": 2,
			"price": 5,
			"cost": 1.5,
			"category": "food",
			"asset": "upgrade-kiosk-pretzel"
		},
		{
			"id": "apple_juice",
			"name": "Heißer Apfelsaft",
			"level": 3,
			"price": 6,
			"cost": 1.9,
			"category": "drink",
			"asset": "upgrade-kiosk-apple_juice"
		},
		{
			"id": "waffle",
			"name": "Waffel",
			"level": 4,
			"price": 8,
			"cost": 2.6,
			"category": "food",
			"asset": "upgrade-kiosk-waffle"
		},
		{
			"id": "soup",
			"name": "Tagessuppe",
			"level": 5,
			"price": 9,
			"cost": 3.3,
			"category": "food",
			"asset": "upgrade-kiosk-soup"
		}
	],
	"viewpoint": [
		{
			"id": "panorama",
			"name": "Aussichtsplattform",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-viewpoint-panorama"
		},
		{
			"id": "binoculars",
			"name": "Fernrohr",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-viewpoint-binoculars"
		},
		{
			"id": "photo_spot",
			"name": "Fotopunkt",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-viewpoint-photo_spot"
		},
		{
			"id": "winter_guide",
			"name": "Naturführer",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-viewpoint-winter_guide"
		}
	],
	"shelter": [
		{
			"id": "warmth",
			"name": "Kostenloser Wärmeunterstand",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-shelter-warmth"
		},
		{
			"id": "bench",
			"name": "Zusätzliche Sitzbank",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-shelter-bench"
		},
		{
			"id": "heating",
			"name": "Sichere Warmluft",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-shelter-heating"
		},
		{
			"id": "medical",
			"name": "Erste-Hilfe-Set",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-shelter-medical"
		}
	],
	"snowpark": [
		{
			"id": "beginner",
			"name": "Anfänger-Snowpark",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-snowpark-beginner"
		},
		{
			"id": "rails",
			"name": "Rail-Einweisung",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-snowpark-rails"
		},
		{
			"id": "jump",
			"name": "Sprungtraining",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-snowpark-jump"
		},
		{
			"id": "coach",
			"name": "Snowpark-Coach",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-snowpark-coach"
		},
		{
			"id": "contest",
			"name": "Freestyle-Event",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "event",
			"asset": "upgrade-snowpark-contest"
		}
	],
	"spa": [
		{
			"id": "spa_access",
			"name": "Spa-Aufenthalt",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-spa-spa_access"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-spa-spring_water"
		},
		{
			"id": "herbal",
			"name": "Kräutertee",
			"level": 2,
			"price": 5,
			"cost": 1,
			"category": "drink",
			"asset": "upgrade-spa-herbal"
		},
		{
			"id": "sauna",
			"name": "Saunaprogramm",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-spa-sauna"
		},
		{
			"id": "massage",
			"name": "Massage",
			"level": 4,
			"price": 38,
			"cost": 11,
			"category": "service",
			"asset": "upgrade-spa-massage"
		},
		{
			"id": "premium",
			"name": "Premium-Wellness",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-spa-premium"
		}
	],
	"bus": [
		{
			"id": "transport",
			"name": "Skibus-Anbindung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-bus-transport"
		},
		{
			"id": "schedule",
			"name": "Live-Abfahrtsanzeige",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-bus-schedule"
		},
		{
			"id": "shelter",
			"name": "Beheizte Wartehalle",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-bus-shelter"
		},
		{
			"id": "shuttle",
			"name": "Zusätzlicher Shuttle",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-bus-shuttle"
		},
		{
			"id": "electric",
			"name": "Elektrobus",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-bus-electric"
		}
	],
	"lodge": [
		{
			"id": "warm_lodge",
			"name": "Warme Berghütte",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-lodge-warm_lodge"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-lodge-spring_water"
		},
		{
			"id": "soup",
			"name": "Bergsuppe",
			"level": 2,
			"price": 9,
			"cost": 3,
			"category": "food",
			"asset": "upgrade-lodge-soup"
		},
		{
			"id": "hot_chocolate",
			"name": "Heiße Schokolade",
			"level": 3,
			"price": 6,
			"cost": 2,
			"category": "drink",
			"asset": "upgrade-lodge-hot_chocolate"
		},
		{
			"id": "family_table",
			"name": "Familientisch",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-lodge-family_table"
		}
	],
	"restaurant": [
		{
			"id": "alpine_menu",
			"name": "Alpines Tagesgericht",
			"level": 1,
			"price": 16,
			"cost": 5.4,
			"category": "food",
			"asset": "upgrade-restaurant-alpine_menu"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-restaurant-spring_water"
		},
		{
			"id": "pasta",
			"name": "Pasta des Hauses",
			"level": 2,
			"price": 15,
			"cost": 5,
			"category": "food",
			"asset": "upgrade-restaurant-pasta"
		},
		{
			"id": "apple_juice",
			"name": "Apfelsaft",
			"level": 2,
			"price": 5,
			"cost": 1.2,
			"category": "drink",
			"asset": "upgrade-restaurant-apple_juice"
		},
		{
			"id": "soup",
			"name": "Bergsuppe",
			"level": 3,
			"price": 9,
			"cost": 3,
			"category": "food",
			"asset": "upgrade-restaurant-soup"
		},
		{
			"id": "dessert",
			"name": "Alpendessert",
			"level": 4,
			"price": 8,
			"cost": 2.2,
			"category": "food",
			"asset": "upgrade-restaurant-dessert"
		},
		{
			"id": "chef",
			"name": "Chefmenü",
			"level": 5,
			"price": 28,
			"cost": 10,
			"category": "food",
			"asset": "upgrade-restaurant-chef"
		}
	],
	"rental": [
		{
			"id": "rental",
			"name": "Skiausrüstung ausleihen",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "rental",
			"asset": "upgrade-rental-rental"
		},
		{
			"id": "helmet",
			"name": "Schutzhelme",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "rental",
			"asset": "upgrade-rental-helmet"
		},
		{
			"id": "snowboard",
			"name": "Snowboardverleih",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "rental",
			"asset": "upgrade-rental-snowboard"
		},
		{
			"id": "snowblade",
			"name": "Snowblade-Verleih",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "rental",
			"asset": "upgrade-rental-snowblade"
		},
		{
			"id": "workshop",
			"name": "Ski-Servicewerkstatt",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-rental-workshop"
		}
	],
	"school": [
		{
			"id": "beginners",
			"name": "Skischule · Anfängerkurs",
			"level": 1,
			"price": 25,
			"cost": 8,
			"category": "training",
			"asset": "upgrade-school-beginners"
		},
		{
			"id": "safety",
			"name": "Sicherheitseinweisung",
			"level": 2,
			"price": 15,
			"cost": 5,
			"category": "training",
			"asset": "upgrade-school-safety"
		},
		{
			"id": "children",
			"name": "Kinderskischule",
			"level": 2,
			"price": 32,
			"cost": 11,
			"category": "training",
			"asset": "upgrade-school-children"
		},
		{
			"id": "snowboard",
			"name": "Snowboardkurs",
			"level": 3,
			"price": 38,
			"cost": 13,
			"category": "training",
			"asset": "upgrade-school-snowboard"
		},
		{
			"id": "carving",
			"name": "Carvingkurs",
			"level": 4,
			"price": 44,
			"cost": 15,
			"category": "training",
			"asset": "upgrade-school-carving"
		},
		{
			"id": "freeride",
			"name": "Freeride und Lawinenkunde",
			"level": 5,
			"price": 55,
			"cost": 20,
			"category": "training",
			"asset": "upgrade-school-freeride"
		}
	],
	"snowmaker": [
		{
			"id": "snow",
			"name": "Grundbeschneiung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-snowmaker-snow"
		},
		{
			"id": "nozzles",
			"name": "Präzisionsdüsen",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-snowmaker-nozzles"
		},
		{
			"id": "weather",
			"name": "Temperaturautomatik",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-snowmaker-weather"
		},
		{
			"id": "water",
			"name": "Wassersparmodus",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-snowmaker-water"
		},
		{
			"id": "network",
			"name": "Vernetzte Beschneiung",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-snowmaker-network"
		}
	],
	"maintenance": [
		{
			"id": "grooming",
			"name": "Pistenraupen-Präparierung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-maintenance-grooming"
		},
		{
			"id": "blade",
			"name": "Räumschild-Upgrade",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-maintenance-blade"
		},
		{
			"id": "tracks",
			"name": "Winterketten und Fahrwerk",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-maintenance-tracks"
		},
		{
			"id": "winch",
			"name": "Pistenraupen-Winde",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-maintenance-winch"
		},
		{
			"id": "sensors",
			"name": "Schneehöhensensor und LED-Licht",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-maintenance-sensors"
		}
	],
	"hotel": [
		{
			"id": "bed",
			"name": "Berghotel-Übernachtung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-hotel-bed"
		},
		{
			"id": "breakfast",
			"name": "Frühstücksbuffet",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-hotel-breakfast"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-hotel-spring_water"
		},
		{
			"id": "lounge",
			"name": "Hotel-Lounge",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-hotel-lounge"
		},
		{
			"id": "room_service",
			"name": "Zimmerservice",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-hotel-room_service"
		},
		{
			"id": "suite",
			"name": "Panoramasuite",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-hotel-suite"
		}
	],
	"cabin": [
		{
			"id": "stay",
			"name": "Ferienhütten-Übernachtung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-cabin-stay"
		},
		{
			"id": "tea",
			"name": "Tee-Set",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-cabin-tea"
		},
		{
			"id": "ski_rack",
			"name": "Skiständer",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-cabin-ski_rack"
		},
		{
			"id": "breakfast_box",
			"name": "Frühstückspaket",
			"level": 4,
			"price": 8,
			"cost": 3,
			"category": "food",
			"asset": "upgrade-cabin-breakfast_box"
		}
	],
	"apartment": [
		{
			"id": "stay",
			"name": "Ferienwohnung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-apartment-stay"
		},
		{
			"id": "kitchen",
			"name": "Kleine Küchenzeile",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-apartment-kitchen"
		},
		{
			"id": "ski_rack",
			"name": "Skischrank",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-apartment-ski_rack"
		},
		{
			"id": "breakfast_box",
			"name": "Frühstücksbox",
			"level": 4,
			"price": 8,
			"cost": 3,
			"category": "food",
			"asset": "upgrade-apartment-breakfast_box"
		}
	],
	"chalet": [
		{
			"id": "stay",
			"name": "Alpenchalet-Übernachtung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-chalet-stay"
		},
		{
			"id": "fireplace",
			"name": "Kamin-Ecke",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-chalet-fireplace"
		},
		{
			"id": "breakfast",
			"name": "Frühstücksservice",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-chalet-breakfast"
		},
		{
			"id": "suite",
			"name": "Premium-Zimmer",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-chalet-suite"
		}
	],
	"guesthouse": [
		{
			"id": "stay",
			"name": "Alpenpension mit Frühstück",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-guesthouse-stay"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-guesthouse-spring_water"
		},
		{
			"id": "buffet",
			"name": "Großes Frühstücksbuffet",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-guesthouse-buffet"
		},
		{
			"id": "terrace",
			"name": "Terrasse",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-guesthouse-terrace"
		},
		{
			"id": "family",
			"name": "Familienzimmer",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-guesthouse-family"
		}
	],
	"grand_hotel": [
		{
			"id": "stay",
			"name": "Grandhotel-Übernachtung",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "lodging",
			"asset": "upgrade-grand_hotel-stay"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-grand_hotel-spring_water"
		},
		{
			"id": "breakfast",
			"name": "Frühstücksrestaurant",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-grand_hotel-breakfast"
		},
		{
			"id": "concierge",
			"name": "Concierge",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-grand_hotel-concierge"
		},
		{
			"id": "room_service",
			"name": "Zimmerservice",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-grand_hotel-room_service"
		},
		{
			"id": "suite",
			"name": "Luxus-Suite",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-grand_hotel-suite"
		}
	],
	"bar": [
		{
			"id": "lounge",
			"name": "Alpenbar-Ausschank",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-bar-lounge"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-bar-spring_water"
		},
		{
			"id": "mocktail",
			"name": "Gipfel-Mocktail",
			"level": 2,
			"price": 8,
			"cost": 2.2,
			"category": "drink",
			"asset": "upgrade-bar-mocktail"
		},
		{
			"id": "tea",
			"name": "Heißer Kräutertee",
			"level": 3,
			"price": 5,
			"cost": 1,
			"category": "drink",
			"asset": "upgrade-bar-tea"
		},
		{
			"id": "snack",
			"name": "Salzgebäck",
			"level": 4,
			"price": 6,
			"cost": 2,
			"category": "food",
			"asset": "upgrade-bar-snack"
		},
		{
			"id": "premium",
			"name": "Premium-Lounge",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-bar-premium"
		}
	],
	"fitness": [
		{
			"id": "workout",
			"name": "Bergfitness",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-fitness-workout"
		},
		{
			"id": "spring_water",
			"name": "Alpenquellwasser",
			"level": 1,
			"price": 3,
			"cost": 0.6,
			"category": "drink",
			"asset": "upgrade-fitness-spring_water"
		},
		{
			"id": "coach",
			"name": "Trainingsberatung",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-fitness-coach"
		},
		{
			"id": "stretch",
			"name": "Stretching-Kurs",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-fitness-stretch"
		},
		{
			"id": "recovery",
			"name": "Regenerationsraum",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-fitness-recovery"
		}
	],
	"souvenir": [
		{
			"id": "postcard",
			"name": "Alpenpostkarte",
			"level": 1,
			"price": 6,
			"cost": 1.8,
			"category": "retail",
			"asset": "upgrade-souvenir-postcard"
		},
		{
			"id": "snowglobe",
			"name": "Schneekugel",
			"level": 2,
			"price": 13,
			"cost": 4,
			"category": "retail",
			"asset": "upgrade-souvenir-snowglobe"
		},
		{
			"id": "bell",
			"name": "Kuhglocke",
			"level": 3,
			"price": 19,
			"cost": 6,
			"category": "retail",
			"asset": "upgrade-souvenir-bell"
		},
		{
			"id": "carving",
			"name": "Schnitzerei",
			"level": 4,
			"price": 28,
			"cost": 9,
			"category": "retail",
			"asset": "upgrade-souvenir-carving"
		}
	],
	"watchmaker": [
		{
			"id": "clock_repair",
			"name": "Uhrenreparatur",
			"level": 1,
			"price": 30,
			"cost": 10,
			"category": "service",
			"asset": "upgrade-watchmaker-clock_repair"
		},
		{
			"id": "watchband",
			"name": "Uhrenarmband",
			"level": 2,
			"price": 20,
			"cost": 7,
			"category": "retail",
			"asset": "upgrade-watchmaker-watchband"
		},
		{
			"id": "pocketwatch",
			"name": "Taschenuhr",
			"level": 3,
			"price": 55,
			"cost": 21,
			"category": "retail",
			"asset": "upgrade-watchmaker-pocketwatch"
		},
		{
			"id": "clock",
			"name": "Alpine Wanduhr",
			"level": 4,
			"price": 75,
			"cost": 29,
			"category": "retail",
			"asset": "upgrade-watchmaker-clock"
		}
	],
	"craftshop": [
		{
			"id": "carving",
			"name": "Holzschnitzerei",
			"level": 1,
			"price": 15,
			"cost": 4.5,
			"category": "retail",
			"asset": "upgrade-craftshop-carving"
		},
		{
			"id": "bell",
			"name": "Bergglocke",
			"level": 2,
			"price": 20,
			"cost": 6,
			"category": "retail",
			"asset": "upgrade-craftshop-bell"
		},
		{
			"id": "toy",
			"name": "Holzspielzeug",
			"level": 3,
			"price": 22,
			"cost": 7,
			"category": "retail",
			"asset": "upgrade-craftshop-toy"
		},
		{
			"id": "design",
			"name": "Design-Handwerk",
			"level": 4,
			"price": 40,
			"cost": 14,
			"category": "retail",
			"asset": "upgrade-craftshop-design"
		}
	],
	"printing_press": [
		{
			"id": "newspaper",
			"name": "Resort-Zeitung drucken",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-printing_press-newspaper"
		},
		{
			"id": "colour",
			"name": "Farbdruck",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-printing_press-colour"
		},
		{
			"id": "radio_ads",
			"name": "Radio-Anzeigen",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-printing_press-radio_ads"
		},
		{
			"id": "edition",
			"name": "Sonderausgabe",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-printing_press-edition"
		}
	],
	"newsstand": [
		{
			"id": "newspaper",
			"name": "Alpenzeitung",
			"level": 1,
			"price": 5,
			"cost": 1.5,
			"category": "retail",
			"asset": "upgrade-newsstand-newspaper"
		},
		{
			"id": "postcard",
			"name": "Alpenpostkarte",
			"level": 2,
			"price": 6,
			"cost": 1.8,
			"category": "retail",
			"asset": "upgrade-newsstand-postcard"
		},
		{
			"id": "map",
			"name": "Pistenkarte",
			"level": 3,
			"price": 8,
			"cost": 2.5,
			"category": "retail",
			"asset": "upgrade-newsstand-map"
		},
		{
			"id": "book",
			"name": "Ski-Freizeitmagazin",
			"level": 4,
			"price": 10,
			"cost": 3.2,
			"category": "retail",
			"asset": "upgrade-newsstand-book"
		}
	],
	"town_hall": [
		{
			"id": "office",
			"name": "Rathaus und Ortschronik",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-town_hall-office"
		},
		{
			"id": "advisory",
			"name": "Resort-Beratung",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-town_hall-advisory"
		},
		{
			"id": "planning",
			"name": "Verkehrs- und Bauplan",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "service",
			"asset": "upgrade-town_hall-planning"
		},
		{
			"id": "events",
			"name": "Festtag- und Bürgerplanung",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "event",
			"asset": "upgrade-town_hall-events"
		}
	],
	"first_aid": [
		{
			"id": "rescue",
			"name": "Bergwacht und Ersthilfe",
			"level": 1,
			"price": 0,
			"cost": 0,
			"category": "rescue",
			"asset": "upgrade-first_aid-rescue"
		},
		{
			"id": "first_aid_training",
			"name": "Erste-Hilfe-Kurs",
			"level": 2,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-first_aid-first_aid_training"
		},
		{
			"id": "sled",
			"name": "Rettungsschlitten",
			"level": 3,
			"price": 0,
			"cost": 0,
			"category": "upgrade",
			"asset": "upgrade-first_aid-sled"
		},
		{
			"id": "evacuation",
			"name": "Lift-Evakuierung",
			"level": 4,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-first_aid-evacuation"
		},
		{
			"id": "avalanche",
			"name": "Winterrettung und Lawinenkunde",
			"level": 5,
			"price": 0,
			"cost": 0,
			"category": "training",
			"asset": "upgrade-first_aid-avalanche"
		}
	]
}
 
static func all_for(kind: String) -> Array:
	return (OFFERS.get(kind, []) as Array).duplicate(true)

static func active(kind: String, level: int) -> Array:
	var result: Array = []
	for item in OFFERS.get(kind, []):
		if int(item.level) <= clampi(level, 1, MAX_LEVEL):
			result.append(item.duplicate(true))
	return result

static func locked(kind: String, level: int) -> Array:
	var result: Array = []
	for item in OFFERS.get(kind, []):
		if int(item.level) > clampi(level, 1, MAX_LEVEL):
			result.append(item.duplicate(true))
	return result

static func sale_margin(item: Dictionary) -> float:
	return float(item.get("price", 0.0)) - float(item.get("cost", 0.0))

static func price_report(kind: String, level: int) -> Dictionary:
	var turnover := 0.0
	var direct_cost := 0.0
	var sellable := 0
	for item in active(kind, level):
		if float(item.price) <= 0.0: continue
		turnover += float(item.price)
		direct_cost += float(item.cost)
		sellable += 1
	return {"sample_turnover": turnover, "sample_cost": direct_cost,
		"sample_margin": turnover - direct_cost, "products": sellable}
 
static func valid_catalog() -> bool:
	if OFFERS.size() != Catalog.BUILDINGS.size(): return false
	for kind in Catalog.BUILDINGS:
		if not OFFERS.has(kind): return false
		var entries: Array = OFFERS[kind]
		if entries.size() < 3: return false
		var seen: Dictionary = {}
		var has_base := false
		for item in entries:
			if not item is Dictionary: return false
			if str(item.get("id", "")).is_empty() or seen.has(item.id): return false
			seen[item.id] = true
			if int(item.get("level", -1)) == 1: has_base = true
			if int(item.get("level", -1)) < 1 or int(item.level) > MAX_LEVEL: return false
			if not item.get("name") is String or str(item.name).is_empty(): return false
			if not item.get("asset") is String or str(item.asset).is_empty(): return false
			if not (item.price is float or item.price is int): return false
			if not (item.cost is float or item.cost is int): return false
			if float(item.price) < 0.0 or float(item.cost) < 0.0 or sale_margin(item) < 0.0: return false
		if not has_base: return false
	return true

## One bought product per completed service visit and visitor. Free services,
## training, upgrades and rooms keep their own existing operational models.
const RETAIL_KINDS := ["cocoa", "schmarrn", "restaurant", "kiosk", "bar", "disco", "souvenir", "watchmaker", "craftshop"]

static func visit_sale(building: Dictionary, guest: Dictionary) -> Dictionary:
	if str(building.get("kind", "")) not in RETAIL_KINDS: return {}
	var choices: Array = active(str(building.kind), int(building.get("level", 1))).filter(
		func(offer): return str(offer.category) in ["food", "drink", "retail"] and float(offer.price) > 0.0)
	if choices.is_empty(): return {}
	var index: int = posmod(int(guest.get("id", 0)) + int(building.get("visits", 0)), choices.size())
	var offer: Dictionary = choices[index]
	var quantity: int = clampi(int(guest.get("group_size", 1)), 1, 20)
	return {"id":str(offer.id), "name":str(offer.name), "quantity":quantity,
		"revenue":snappedf(float(offer.price) * quantity, 0.01),
		"cost":snappedf(float(offer.cost) * quantity, 0.01)}

static func record_sale(building: Dictionary, sale: Dictionary) -> void:
	if sale.is_empty(): return
	var ledger: Dictionary = building.get("product_sales", {})
	var item: Dictionary = ledger.get(str(sale.id), {"quantity":0, "revenue":0.0, "cost":0.0})
	item.quantity = int(item.quantity) + int(sale.quantity)
	item.revenue = snappedf(float(item.revenue) + float(sale.revenue), 0.01)
	item.cost = snappedf(float(item.cost) + float(sale.cost), 0.01)
	ledger[str(sale.id)] = item
	building.product_sales = ledger

static func valid_sales(building: Dictionary) -> bool:
	if not building.has("product_sales"): return true
	if not building.product_sales is Dictionary: return false
	var known: Array = all_for(str(building.get("kind", ""))).map(func(offer): return str(offer.id))
	# Custom pizzas use one stable ledger entry while the recipe names remain
	# in the backwards-compatible pizza_menu. Recipes may be renamed later.
	if str(building.get("kind", "")) == "pizzeria": known.append("pizza")
	if building.product_sales.size() > known.size(): return false
	for id in building.product_sales:
		if not id is String or id not in known: return false
		var item: Variant = building.product_sales[id]
		if not item is Dictionary or item.size() != 3: return false
		for key in ["quantity", "revenue", "cost"]:
			if not item.get(key) is float and not item.get(key) is int: return false
			if not is_finite(float(item[key])) or float(item[key]) < 0 or float(item[key]) > 100000000000.0: return false
		if float(item.quantity) != floorf(float(item.quantity)): return false
	return true
