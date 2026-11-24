extends RefCounted
## Physical holiday stock: purchase supplies before sales, wait for delivery and
## spend the same units exactly once. The optional per-building dictionary is
## validated on load; absent stock in legacy careers is valid and means empty.
const Calendar=preload("res://src/core/annual_festival.gd")
const Market=preload("res://src/core/holiday_market_sales_043.gd")
const DELIVERY_MINUTES:=45
const REORDER_AT:=5
const ORDER_UNITS:=24
const MAX_UNITS:=256
const MAX_CLOCK:=150000000

static func sku_for(kind:String)->String:
	return str(Market.ITEMS[kind].id) if Market.ITEMS.has(kind) else ""

static func seasonal(sale:Dictionary)->bool:
	return str(sale.get("id","")) in Market.ITEMS.values().map(func(offer):return str(offer.id))

static func valid(building:Dictionary)->bool:
	if not building.has("holiday_inventory"):return true
	var inv:Variant=building.holiday_inventory
	if not inv is Dictionary or inv.size()!=4:return false
	if not Market.ITEMS.has(str(building.get("kind",""))):return false
	if inv.get("sku")!=sku_for(str(building.kind)):return false
	for field in ["stock","pending","arrival_at"]:
		var value:Variant=inv.get(field)
		# Godot JSON.parse_string may decode integral JSON values as floats.
		# Accept only finite exact integers, never fractions, NaN or strings.
		if not value is int and not value is float:return false
		if not is_finite(float(value)) or float(value)!=floorf(float(value)):return false
	var stock:int=int(inv.stock)
	var pending:int=int(inv.pending)
	var eta:int=int(inv.arrival_at)
	if stock<0 or stock>MAX_UNITS or pending<0 or pending>ORDER_UNITS:return false
	if stock+pending>MAX_UNITS:return false
	if (pending==0)!=(eta==-1):return false
	if eta< -1 or eta>MAX_CLOCK:return false
	return true

static func available(building:Dictionary,quantity:int)->bool:
	if quantity<1 or not valid(building):return false
	if not building.has("holiday_inventory"):return false
	return int(building.holiday_inventory.stock)>=quantity

static func consume(building:Dictionary,quantity:int)->bool:
	if not available(building,quantity):return false
	building.holiday_inventory.stock=int(building.holiday_inventory.stock)-quantity
	return true

static func _clock(model:RefCounted)->int:
	return (int(model.day)-1)*1440+int(model.minute)

static func receive(model:RefCounted,building:Dictionary)->bool:
	if not valid(building) or not building.has("holiday_inventory"):return false
	var inv:Dictionary=building.holiday_inventory
	if int(inv.pending)<=0 or _clock(model)<int(inv.arrival_at):return false
	inv.stock=int(inv.stock)+int(inv.pending)
	inv.pending=0
	inv.arrival_at=-1
	return true

static func order(model:RefCounted,building:Dictionary,date:Dictionary={},quantity:int=ORDER_UNITS)->bool:
	var kind:String=str(building.get("kind",""))
	if not Market.ITEMS.has(kind) or quantity<1 or quantity>ORDER_UNITS:return false
	var now:Dictionary=Calendar.device_now() if date.is_empty() else date
	if Market.active(kind,now).is_empty():return false
	if not bool(building.get("enabled",false)) or not model.Ops.building_open(model,building):return false
	if not valid(building):return false
	var current:Dictionary=building.get("holiday_inventory",{"sku":sku_for(kind),"stock":0,"pending":0,"arrival_at":-1})
	if int(current.pending)>0 or int(current.stock)+quantity>MAX_UNITS:return false
	var expense:float=snappedf(float(Market.ITEMS[kind].cost)*float(quantity),0.01)
	if not model.can_afford(expense):return false
	# Supply prepayment is the ONLY cash/expense event for holiday goods.
	model.Ops._charge(model,expense,"supplies:%d" % int(building.id))
	current.pending=quantity
	current.arrival_at=_clock(model)+DELIVERY_MINUTES
	building.holiday_inventory=current
	return true

static func tick(model:RefCounted,date:Dictionary={})->void:
	if not model.Ops.active(model):return
	var now:Dictionary=Calendar.device_now() if date.is_empty() else date
	for building in model.buildings:
		if not Market.ITEMS.has(str(building.get("kind",""))):continue
		if not valid(building):continue
		# Deliver even after the calendar passes Christmas; paid stock is
		# preserved for the next annual season instead of silently expiring.
		receive(model,building)
		if int(model.minute)<480 or int(model.minute)>1020:continue
		if Market.active(str(building.kind),now).is_empty():continue
		var stock:int=int(building.get("holiday_inventory",{}).get("stock",0))
		var pending:int=int(building.get("holiday_inventory",{}).get("pending",0))
		if stock<REORDER_AT and pending==0:
			order(model,building,now,ORDER_UNITS)
