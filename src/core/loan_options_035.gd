extends RefCounted
## 0.35 finance design – deterministic quotes and amortization (no save writes).
## Interest and repayments are fictional game rules, not real lending offers.
## Economic operations MUST use this module as a quote source before
## implementing separate persisted cash-flow/loan servicing.
const StartTiers = preload("res://src/core/start_tiers.gd")
const MIN_PRINCIPAL := 10000
const MAX_PRINCIPAL := 750000
const MAX_DAYS := 180
const MAX_GRACE := 14
const FIXED := [
	{"id":"micro","name":"Starterbrücke","principal":20000,"days":28,"annual_rate":0.055,"mode":"annuity","grace":0},
	{"id":"season","name":"Saisonliquidität","principal":60000,"days":56,"annual_rate":0.070,"mode":"linear","grace":0},
	{"id":"construction","name":"Ausbaukredit","principal":150000,"days":84,"annual_rate":0.085,"mode":"annuity","grace":7},
	{"id":"equipment","name":"Pistenraupen & Technik","principal":250000,"days":112,"annual_rate":0.100,"mode":"linear","grace":7},
	{"id":"growth","name":"Resort-Expansion","principal":400000,"days":168,"annual_rate":0.115,"mode":"annuity","grace":14},
	{"id":"emergency","name":"Notfall-Überbrückung","principal":70000,"days":28,"annual_rate":0.160,"mode":"interest_only","grace":0}
]
const REPAYMENT_MODES := ["annuity", "linear", "interest_only"]
const TIER_FACTORS := [1.7, 1.3, 1.0, 0.85, 0.7]

static func details(id: String) -> Dictionary:
	for row in FIXED:
		if str(row.id) == id: return row.duplicate(true)
	return {}

static func valid_terms(principal: int, days: int, annual_rate: float, mode: String, grace: int) -> bool:
	return principal >= MIN_PRINCIPAL and principal <= MAX_PRINCIPAL and days >= 7 and days <= MAX_DAYS and grace >= 0 and grace <= MAX_GRACE and grace < days and annual_rate >= 0.0 and annual_rate <= 0.50 and mode in REPAYMENT_MODES

static func custom_rate(principal: int, days: int, tier_index: int, mode: String) -> float:
	# The player chooses principal, term and repayment policy, but cannot
	# arbitrarily set the risk premium to zero or generate money for free.
	var risk: float = TIER_FACTORS[clampi(tier_index, 0, TIER_FACTORS.size()-1)]
	var size_extra: float = 0.0 if principal <= 60000 else 0.010 if principal <= 200000 else 0.025
	var term_extra: float = 0.0 if days <= 56 else 0.008 if days <= 112 else 0.018
	var mode_extra: float = 0.015 if mode == "interest_only" else 0.0
	return snappedf((0.07 + size_extra + term_extra + mode_extra)*risk,0.0001)

static func offer(id: String, tier_index: int, amount: int = 0, days: int = 0, mode: String = "annuity", grace: int = 0) -> Dictionary:
	var spec: Dictionary = details(id)
	if id == "custom":
		spec = {"id":"custom","name":"Wunschfinanzierung","principal":amount,
			"days":days,"mode":mode,"grace":grace,
			"annual_rate":custom_rate(amount,days,tier_index,mode)}
	elif not spec.is_empty():
		# The same six named products become meaningfully harder on sparse budgets.
		spec.annual_rate = snappedf(float(spec.annual_rate) * TIER_FACTORS[clampi(tier_index,0,TIER_FACTORS.size()-1)],0.0001)
	if spec.is_empty(): return {"ok":false,"message":"Unbekannter Kredittyp."}
	if not valid_terms(int(spec.principal),int(spec.days),float(spec.annual_rate),str(spec.mode),int(spec.grace)):
		return {"ok":false,"message":"Kreditbetrag, Laufzeit oder Rückzahlungsmodus ist ungültig."}
	var payments: Array = schedule(int(spec.principal),int(spec.days),float(spec.annual_rate),str(spec.mode),int(spec.grace))
	if payments.size()!=int(spec.days): return {"ok":false,"message":"Kreditplan konnte nicht erstellt werden."}
	var total_interest := 0.0
	var max_payment := 0.0
	for row in payments:
		total_interest += float(row.interest)
		max_payment = maxf(max_payment,float(row.payment))
	return {"ok":true,"id":str(spec.id),"name":str(spec.name),
		"principal":int(spec.principal),"annual_rate":float(spec.annual_rate),"days":int(spec.days),
		"grace":int(spec.grace),"mode":str(spec.mode),"daily_installments":payments,
		"first_payment":float(payments[0].payment),"max_payment":max_payment,
		"total_interest":snappedf(total_interest,0.01),
		"total_payment":snappedf(float(spec.principal)+total_interest,0.01)}

static func schedule(principal: int, days: int, annual_rate: float, mode: String, grace: int = 0) -> Array:
	if not valid_terms(principal,days,annual_rate,mode,grace): return []
	var result: Array = []
	var balance: float = float(principal)
	var rate: float = annual_rate / 365.0
	var payment_days: int = days-grace
	var annuity: float = 0.0
	if mode == "annuity":
		annuity = float(principal)/payment_days if rate < 0.00000001 else float(principal)*rate/(1.0-pow(1.0+rate,-payment_days))
	for day in range(1,days+1):
		var interest: float = snappedf(balance*rate,0.01)
		var capital: float = 0.0
		if day > grace:
			if mode == "interest_only":
				capital = balance if day == days else 0.0
			elif mode == "linear":
				capital = mini(int(ceilf(float(principal)/float(payment_days))), int(ceilf(balance)))
			else:
				capital = maxf(0.0,annuity-interest)
			if day == days: capital = balance
		capital = snappedf(minf(balance,capital),0.01)
		balance = maxf(0.0,snappedf(balance-capital,0.01))
		result.append({"day":day,"principal":capital,"interest":interest,
			"payment":snappedf(capital+interest,0.01),"balance":balance})
	return result

static func risk_hint(quote: Dictionary, free_cash_per_day: float) -> String:
	if not bool(quote.get("ok",false)): return "Kein gültiges Kreditangebot"
	var instalment: float = float(quote.max_payment)
	if free_cash_per_day <= 0.0 or instalment > free_cash_per_day*1.2:
		return "Hohes Insolvenz- und Ratenrisiko"
	if instalment > free_cash_per_day*0.7:
		return "Hohe Belastung"
	return "Aus aktueller Liquiditätsreserve tragbar"
