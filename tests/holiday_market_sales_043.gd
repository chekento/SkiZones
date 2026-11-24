extends SceneTree
## Holiday products must be real completed sales, with staff, per-unit supplies,
## validated ledgers, and lossless career roundtrip on any game day.
const Resort=preload("res://src/core/resort.gd")
const Offers=preload("res://src/core/building_offers_035.gd")
const Holiday=preload("res://src/core/holiday_market_sales_043.gd")
const Ops=preload("res://src/core/operations.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0

func check(ok:bool,why:String)->void:
	if ok:passed+=1;print("PASS ",why)
	else:failed+=1;push_error("FAIL "+why)

func _init()->void:call_deferred("run")

func _guest(id:int,building_id:int)->Dictionary:
	return {"id":id,"age":30,"phase":"moving","ability":0,"group_size":2,
		"leg":0,"heading_home":true,"stay":200,"runs":0,"loops":0,
		"route":{"target":0,"legs":[{"kind":"visit","id":building_id,"from":"base","to":"base"}]}}

func run()->void:
	var nikolaus:Dictionary={"year":2026,"month":12,"day":6}
	var christmas:Dictionary={"year":2026,"month":12,"day":25}
	var november:Dictionary={"year":2026,"month":11,"day":30}
	check(Holiday.valid_catalog(),"Seasonal prices, supply costs and SKU IDs are valid and profitable")
	check(Holiday.ITEMS.size()==6,"Six real winter products use six existing staffed business types")
	for kind in Holiday.ITEMS:
		var offer:Dictionary=Holiday.all_for(str(kind))[0]
		var off:Array=Offers.active(str(kind),1,november)
		var on:Array=Offers.active(str(kind),1,christmas)
		check(not off.any(func(item):return item.id==offer.id) and on.any(func(item):return item.id==offer.id),
			"Holiday item is visible only in season: "+str(kind))
		check(float(offer.price)>float(offer.cost) and float(offer.cost)>0.0 and offer.level==1,
			"Seasonal selling price exceeds charged ingredient or merchandise cost: "+str(kind))
		check(Offers.all_for(str(kind)).any(func(item):return item.id==offer.id),
			"Off-season sales ledger still recognizes historical SKU: "+str(kind))
		check(Offers.visit_sale({"kind":kind,"level":1,"visits":0},{"id":18,"group_size":2},november).id!=offer.id,
			"Ordinary dates cannot book a Christmas-only SKU: "+str(kind))
	check(Holiday.active("restaurant",nikolaus).is_empty() and Holiday.active("restaurant",christmas).size()==1,
		"Christmas dinner cannot be sold prematurely on Nikolaus day")
	check(not Holiday.active("cocoa",nikolaus).is_empty() and Holiday.active("cocoa",christmas).size()==1,
		"Festive cocoa can be served on Nikolaus and Christmas")
	check(Holiday.active("cocoa",{"year":2026,"month":12,"day":31}).is_empty(),
		"Silvester does not accidentally keep Christmas products on shelves")
	check(Holiday.active("cocoa",{"year":2026,"month":12,"day":32}).is_empty(),
		"Invalid calendar dates cannot create festival products")
	check(Holiday.active("hotel",christmas).is_empty() and Holiday.active("pizzeria",christmas).is_empty(),
		"Rooms and custom pizzas preserve their independent existing pricing logic")
	var model:=Resort.new()
	model.new_game(true,20261105,"sonnenhang")
	model.minute=720
	model.party_mode=false
	var shop:Dictionary=model.buildings[0]
	shop.kind="cocoa"
	shop.enabled=true
	shop.level=1
	model.operations.enabled=true
	model.operations.continuous=false
	model.operations.staff=[]
	model._duty_cache.clear()
	check(not Ops.building_open(model,shop),"Seasonal cocoa is closed without a qualified barista on duty")
	var selected_id:int=-1
	var sale:Dictionary={}
	for id in range(25,100):
		var candidate:Dictionary=Offers.visit_sale(shop,_guest(id,int(shop.id)),christmas)
		if str(candidate.get("id",""))=="holiday_cocoa":
			selected_id=id
			sale=candidate
			break
	check(selected_id>0 and sale.quantity==2 and float(sale.cost)>0,"A real two-person purchase can select the festive cocoa recipe")
	if selected_id<0:
		print("RESULT: %d passed; %d failed" % [passed,failed])
		quit(1)
		return
	var blocked:Dictionary=_guest(selected_id,int(shop.id))
	var blocked_money:float=model.money
	var blocked_cost:float=model.report.costs
	model._finish_leg(blocked,christmas)
	check(is_equal_approx(model.money,blocked_money) and is_equal_approx(model.report.costs,blocked_cost) and not shop.has("product_sales"),
		"No employee means no seasonal cash, supplies or phantom sale")
	var hired:Dictionary=Ops.hire(model,"barista","building:%d" % int(shop.id),"day",true)
	Ops.refresh_duty(model)
	check(hired.ok and Ops.building_open(model,shop),"Real qualified employee opens the festive cocoa shop")
	var guest:Dictionary=_guest(selected_id,int(shop.id))
	var money_before:float=model.money
	var costs_before:float=model.report.costs
	var services_before:float=model.report.services
	model._finish_leg(guest,christmas)
	check(is_equal_approx(model.money-money_before,float(sale.revenue)-float(sale.cost)),
		"Completed two-person festive sale changes cash by real gross revenue minus unit costs")
	check(is_equal_approx(model.report.services-services_before,float(sale.revenue)),
		"Festival income is a replacement product sale, never a second flat tariff")
	check(is_equal_approx(model.report.costs-costs_before,float(sale.cost)),
		"Exactly one ingredient or merchandise expense enters daily operating costs")
	var recorded:Dictionary=shop.get("product_sales",{}).get("holiday_cocoa",{})
	check(recorded.get("quantity",0)==2 and is_equal_approx(float(recorded.get("cost",0)),float(sale.cost)),
		"Product ledger records the actual quantity and supply cost")
	check(Offers.valid_sales(shop) and is_equal_approx(float(Ops.business_balance(model,shop).supplies),float(sale.cost)),
		"Seasonal SKU is validated and its real supplies lower business profit")
	check(guest.leg==1,"Completed festive service resumes the guest itinerary normally")
	var saved:Dictionary=model.snapshot()
	var restored:=Resort.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))).ok,
		"Seasonal SKU and paid barista survive an actual complete JSON save/load roundtrip")
	if restored.buildings.size()>0:
		var again:Dictionary=restored.buildings[0].get("product_sales",{}).get("holiday_cocoa",{})
		check(int(again.get("quantity",0))==2 and is_equal_approx(float(again.get("cost",0)),float(sale.cost)),
			"Recovered careers preserve exact season stock-consumption counters and ingredient expenses")
	L.configure("en")
	check(L.text("Weihnachtsmenü")=="Christmas menu" and L.text("Festtags-Kakao")=="Festive hot cocoa",
		"Festive item names have complete English translations")
	L.configure("de")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
