extends RefCounted
## 0.35 prototype credit servicing. All new states are optional and additive.
## Legacy 0.33.2 loans (integer principal, no credit_contract) remain valid.
const LoanOptions = preload("res://src/core/loan_options_035.gd")

static func active(model: RefCounted) -> bool:
	return model.campaign.get("credit_contract", {}) is Dictionary and not model.campaign.get("credit_contract", {}).is_empty()

static func take(model: RefCounted, id: String, principal: int = 0, days: int = 0,
	mode: String = "annuity", grace: int = 0) -> Dictionary:
	if model.loan > 0 or active(model):
		return {"ok":false,"message":"Zuerst den bestehenden Kredit vollständig tilgen."}
	var tier: int = clampi(int(model.campaign.get("starting_tier",2)),0,4)
	var quote: Dictionary = LoanOptions.offer(id,tier,principal,days,mode,grace)
	if not quote.get("ok",false): return quote
	var money_before: float = model.money
	var loan_before: int = model.loan
	var amount: int = int(quote.principal)
	if amount < 0 or money_before + amount > 1000000000.0:
		return {"ok":false,"message":"Die Kreditobergrenze oder Geldgrenze ist überschritten."}
	var contract := {
		"id":str(quote.id),"principal":amount,"annual_rate":float(quote.annual_rate),
		"days":int(quote.days),"mode":str(quote.mode),"grace":int(quote.grace),
		"start_day":int(model.day),"last_paid_day":int(model.day),"paid_days":0,
		"paid_interest":0.0,"balance":float(amount),"tier":tier
	}
	model.campaign["credit_contract"]=contract
	model.loan = amount
	model.money += amount
	# Loan principal is a financing cash flow and MUST NOT enter turnover.
	model._invalidate()
	return {"ok":true,"message":"Kredit ausgezahlt · %d € · %d Tage. Einzahlungen sind kein Gewinn." % [amount,int(quote.days)],
		"contract":contract.duplicate(true),"previous_loan":loan_before}

static func service_day(model: RefCounted) -> Dictionary:
	if not active(model): return {"ok":false,"reason":"none"}
	var contract: Dictionary = model.campaign.credit_contract
	# Exactly one due installment per actual closing day, including resume.
	if int(contract.last_paid_day) >= int(model.day) or int(contract.paid_days) >= int(contract.days):
		return {"ok":false,"reason":"already_paid"}
	var payments: Array = LoanOptions.schedule(int(contract.principal),int(contract.days),
		float(contract.annual_rate),str(contract.mode),int(contract.grace))
	if payments.is_empty(): return {"ok":false,"reason":"invalid_plan"}
	var item: Dictionary = payments[int(contract.paid_days)]
	var amount: float = float(item.payment)
	# Debt service may create a limited overdraft; difficulty influences
	# risk and finance eligibility, but the player cannot avoid the due date.
	# Negativity remains within the model's pre-existing safe money bounds.
	if model.money - amount < -100000000.0:
		return {"ok":false,"reason":"hard_balance_limit"}
	model.money -= float(item.principal)
	model.Ops._charge(model,float(item.interest),"loan_interest")
	contract.paid_days = int(contract.paid_days)+1
	contract.last_paid_day = int(model.day)
	contract.balance = float(item.balance)
	contract.paid_interest = snappedf(float(contract.paid_interest)+float(item.interest),0.01)
	model.loan = ceili(float(item.balance))
	if int(contract.paid_days) == int(contract.days):
		model.campaign["last_credit"]=contract.duplicate(true)
		model.campaign.erase("credit_contract")
	model._invalidate()
	return {"ok":true,"payment":amount,"principal":float(item.principal),
		"interest":float(item.interest),"balance":model.loan}

static func early_repay(model: RefCounted) -> Dictionary:
	if not active(model): return {"ok":false,"message":"Kein neuer Kredit offen."}
	var contract: Dictionary = model.campaign.credit_contract
	var due: float = float(contract.balance)
	if model.money < due:
		return {"ok":false,"message":"Für die vollständige Sondertilgung fehlt das Geld."}
	model.money -= due
	model.loan = 0
	contract.balance = 0.0
	model.campaign["last_credit"]=contract.duplicate(true)
	model.campaign.erase("credit_contract")
	model._invalidate()
	return {"ok":true,"message":"Kredit vollständig getilgt; keine künftigen Zinsen."}

static func valid_contract(value: Variant, day: int, loan: int) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	var needed := ["id","principal","annual_rate","days","mode","grace","start_day",
		"last_paid_day","paid_days","paid_interest","balance","tier"]
	if value.size()!=needed.size(): return false
	for key in needed:
		if not value.has(key): return false
	if not value.id is String or value.id not in ["micro","season","construction","equipment","growth","emergency","custom"]: return false
	for key in ["principal","days","grace","start_day","last_paid_day","paid_days","tier"]:
		if not (value[key] is float or value[key] is int) or float(value[key])!=floorf(float(value[key])): return false
	if int(value.tier)<0 or int(value.tier)>4 or int(value.start_day)<1 or int(value.start_day)>day: return false
	if int(value.last_paid_day)<int(value.start_day) or int(value.last_paid_day)>day: return false
	if int(value.paid_days)<0 or int(value.paid_days)>=int(value.days): return false
	if not value.annual_rate is float and not value.annual_rate is int: return false
	if not LoanOptions.valid_terms(int(value.principal),int(value.days),float(value.annual_rate),str(value.mode),int(value.grace)): return false
	if not (value.balance is float or value.balance is int) or not (value.paid_interest is float or value.paid_interest is int): return false
	if is_nan(float(value.balance)) or is_inf(float(value.balance)) or is_nan(float(value.paid_interest)) or is_inf(float(value.paid_interest)): return false
	if float(value.balance)<0 or float(value.balance)>750000 or float(value.paid_interest)<0 or float(value.paid_interest)>750000: return false
	var schedule: Array = LoanOptions.schedule(int(value.principal),int(value.days),float(value.annual_rate),str(value.mode),int(value.grace))
	var remaining: float = float(value.principal) if int(value.paid_days)==0 else float(schedule[int(value.paid_days)-1].balance)
	if absf(float(value.balance)-remaining)>0.01 or loan!=ceili(remaining): return false
	# Never accept a fictitious number of installments for the game date.
	if int(value.paid_days)>int(value.last_paid_day)-int(value.start_day): return false
	return true
