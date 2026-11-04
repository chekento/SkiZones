extends RefCounted
## New-career financial challenge only. Existing saves never change tier.
## Each profile supplies a deliberately distinct starting liquidity buffer.
const LEVELS := [
	{"id":"survival","name":"Existenzkampf","money":25000,"reputation":38.0,"parts":1,"description":"Ein funktionierender Starterberg, aber kaum Reserven. Jeder Kredit und Auftrag zählt."},
	{"id":"thrifty","name":"Knappes Budget","money":85000,"reputation":43.0,"parts":2,"description":"Kleine Rücklage, behutsame Investitionen und frühe Einnahmen sind entscheidend."},
	{"id":"balanced","name":"Ausgewogen","money":190000,"reputation":48.0,"parts":3,"description":"Genug Kapital für den behutsamen Ausbau – der Standard für eine neue Karriere."},
	{"id":"prosperous","name":"Wohlhabend","money":390000,"reputation":57.0,"parts":5,"description":"Großer Handlungsspielraum für Personal, neue Pisten und Pistenraupen."},
	{"id":"patron","name":"Großinvestor","money":850000,"reputation":67.0,"parts":8,"description":"Üppiges Startkapital und ein guter Ruf. Konzentriere dich auf große Ausbaupläne."}
]

static func choice(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]

static func apply(model: RefCounted, index: int) -> void:
	var tier: Dictionary = choice(index)
	if model.campaign.get("mode", "career") != "career": return
	if model.map_id not in preload("res://src/core/maps.gd").FANTASY_MAPS: return
	model.money = float(tier.money)
	model.reputation = float(tier.reputation)
	model.operations.parts = int(tier.parts)
	model.campaign["starting_tier"] = clampi(index, 0, LEVELS.size() - 1)
	model._operational_change()
