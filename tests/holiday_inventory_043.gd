extends SceneTree
## Actual hourly delivery, automatic low-stock ordering and fail-closed save
## validation. Uses the same operations clock as staff and rescue simulation.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Stock=preload("res://src/core/holiday_inventory_043.gd")
const Market=preload("res://src/core/holiday_market_sales_043.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error("FAIL "+message)
func _init()->void:call_deferred("run")
func run()->void:
	var dec6:Dictionary={"year":2026,"month":12,"day":6}
	var dec25:Dictionary={"year":2026,"month":12,"day":25}
	var ordinary:Dictionary={"year":2026,"month":11,"day":24}
	var model:=Resort.new()
	model.new_game(true,20261124,"sonnenhang")
	model.minute=600
	model.operations.enabled=true
	model.operations.continuous=false
	var shop:Dictionary=model.buildings[0]
	shop.kind="kiosk"
	shop.enabled=true
	shop.level=1
	model.operations.staff=[]
	model._duty_cache.clear()
	check(Stock.valid(shop) and not Stock.available(shop,1),"Existing careers have optional empty stock, never phantom units")
	Stock.tick(model,dec6)
	check(not shop.has("holiday_inventory"),"No festive preorders are placed without an assigned vendor")
	var hired:Dictionary=Ops.hire(model,"vendor","building:%d" % int(shop.id),"day",true)
	Ops.refresh_duty(model)
	check(hired.ok and Ops.building_open(model,shop),"Qualified kiosk vendor is on duty")
	var money_before:float=model.money
	var cost_before:float=model.report.costs
	Stock.tick(model,ordinary)
	check(not shop.has("holiday_inventory") and is_equal_approx(model.money,money_before),"Ordinary days do not purchase Christmas goods")
	Stock.tick(model,dec6)
	var expense:float=snappedf(Stock.ORDER_UNITS*float(Market.ITEMS.kiosk.cost),0.01)
	check(shop.has("holiday_inventory") and int(shop.holiday_inventory.stock)==0 and int(shop.holiday_inventory.pending)==24,
		"First holiday duty automatically places 24-unit replenishment, no free initial inventory")
	check(is_equal_approx(money_before-model.money,expense) and is_equal_approx(model.report.costs-cost_before,expense),
		"Automatic purchase pays exactly 24 wholesale units and logs the operating cost")
	var charged:float=model.money
	Stock.tick(model,dec6)
	check(is_equal_approx(model.money,charged),"Repeated game ticks do not duplicate the pending purchase")
	var restored:=Resort.new()
	var saved:Dictionary=model.snapshot()
	var loaded:Dictionary=restored.restore(JSON.parse_string(JSON.stringify(saved)))
	check(loaded.ok,"A pending stock delivery survives an actual JSON save/load roundtrip")
	if not loaded.ok:
		print("SAVE CHECK: ",loaded.get("message",""))
		print("RESULT: %d passed; %d failed" % [passed,failed])
		quit(1)
		return
	var revived:Dictionary=restored.buildings[0]
	check(Stock.valid(revived) and not Stock.available(revived,1) and int(revived.holiday_inventory.pending)==24,
		"Reloading preserves outstanding delivery but does not unlock merchandise")
	restored.minute+=Stock.DELIVERY_MINUTES-1
	Stock.tick(restored,dec6)
	check(not Stock.available(revived,1),"Delivery cannot arrive a simulated minute early")
	restored.minute+=1
	Stock.tick(restored,dec6)
	check(Stock.available(revived,24) and int(revived.holiday_inventory.pending)==0,
		"Delivery becomes actual available stock after 45 game minutes")
	check(Stock.consume(revived,22) and int(revived.holiday_inventory.stock)==2,
		"Actual fulfilled transactions consume physical holiday stock")
	var cash_before_reorder:float=restored.money
	Stock.tick(restored,dec6)
	check(int(revived.holiday_inventory.pending)==24 and is_equal_approx(cash_before_reorder-restored.money,expense),
		"Low stock automatically queues another 24-unit prepaid replenishment")
	check(not Stock.consume(revived,3) and int(revived.holiday_inventory.stock)==2,
		"No transaction can consume more holiday goods than available")
	var no_sales:Dictionary=revived.duplicate(true)
	restored.minute+=45
	Stock.tick(restored,ordinary)
	check(int(revived.holiday_inventory.stock)==26 and int(revived.holiday_inventory.pending)==0,
		"Previously paid deliveries still arrive after the real holiday date ends")
	check(Stock.valid(revived) and Stock.valid(no_sales),"Valid persisted replenishment records remain accepted")
	var broken:Dictionary=restored.snapshot()
	broken.buildings[0].holiday_inventory.stock=-1
	check(not Resort.new().restore(broken).ok,"Negative inventory is rejected at the actual career load gate")
	var fractional:Dictionary=restored.snapshot()
	fractional.buildings[0].holiday_inventory.pending=2.5
	check(not Resort.new().restore(fractional).ok,"Fractional or forged delivery quantities cannot be loaded")
	var mismatched:Dictionary=restored.snapshot()
	mismatched.buildings[0].holiday_inventory.sku="holiday_gift"
	check(not Resort.new().restore(mismatched).ok,"An inventory SKU cannot be reassigned to another business type")
	var invalid_eta:Dictionary=restored.snapshot()
	invalid_eta.buildings[0].holiday_inventory.arrival_at=123
	check(not Resort.new().restore(invalid_eta).ok,"Arrivals without a pending order fail closed")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
