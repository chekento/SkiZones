extends RefCounted
## 0.40 specialist occupations: optional jobs must be relevant to the venue,
## and productivity gains are bounded by qualified, motivated on-duty staff.
## Existing generic mandatory roles remain untouched for old save continuity.
const ROLES := {
	"chef":{"name":"Koch / Köchin","wage":23.0,"throughput":0.16,"capacity":0.06,"quality":0.055},
	"waiter":{"name":"Servicekraft / Kellner","wage":19.0,"throughput":0.17,"capacity":0.11,"quality":0.025},
	"receptionist":{"name":"Hotelrezeption","wage":21.0,"throughput":0.12,"capacity":0.06,"quality":0.045},
	"housekeeper":{"name":"Housekeeping","wage":19.0,"throughput":0.12,"capacity":0.07,"quality":0.035},
	"ski_instructor":{"name":"Skilehrer / Skilehrerin","wage":25.0,"throughput":0.12,"capacity":0.15,"quality":0.06},
	"rental_tech":{"name":"Skiservice-Techniker","wage":22.0,"throughput":0.20,"capacity":0.12,"quality":0.035},
	"salesperson":{"name":"Fachverkäufer / Fachverkäuferin","wage":19.0,"throughput":0.16,"capacity":0.10,"quality":0.03},
	"lifeguard":{"name":"Badeaufsicht","wage":24.0,"throughput":0.07,"capacity":0.09,"quality":0.075},
	"spa_therapist":{"name":"Wellness-Therapeut / Therapeutin","wage":26.0,"throughput":0.11,"capacity":0.07,"quality":0.09},
	"night_host":{"name":"Eventservice","wage":22.0,"throughput":0.15,"capacity":0.13,"quality":0.04},
	"paramedic":{"name":"Rettungssanitäter / Rettungssanitäterin","wage":29.0,"throughput":0.12,"capacity":0.09,"quality":0.08}
}
const VENUES := {
	"restaurant":["chef","waiter"],
	"lodge":["chef","waiter"],
	"pizzeria":["chef","waiter"],
	"schmarrn":["chef","waiter"],
	"kiosk":["waiter"],
	"cocoa":["waiter"],
	"bar":["waiter","night_host"],
	"disco":["night_host"],
	"hotel":["receptionist","housekeeper"],
	"grand_hotel":["receptionist","housekeeper"],
	"guesthouse":["receptionist","housekeeper"],
	"school":["ski_instructor"],
	"rental":["rental_tech","salesperson"],
	"pool":["lifeguard"],
	"spa":["spa_therapist"],
	"fitness":["spa_therapist"],
	"souvenir":["salesperson"],
	"watchmaker":["rental_tech","salesperson"],
	"craftshop":["salesperson"],
	"printing_press":["rental_tech"],
	"newsstand":["salesperson"],
	"first_aid":["paramedic"]
}

static func optional_roles(kind: String) -> Array:
	return VENUES.get(kind,[]).duplicate()

static func allowed(role: String,kind: String) -> bool:
	return role in VENUES.get(kind,[])

## Only active people contribute. Additional staff beyond the third person
## per role do not increase capacity/turnover forever; skill and fatigue matter.
static func metrics(kind: String,people: Array) -> Dictionary:
	var counts:Dictionary={}
	var speed:=1.0
	var capacity:=1.0
	var quality:=1.0
	for person in people:
		if not person is Dictionary:continue
		var role:String=str(person.get("role",""))
		if not allowed(role,kind):continue
		counts[role]=int(counts.get(role,0))+1
		if int(counts[role])>3:continue
		var spec:Dictionary=ROLES[role]
		var qualified:float=clampf(float(person.get("qualification",1)),1.0,5.0)
		var motivation:float=clampf(float(person.get("motivation",85)),0.0,100.0)/100.0
		var fatigue:float=clampf(float(person.get("fatigue",0)),0.0,100.0)/100.0
		var effectiveness:float=clampf(0.55+qualified*0.10,0.0,1.05)*motivation*(1.0-fatigue*0.55)
		speed+=float(spec.throughput)*effectiveness
		capacity+=float(spec.capacity)*effectiveness
		quality+=float(spec.quality)*effectiveness
	return {"throughput":minf(speed,2.4),"capacity":minf(capacity,1.65),"quality":minf(quality,1.32),"specialists":counts}
