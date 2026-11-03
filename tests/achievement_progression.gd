extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Progression = preload("res://src/core/progression.gd")
const Book = preload("res://src/core/achievement_book.gd")
const Sponsorship = preload("res://src/core/sponsorship.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, explanation: String) -> void:
	if ok:
		passed += 1
		print("PASS ",explanation)
	else:
		failed += 1
		push_error("FAIL "+explanation)

func run() -> void:
	check(Book.TRACKS.size() == 20 and Book.TIERS == 50 and Book.TOTAL == 1000,
		"The book contains 1000 individually addressable achievements")
	var unique := {}
	for id in range(Book.START_ID,Book.START_ID+Book.TOTAL):
		var a: Dictionary = Book.entry(id)
		unique[a.id] = true
		check(a.tier >= 1 and a.tier <= 50 and a.reward > 0 and Book.target(a.track,a.tier) > 0,
			"Achievement %d has a valid target and reward" % id)
	check(unique.size() == 1000 and Book.entry(1004).is_empty(),
		"No missing or duplicate IDs and legacy IDs remain reserved")
	for track in range(Book.TRACKS.size()):
		for tier in range(2,Book.TIERS+1):
			check(Book.target(track,tier)>Book.target(track,tier-1),
				"Targets increase across track %d tier %d" % [track,tier])
	check(Book.mastery_for_xp(0) == 1 and Book.mastery_for_xp(Book.xp_for_rank(500)) == 500,
		"Mastery spans exactly ranks 1 through 500")
	for rank in range(2,501):
		check(Book.xp_for_rank(rank)>Book.xp_for_rank(rank-1) and Book.mastery_for_xp(Book.xp_for_rank(rank)) == rank,
			"Rank %d has a distinct, attainable threshold" % rank)
	check(Progression.construction_xp("lift") > Progression.construction_xp("building") and
		Progression.construction_xp("piste") > Progression.construction_xp("piste",true) and
		Progression.construction_xp("unknown") == 0,
		"Constructing useful new lifts and pistes grants more XP than cosmetic remodeling")
	var model := Resort.new()
	model.new_game(true)
	var initial: int = model.achievements.size()
	Book.unlock(model)
	check(model.achievements.size() > initial, "Built starter assets unlock actual starter milestones")
	var count: int = model.achievements.size()
	var cash: float = model.money
	var rewards: float = model.report.rewards
	Book.unlock(model)
	check(model.achievements.size() == count and model.money == cash and model.report.rewards == rewards,
		"Repeated progression checks do not double-pay achievements")
	var copy := Resort.new()
	copy.new_game(false)
	var data: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(copy.restore(data).ok and copy.achievements == model.achievements,
		"New milestones survive exact save/load round trips")
	var legacy := model.snapshot()
	legacy.achievements = [0,1]
	legacy.campaign.erase("mastery_rank")
	var migrated := Resort.new()
	migrated.new_game(false)
	check(migrated.restore(legacy).ok and migrated.achievements == [0,1],
		"Old four-achievement saves migrate without injecting fake earned milestones")
	var false_id := model.snapshot()
	false_id.achievements.append(1004)
	check(not copy.restore(false_id).ok,"Unknown achievement IDs cannot corrupt saves")
	var duplicate := model.snapshot()
	duplicate.achievements.append(duplicate.achievements[0])
	check(not copy.restore(duplicate).ok,"Duplicate achievement IDs cannot corrupt saves")
	var current_xp: float = model.campaign.xp
	model.campaign.xp = Book.xp_for_rank(20)
	Progression.refresh(model)
	check(int(model.campaign.mastery_rank) == 20 and model.campaign.xp == Book.xp_for_rank(20),
		"Experience raises mastery rank without consuming XP")
	check(model.recent_unlocks.any(func(event): return event.kind == "rank"),
		"Mastery promotion emits a live UI event")
	check(model.campaign.rank >= 1 and model.campaign.rank <= 5,
		"Mastery preserves all five original career-star gates")
	model.campaign.xp = current_xp
	var sponsor_model := Resort.new()
	sponsor_model.new_game(true)
	check(Sponsorship.check(sponsor_model,"winter_cocoa").ok,
		"A starter resort can affordably enter regional sponsorship")
	var signed := Sponsorship.sign(sponsor_model,"winter_cocoa")
	check(signed.ok and not Sponsorship.sign(sponsor_model,"winter_cocoa").ok,
		"Only one seven-day sponsor contract may be active")
	var sponsor_cash: float = sponsor_model.money
	var first_reward: float = Sponsorship.daily_reward(sponsor_model)
	check(first_reward > 0 and sponsor_model.money == sponsor_cash+first_reward,
		"An active lift generates a clear sponsor payment")
	check(Sponsorship.daily_reward(sponsor_model) == 0 and sponsor_model.money == sponsor_cash+first_reward,
		"Recalculating one day cannot double-pay sponsorship")
	var saved_sponsor: Dictionary = sponsor_model.snapshot()
	var sponsor_copy := Resort.new()
	sponsor_copy.new_game(false)
	check(sponsor_copy.restore(saved_sponsor).ok and
		Sponsorship.daily_reward(sponsor_copy) == 0,
		"Paid sponsorship state survives saves without duplicate income")
	sponsor_model.day += Sponsorship.CONTRACT_DAYS
	check(Sponsorship.daily_reward(sponsor_model) == 0 and Sponsorship.check(sponsor_model,"alpine_craft").ok == false,
		"An expired sponsor cannot pay beyond the seventh business day")
	var corrupted := sponsor_copy.snapshot()
	corrupted.campaign.sponsor.end = -1
	check(not sponsor_copy.restore(corrupted).ok,
		"Invalid or forged sponsor agreements are rejected")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
