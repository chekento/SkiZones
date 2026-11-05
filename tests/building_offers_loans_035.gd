extends SceneTree
## 0.35 unit-only regression – does not modify existing live save formats.
const Catalog = preload("res://src/core/catalog.gd")
const Offers = preload("res://src/core/building_offers_035.gd")
const Loans = preload("res://src/core/loan_options_035.gd")
var passed := 0
var failed := 0

func check(value: bool, description: String) -> void:
	if value:
		passed += 1
		print("PASS ",description)
	else:
		failed += 1
		push_error("FAIL "+description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Offers.valid_catalog(),"All currently buildable building types have real levelled offers")
	check(Offers.OFFERS.size()==Catalog.BUILDINGS.size(),"Offer catalog tracks the complete existing buildings catalog")
	for kind in Catalog.BUILDINGS:
		var base: Array = Offers.active(str(kind),1)
		check(base.size()>0,"Baseline is immediately active for "+str(kind))
		check(Offers.active(str(kind),5).size() >= base.size(),"All upgrades preserve baseline in "+str(kind))
		check(Offers.locked(str(kind),1).size()>0,"At least one meaningful unlock remains for "+str(kind))
		for offer in Offers.all_for(str(kind)):
			check(Offers.sale_margin(offer) >= 0.0,"Sale price covers direct unit costs: "+str(kind)+"/"+str(offer.id))
	var schmarrn := Offers.active("schmarrn",1)
	check(schmarrn.any(func(item): return str(item.id)=="kaiserschmarrn"),"Kaiserschmarrn is offered from the start")
	check(not schmarrn.any(func(item): return str(item.id)=="churros"),"Churros require a higher building level")
	check(Offers.active("schmarrn",4).any(func(item): return str(item.id)=="croissant"),"Croissant unlocks in the Schmarrn shop")
	check(Offers.active("pizzeria",3).any(func(item): return str(item.id)=="pasta"),"Pizzeria unlocks Pasta")
	check(Offers.active("school",1).any(func(item): return str(item.id)=="beginners"),"Ski school starts with beginner course")
	check(Offers.active("school",5).any(func(item): return str(item.id)=="freeride"),"Advanced ski courses appear in higher levels")
	check(Offers.active("first_aid",1).any(func(item): return str(item.id)=="rescue"),"Bergwacht starts with core rescue service")
	check(Offers.active("maintenance",5).any(func(item): return str(item.id)=="sensors"),"Piste groomer upgrades are represented")
	for kind in ["schmarrn","pizzeria","restaurant","kiosk","cocoa","bar","disco","hotel","grand_hotel"]:
		check(Offers.active(kind,1).any(func(item): return str(item.category)=="drink"),"Beverage service exists on level 1 in "+kind)
	var price := Offers.price_report("schmarrn",4)
	check(float(price.sample_turnover)>float(price.sample_cost) and int(price.products)>0,"Sale mix has explicit cost and margin instead of pure bonus")
	check(Loans.FIXED.size()==6,"There are exactly six named finance choices")
	check(Loans.REPAYMENT_MODES.size()==3,"All three repayment modes are modelled")
	for loan in Loans.FIXED:
		for tier in range(5):
			var quote := Loans.offer(str(loan.id),tier)
			check(bool(quote.get("ok",false)),"Loan quote is valid: "+str(loan.id)+", tier "+str(tier))
			if not bool(quote.get("ok",false)): continue
			var payments: Array = quote.daily_installments
			check(payments.size()==int(loan.days),"Daily installments cover the exact term: "+str(loan.id))
			check(is_zero_approx(float(payments.back().balance)),"Debt amortizes exactly to zero: "+str(loan.id))
			var principal_total := 0.0
			var interest_total := 0.0
			for payment in payments:
				principal_total += float(payment.principal)
				interest_total += float(payment.interest)
			check(absf(principal_total-float(loan.principal))<0.1,"Principal is conserved: "+str(loan.id))
			check(absf(interest_total-float(quote.total_interest))<0.1,"Interest is recorded once: "+str(loan.id))
	var hardship := Loans.offer("emergency",0)
	var easy := Loans.offer("emergency",4)
	check(bool(hardship.ok) and bool(easy.ok) and float(hardship.annual_rate)>float(easy.annual_rate),"Hard careers bear higher borrowing costs than very easy ones")
	for mode in Loans.REPAYMENT_MODES:
		var quote := Loans.offer("custom",2,120000,77,str(mode),7)
		check(bool(quote.get("ok",false)),"Custom loan supports "+str(mode))
		if bool(quote.get("ok",false)):
			check(is_zero_approx(float(quote.daily_installments.back().balance)),"Custom balance reaches zero for "+str(mode))
	check(not bool(Loans.offer("custom",2,1000,0,"annuity",0).get("ok",false)),"Invalid custom principal and term rejected")
	check(not bool(Loans.offer("custom",2,120000,77,"free_money",0).get("ok",false)),"Unknown repayment mode rejected")
	check(not bool(Loans.offer("unknown",2).get("ok",false)),"Unknown preset cannot be taken")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
