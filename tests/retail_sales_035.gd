extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Offers = preload("res://src/core/building_offers_035.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; push_error("FAIL "+label)
func run() -> void:
	var model := Resort.new()
	model.new_game(true,20261105,"sonnenhang")
	model.operations.enabled = false
	model.minute = 720
	model.party_mode = false
	var shop: Dictionary = model.buildings[0]
	shop.kind = "schmarrn"
	shop.level = 1
	shop.enabled = true
	# Complete an actual service leg, without starting a second itinerary.
	var guest := {"id":300,"age":30,"phase":"moving","ability":0,"group_size":2,
		"leg":0,"heading_home":true,"stay":200,"runs":0,"loops":0,
		"route":{"target":0,"legs":[{"kind":"visit","id":int(shop.id),"from":"base","to":"base"}]}}
	var sale: Dictionary = Offers.visit_sale(shop,guest)
	var money_before: float = model.money
	var costs_before: float = model.report.costs
	var services_before: float = model.report.services
	model._finish_leg(guest)
	check(is_equal_approx(model.money-money_before,float(sale.revenue)-float(sale.cost)),"Completed party visit changes actual cash by gross sale minus supplies")
	check(is_equal_approx(model.report.services-services_before,float(sale.revenue)),"Revenue is gross and charged once instead of adding the old flat tariff")
	check(is_equal_approx(model.report.costs-costs_before,float(sale.cost)),"Real supply expense enters operating costs once")
	check(shop.product_sales[str(sale.id)].quantity==2 and guest.leg==1,"Two actual customers buy two products and the visit advances")
	check(not Offers.active("schmarrn",1).any(func(x): return x.id=="churros"),"Churros cannot be sold before their building upgrade")
	shop.level=2
	check(Offers.active("schmarrn",2).any(func(x): return x.id=="churros"),"Upgrading really adds Churros to the selectable retail assortment")
	model.campaign.mode="free"
	model.money=5000000
	while int(shop.level)<5:
		check(model.upgrade_asset(int(shop.id)).ok,"Building upgrade reaches genuine next level "+str(int(shop.level)))
	check(not model.upgrade_asset(int(shop.id)).ok,"Building level 5 is a real final upgrade cap")
	check(Offers.active("schmarrn",5).any(func(x):return x.id=="apple_pastry"),"Level-5 bakery products are now actually unlocked")
	var restored := Resort.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Product quantities and costs survive complete resort save/load")
	var bad: Dictionary = model.snapshot()
	bad.buildings[0].product_sales[str(sale.id)].quantity=-1
	check(not restored.restore(bad).ok,"Corrupt product inventory counters cannot mutate a loaded resort")
	for kind in ["hotel","school","first_aid","viewpoint"]:
		check(Offers.visit_sale({"kind":kind,"level":5},guest).is_empty(),"No fabricated product cash at "+kind)
	var pizza := {"kind":"pizzeria","level":1,"visits":0}
	var old_menu: Array = Hospitality.menu(pizza)
	check(not Hospitality.pizza_sale(pizza,guest).is_empty(),"Legacy unpriced pizza menus now incur actual ingredients without save mutation")
	check(Hospitality.menu(pizza)==old_menu and not pizza.has("pizza_menu"),"Reading and selling legacy pizza preserves original names and toppings")
	var low := 0.0
	var high := 0.0
	var cheap := {"kind":"pizzeria","pizza_menu":old_menu.duplicate(true)}
	var costly := cheap.duplicate(true)
	for recipe in cheap.pizza_menu: recipe.price=15
	for recipe in costly.pizza_menu: recipe.price=36
	for i in range(500):
		cheap.visits=i;costly.visits=i
		low+=Hospitality.pizza_sale(cheap,{"id":i}).quantity
		high+=Hospitality.pizza_sale(costly,{"id":i}).quantity
	check(high<low*0.5 and high>0,"High pizza prices lower real purchase conversion and cannot guarantee every visitor buys")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
