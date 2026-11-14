extends RefCounted
## One batched notice per newly earned set; no financial or saved state changes.
const Goals = preload("res://src/core/long_goals_042.gd")
const L = preload("res://src/core/i18n.gd")
var _model_id := 0
var _campaign: Dictionary = {}
var _seen: Dictionary = {}

func collect(model: RefCounted) -> Array:
	if _model_id != model.get_instance_id() or not is_same(_campaign, model.campaign):
		_model_id = model.get_instance_id()
		_campaign = model.campaign
		_seen.clear()
	var newly_ready: Array = []
	for id in Goals.pending(model):
		if not _seen.has(id):
			_seen[id] = true
			newly_ready.append(id)
	if newly_ready.is_empty(): return []
	var title: String = L.text(str(Goals.SPECS[newly_ready[0]].name)) if newly_ready.size() == 1 else L.text("%d Langzeitziele erreicht") % newly_ready.size()
	var detail: String = L.text("Im Resort-Büro unter Ziele abschließen.")
	if model.campaign.get("mode", "") == "career":
		detail = L.text("%d € verfügbar · Im Resort-Büro unter Ziele abholen.") % Goals.pending_reward(model)
	# No reward field: this announces eligibility, never an imaginary payout.
	return [{"kind":"goal", "title":title, "detail":detail}]
