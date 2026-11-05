extends SceneTree
## Loan acceptance tests: actual money, daily servicing and old saves.
const Resort = preload("res://src/core/resort.gd")
const Credits = preload("res://src/core/credit_service_035.gd")
const Offers = preload("res://src/core/loan_options_035.gd")
var pass_count := 0
var fail_count := 0

func check(value: bool, name: String) -> void:
	if value:
		pass_count += 1
		print("PASS ",name)
	else:
		fail_count += 1
		push_error("FAIL "+name)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var model := Resort.new()
	model.new_game(true,20261105,"sonnenhang")
	model.money = 200000.0
	model.campaign["starting_tier"]=2
	var previous: float = model.money
	var offer := Offers.offer("micro",2)
	var granted := model.take_credit("micro")
	check(granted.ok and model.loan==int(offer.principal) and model.money==previous+float(offer.principal),"Loan disbursement creates debt and cash only")
	check(model.campaign.get("credit_contract",{}).get("paid_days",-1)==0,"New loan has no due installment on its signature day")
	check(not model.take_credit("season").ok,"Second simultaneous loan cannot be created")
	var first := Credits.service_day(model)
	check(not first.ok,"No premature payment on loan start day")
	model.day += 1
	previous = model.money
	var report_before: float = float(model.report.costs)
	first = Credits.service_day(model)
	var item: Dictionary = offer.daily_installments[0]
	check(first.ok,"Loan has a due installment after day rollover")
	check(absf(model.money-(previous-float(item.payment)))<0.02,"Loan decreases real cash by principal plus interest exactly once")
	check(absf(float(model.report.costs)-report_before-float(item.interest))<0.02,"P&L sees interest only, not principal")
	check(model.loan==ceili(float(item.balance)),"Legacy numeric loan mirrors active balance")
	previous = model.money
	check(not Credits.service_day(model).ok and model.money==previous,"Repeat daily collection cannot debit twice")
	var copy: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(Resort.new().restore(copy).ok,"New credit debt, payment state and day survive JSON save/load")
	var forged: Dictionary = copy.duplicate(true)
	forged.campaign.credit_contract.balance = -50000.0
	check(not Resort.new().restore(forged).ok,"Forged negative balance is rejected without loading")
	forged=copy.duplicate(true)
	forged.campaign.credit_contract.paid_days=76
	check(not Resort.new().restore(forged).ok,"Invented repayment progress is rejected")
	var due: float = float(model.campaign.credit_contract.balance)
	previous=model.money
	check(model.repay_loan() and model.loan==0 and not Credits.active(model),"Early repayment fully settles debt")
	check(absf(model.money-(previous-due))<0.02,"Early repayment is only remaining principal")
	check(model.take_credit("custom",120000,84,"linear",7).ok,"Custom loan can be signed after former loan is cleared")
	model.campaign.erase("credit_contract")
	model.loan=150000
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Legacy 150k loan remains compatible")
	print("RESULT: %d passed; %d failed" % [pass_count,fail_count])
	quit(1 if fail_count else 0)
