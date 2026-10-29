extends RefCounted
## Editorial concepts only. These DO NOT claim the named resorts have real problems.
## Never present a template as playable until a separately licensed, validated map
## and the corresponding full piste/lift inventory have been imported.
const REAL_RESORT_TEMPLATES := [
	{
		"id": "filzmoos",
		"name": "Filzmoos",
		"title_de": "Filzmoos – Der Morgenansturm",
		"title_en": "Filzmoos – Morning Rush",
		"premise_de": "Fiktives Planspiel: Die Gäste verteilen sich ungünstig auf die Talanschlüsse. Entlaste die Warteschlangen, ohne Einsteiger abzuhängen.",
		"premise_en": "Fictional challenge: Guests concentrate at the valley access lifts. Reduce queues while keeping beginner routes accessible.",
		"data_status": "pending_licensed_import",
		"objectives": [
			{"key": "max_wait_minutes", "direction": "at_most", "target": 8.0},
			{"key": "reachable_pistes", "direction": "at_least", "target": 4.0},
			{"key": "reputation", "direction": "at_least", "target": 65.0}
		]
	},
	{
		"id": "seiser_alm",
		"name": "Seiser Alm",
		"title_de": "Seiser Alm – Verbindungen im Hochplateau",
		"title_en": "Seiser Alm – Plateau Connections",
		"premise_de": "Fiktives Planspiel: Starke Spitzenlast an einer Verbindungsachse. Verbessere Umstiege, Verteilung und Pistenanschlüsse.",
		"premise_en": "Fictional challenge: Peak traffic overburdens a connecting corridor. Improve transfers and the distribution of skiers.",
		"data_status": "pending_licensed_import",
		"objectives": [
			{"key": "bottlenecks", "direction": "at_most", "target": 0.0},
			{"key": "queue_weighted_wait_minutes", "direction": "at_most", "target": 6.0},
			{"key": "reputation", "direction": "at_least", "target": 70.0}
		]
	},
	{
		"id": "kitzbuehel",
		"name": "Kitzbühel",
		"title_de": "Kitzbühel – Der Verbindungstest",
		"title_en": "Kitzbühel – The Connection Test",
		"premise_de": "Fiktives Planspiel: Ein simuliertes Verkehrsereignis belastet zentrale Liftverbindungen. Schaffe Alternativen und halte die Wartezeiten niedrig.",
		"premise_en": "Fictional challenge: A simulated traffic incident stresses the main lift connections. Add alternatives and reduce queues.",
		"data_status": "pending_licensed_import",
		"objectives": [
			{"key": "max_wait_minutes", "direction": "at_most", "target": 10.0},
			{"key": "bottlenecks", "direction": "at_most", "target": 1.0},
			{"key": "reputation", "direction": "at_least", "target": 75.0}
		]
	}
]

static func specs() -> Array:
	return REAL_RESORT_TEMPLATES.duplicate(true)

static func spec(id: String) -> Dictionary:
	for entry in REAL_RESORT_TEMPLATES:
		if entry.id == id:
			return entry.duplicate(true)
	return {}

static func playable(id: String) -> bool:
	# No true-to-life terrain or approved piste/lift inventory is bundled yet.
	# Must only become true after verifying external data provenance and coverage.
	var entry := spec(id)
	return not entry.is_empty() and entry.data_status == "validated_import"
