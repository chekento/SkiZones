extends RefCounted
## Local, deterministic applicant board. Extra qualifications require suitable
## facilities and resort progression. No account, network or new save schema.
const Ops=preload("res://src/core/operations.gd")
const NAMES := ["Lena Vogt","Mika Holm","Noah Berg","Finja Winter","Amir Kaya","Elin Lind","Robin Seidel","Juna Wolf","Sam Falk","Mara Busch","Toni Adler","Kim Nielsen","Lea Hansen","Jules Frank","Nico Roth","Lotte Brandt","Alex Fischer","Nika Sturm"]
const FACILITIES := {
	"operator":["lift"], "technician":["repair_office"], "electrician":["repair_office"],
	"driver":["maintenance"], "rescue":["first_aid"], "snow":["snowmaker"],
	"hotel":["hotel","grand_hotel","guesthouse","chalet","apartment","cabin"],
	"catering":["restaurant","pizzeria","bar","cocoa","schmarrn","kiosk","lodge"],
	"security":[],
	"chef":["restaurant","lodge","pizzeria","schmarrn","hotel","grand_hotel","guesthouse"],
	"waiter":["restaurant","lodge","pizzeria","schmarrn","cocoa"],
	"barista":["cocoa"],"bartender":["bar","disco"],"vendor":["kiosk","newsstand"],
	"rental_specialist":["rental"],"ski_instructor":["school"],"fitness_trainer":["fitness"],
	"lifeguard":["pool"],"therapist":["spa"],"shop_assistant":["souvenir"],
	"watchmaker":["watchmaker"],"artisan":["craftshop"],"printer":["printing_press"],
	"editor":["printing_press"],"housekeeper":["hotel","grand_hotel","guesthouse"],
	"receptionist":["hotel","grand_hotel"],"medic":["first_aid"]
}
static func market(model: RefCounted) -> Array:
	var result: Array=[]
	# Keep the historic 18 candidate IDs and their original professions.
	# Append specialist applicants instead of silently changing an old hire.
	var legacy_roles:Array=["operator","technician","electrician","driver","rescue","snow","hotel","catering","security","sanitation"]
	var specialties:Array=Ops.ROLES.keys().filter(func(role):return role not in legacy_roles)
	for i in range(NAMES.size()+specialties.size()):
		var role:String=str(legacy_roles[i % legacy_roles.size()]) if i<NAMES.size() else str(specialties[i-NAMES.size()])
		var level:int=1 if i<legacy_roles.size() or i>=NAMES.size() else 2
		var id: String="applicant-%02d" % i
		var reason: String=gate(model,role,level)
		var already: bool=model.operations.staff.any(func(p):return str(p.get("applicant_id",""))==id)
		result.append({
			"id":id,"name":NAMES[i%NAMES.size()] if i<NAMES.size() else NAMES[i%NAMES.size()]+" · "+str(Ops.ROLES[role].name),"role":role,"qualification":level,
			"experience":2+i*3,"motivation":77+(i%5)*4,
			"specialty": ["Gästebetreuung","Sicherheitsroutinen","Nachtdienst","Bergwetter","Teamkoordination","Technikdiagnose"][i%6],
			"fee":180 if level==1 else 380,
			"reason":"Bereits eingestellt" if already else reason,
			"available":reason.is_empty() and not already
		})
	return result
static func gate(model: RefCounted, role: String, level: int) -> String:
	if not Ops.ROLES.has(role):return "Unbekanntes Berufsbild"
	var needed: Array=FACILITIES.get(role,[])
	if role=="operator" and model.lifts.is_empty():return "Erfordert mindestens einen Lift"
	if not needed.is_empty() and not needed.has("lift"):
		var exists: bool=model.buildings.any(func(b):return b.enabled and str(b.kind) in needed)
		if not exists:return "Erfordert passende Einrichtung: " + " / ".join(PackedStringArray(needed))
	if level>=2 and int(model.campaign.get("rank",1))<2:
		return "Ab Resort-Stern 2: geprüfte Zusatzqualifikation"
	return ""
static func hire_candidate(model: RefCounted, id: String, target: String, shift: String = "day") -> Dictionary:
	var chosen: Dictionary={}
	for item in market(model):
		if item.id==id:chosen=item;break
	if chosen.is_empty():return model._result(false,"Bewerbung nicht gefunden.")
	if not chosen.available:return model._result(false,str(chosen.reason))
	if not model.can_afford(float(chosen.fee)):return model._result(false,"Budget für die Einstellung reicht nicht.")
	var result: Dictionary=Ops.hire(model,str(chosen.role),target,shift)
	if not result.ok:return result
	var staff: Dictionary=model.operations.staff[-1]
	staff.name=str(chosen.name)
	staff.qualification=int(chosen.qualification)
	staff.motivation=float(chosen.motivation)
	staff["applicant_id"]=str(chosen.id)
	staff["specialty"]=str(chosen.specialty)
	staff["experience"]=int(chosen.experience)
	var surplus: float=float(chosen.fee)-180.0
	if surplus>0.0:Ops._expense(model,surplus,"recruitment")
	model._operational_change()
	return model._result(true,str(chosen.name)+" eingestellt · "+str(chosen.specialty)+".")
