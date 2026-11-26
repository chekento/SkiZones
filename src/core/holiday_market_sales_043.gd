extends RefCounted
## Small seasonal retail assortment. A seasonal product REPLACES one ordinary
## product in an actual completed visit; it is never a second sale, subsidy,
## automatic visitor spawn or stand-alone cash reward.
const Calendar=preload("res://src/core/annual_festival.gd")
const HOLIDAY_DAYS:=[6,24,25,26]
const CHRISTMAS_DAYS:=[24,25,26]
const ITEMS:={
	"cocoa":{"id":"holiday_cocoa","name":"Festtags-Kakao","price":8.50,"cost":3.20,"category":"drink","days":HOLIDAY_DAYS},
	"kiosk":{"id":"holiday_punch","name":"Weihnachtspunsch","price":7.50,"cost":2.75,"category":"drink","days":HOLIDAY_DAYS},
	"schmarrn":{"id":"holiday_schmarrn","name":"Festtags-Schmarrn","price":17.00,"cost":6.40,"category":"food","days":CHRISTMAS_DAYS},
	"restaurant":{"id":"holiday_menu","name":"Weihnachtsmenü","price":27.00,"cost":12.70,"category":"food","days":CHRISTMAS_DAYS},
	"souvenir":{"id":"holiday_gift","name":"Weihnachtsgeschenk","price":17.00,"cost":6.40,"category":"retail","days":HOLIDAY_DAYS},
	"craftshop":{"id":"holiday_star","name":"Holz-Weihnachtsstern","price":22.00,"cost":8.50,"category":"retail","days":HOLIDAY_DAYS}
}

static func all_for(kind:String)->Array:
	if not ITEMS.has(kind):return []
	var item:Dictionary=ITEMS[kind].duplicate(true)
	item.erase("days")
	item.level=1
	item.asset="upgrade-%s-%s" % [kind,str(item.id)]
	return [item]

static func active(kind:String,date:Dictionary={})->Array:
	if not ITEMS.has(kind):return []
	var now:Dictionary=Calendar.device_now() if date.is_empty() else date
	if not Calendar.valid_date(now) or int(now.month)!=12:return []
	if int(now.day) not in ITEMS[kind].days:return []
	return all_for(kind)

static func valid_catalog()->bool:
	var seen:Dictionary={}
	for kind in ITEMS:
		var item:Dictionary=ITEMS[kind]
		if str(item.get("id","")).is_empty() or seen.has(str(item.id)):return false
		seen[str(item.id)]=true
		if not item.get("name") is String or str(item.name).is_empty():return false
		if str(item.get("category","")) not in ["food","drink","retail"]:return false
		if not item.get("price") is float and not item.get("price") is int:return false
		if not item.get("cost") is float and not item.get("cost") is int:return false
		if not is_finite(float(item.price)) or not is_finite(float(item.cost)):return false
		if float(item.price)<=0.0 or float(item.cost)<=0.0 or float(item.cost)>=float(item.price):return false
		var days:Variant=item.get("days")
		if not days is Array or days.is_empty():return false
		for day in days:
			if day not in HOLIDAY_DAYS:return false
	return true
