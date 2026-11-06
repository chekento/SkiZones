extends RefCounted
## Hotel Simulator: a five-stage real operating shift, not a questionnaire.
## Every action touches existing bookings, room stock, the operating ledger,
## hotel pricing or a validated sanitary-service module.
## Read-only overview never upgrades legacy saves or invents hotel guests.
const Rooms = preload("res://src/core/hotel_rooms.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const L = preload("res://src/core/i18n.gd")
const MAX_EXTRA_WCS := 8
const STAGES := ["reception","housekeeping","breakfast","guest_service","revenue"]
const TITLES := ["Rezeption & Buchungen","Housekeeping & Zimmer","Frühstück & Gästeservice","Gästekomfort & Service","Zimmerpreise & Ertrag"]

static func _hotel(building: Dictionary) -> bool:
	return Catalog.LODGING.has(str(building.get("kind","")))

static func _base_units(building: Dictionary) -> int:
	return maxi(1,ceili(float(Rooms.capacity(building))/14.0))

static func _default_sanitation(model: RefCounted, building: Dictionary) -> Dictionary:
	return {"version":1,"extra_units":0,"hygiene":100.0,"last_day":int(model.day),"serviced":0}

static func sanitary_status(model: RefCounted, building: Dictionary) -> Dictionary:
	if not _hotel(building): return {}
	var saved: Dictionary=building.get("sanitation",_default_sanitation(model,building))
	var units := _base_units(building)+int(saved.get("extra_units",0))
	var occupancy: int=model.Lodging.rooms_used(model,int(building.id))
	var visits: int=int(building.get("visits",0))
	# Occupied rooms contribute actual hotel traffic, with a bounded daily
	# day-visitor share, not a fabricated guest counter.
	var demand := occupancy*2 + mini(22,visits%23)
	var coverage := units*9
	return {"enabled":building.has("sanitation"),"units":units,"hygiene":float(saved.get("hygiene",100.0)),
		"demand":demand,"capacity":coverage,"waiting":maxi(0,demand-coverage),"extra_units":int(saved.get("extra_units",0)),
		"clean_cost":25*units,"expand_cost":1400+400*int(saved.get("extra_units",0))}

static func sanitation_action(model: RefCounted, id: int, action: String) -> Dictionary:
	var building: Dictionary=model.asset(id)
	if not _hotel(building):return model._result(false,L.text("Eine eigene Unterkunft wählen."))
	var state: Dictionary=building.get("sanitation",_default_sanitation(model,building)).duplicate(true)
	if action=="activate":
		if building.has("sanitation"):return model._result(false,L.text("Sanitärbetrieb ist bereits aktiv."))
		building.sanitation=state
		return model._result(true,L.text("Sanitärbetrieb mit WC-Kapazität und Hygiene aktiviert."))
	if not building.has("sanitation"):return model._result(false,L.text("Zuerst den Sanitärbetrieb aktivieren."))
	var info: Dictionary=sanitary_status(model,building)
	if action=="clean":
		if float(state.hygiene)>=99.99:return model._result(false,L.text("Alle Toiletten sind bereits sauber."))
		var cost: int=int(info.clean_cost)
		if not model.Ops._expense(model,cost,"supplies:%d"%id):return model._result(false,L.text("Für die WC-Reinigung reicht das Budget nicht."))
		state.hygiene=100.0
		state.serviced=int(state.serviced)+1
		building.sanitation=state
		return model._result(true,L.text("Sanitäranlagen gereinigt · %d € Material und Arbeitsaufwand.") % cost)
	if action=="expand":
		if int(state.extra_units)>=MAX_EXTRA_WCS:return model._result(false,L.text("Maximale Sanitärkapazität erreicht."))
		if model.campaign.get("mode","career")!="free" and not model.Progression.has(model,"sanitation"):
			return model._result(false,L.text("Forschungszweig Sanitärtechnik zuerst freischalten."))
		var cost: int=int(info.expand_cost)
		if not model._spend(cost):return model._result(false,L.text("Für neue Sanitäranlagen reicht das Budget nicht."))
		state.extra_units=int(state.extra_units)+1
		building.sanitation=state
		return model._result(true,L.text("Eine zusätzliche WC-Einheit ist verfügbar · %d € investiert.") % cost)
	return model._result(false,L.text("Unbekannte Sanitäraktion."))

static func daily(model: RefCounted, building: Dictionary) -> void:
	if not building.has("sanitation"):return
	var state: Dictionary=building.sanitation
	var elapsed: int=maxi(0,int(model.day)-int(state.last_day))
	if elapsed<=0:return
	var demand: Dictionary=sanitary_status(model,building)
	var pressure: float=float(demand.demand)/maxf(1.0,float(demand.capacity))
	var hygiene_loss: float=minf(48.0,7.0 + 8.0*pressure)
	state.hygiene=clampf(float(state.hygiene)-hygiene_loss*mini(elapsed,10),0.0,100.0)
	state.last_day=int(model.day)
	building.sanitation=state

static func overview(model: RefCounted, building: Dictionary) -> Dictionary:
	var room: Dictionary=Rooms.view(model,building)
	var accounting: Dictionary=model.Hospitality.dashboard(model,building)
	var toilets: Dictionary=sanitary_status(model,building)
	var work: Dictionary=building.get("activity",{}).get("hotel_shift",{})
	return {"rooms":room,"economy":accounting,"toilets":toilets,"shift_done":int(work.get("day",-1))==model.day and int(work.get("steps",0))>=5,
		"last_score":int(work.get("score",0)),"rating":float(model.Hospitality.config(building).rating)}

static func begin(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary=model.asset(id)
	if not _hotel(building):return {"ok":false,"message":L.text("Eine eigene Unterkunft wählen.")}
	if bool(overview(model,building).shift_done):return {"ok":false,"message":L.text("Die heutige Hotelschicht ist abgeschlossen. Morgen warten neue Aufgaben.")}
	if not building.has("room_operations"):
		var started: Dictionary=Rooms.enable(model,id)
		if not started.ok:return started
	# Hotels and restaurants include their own toilets. Public portable WC
	# management is an independent building system, not a hotel upgrade.
	var activity: Dictionary=building.get("activity",{"day":0,"plays":0,"best":0,"bonus":0,"rounds":0}).duplicate(true)
	var saved: Dictionary=activity.get("hotel_shift",{})
	if int(saved.get("day",-1))==model.day and int(saved.get("steps",0))<5:
		return {"ok":true,"id":id,"day":model.day,"step":int(saved.get("steps",0)),
			"score":int(saved.get("score",0)),"actions":saved.get("actions",[]).duplicate()}
	activity.hotel_shift={"day":int(model.day),"score":0,"steps":0,"actions":[]}
	building.activity=activity
	return {"ok":true,"id":id,"day":model.day,"step":0,"score":0,"actions":[]}

static func situation(model: RefCounted, building: Dictionary, step: int) -> Dictionary:
	var stats: Dictionary=overview(model,building)
	var settings: Dictionary=model.Hospitality.config(building)
	var rooms: Dictionary=stats.rooms
	var account: Dictionary=stats.economy
	var stage := clampi(step,0,4)
	var result := {"name":TITLES[stage],"stage":STAGES[stage],"prompt":"","choices":[],"description":""}
	match stage:
		0:
			result.prompt=L.text("Ein neuer Ankunftstag beginnt. Wie organisierst du die Rezeption?")
			result.description=L.text("%d freie Zimmer · %d bestehende Buchungen · %d ungeklärte Zimmer") % [int(rooms.ready),int(rooms.occupied),int(rooms.unassigned)]
			result.choices=[L.text("Kapazität prüfen und Ankünfte koordinieren"),L.text("Zusätzlichen Gästeservice organisieren · 120 €"),L.text("Ohne Prüfung abwarten")]
		1:
			result.prompt=L.text("Der Zimmerdienst beginnt. Wie bereitest du die nächsten Buchungen vor?")
			result.description=L.text("%d Zimmer zu reinigen · %d nutzbar") % [int(rooms.dirty),int(rooms.ready)]
			result.choices=[L.text("Ein schmutziges Zimmer reinigen · 8 €"),L.text("Alle freien Zimmer reinigen · Kosten nach Bedarf"),L.text("Reinigung verschieben")]
		2:
			result.prompt=L.text("Vor dem ersten Liftbetrieb braucht dein Hotel einen Serviceplan.")
			result.description=L.text("Frühstück: %s · Sauberkeit %.0f %%") % [L.text("aktiv") if settings.breakfast else L.text("aus"),float(settings.cleanliness)]
			result.choices=[L.text("Frühstück und warmen Empfang anbieten"),L.text("Frühstücksangebot deaktivieren"),L.text("Servicequalitätsschulung · 85 €")]
		3:
			result.prompt=L.text("Wie verbesserst du heute den Komfort deiner Hotelgäste?")
			result.description=L.text("Zimmerkomfort %d/5 · Bewertung %.1f ★ · Sauberkeit %.0f %%") % [int(settings.comfort),float(settings.rating),float(settings.cleanliness)]
			result.choices=[L.text("Gästezufriedenheit prüfen"),L.text("Zimmerkomfort aufwerten"),L.text("Service- und Empfangsschulung · 85 €")]
		4:
			result.prompt=L.text("Der Tagesabschluss: Welche Zimmerpreisstrategie wählst du?")
			result.description=L.text("%d/%d Zimmer · aktueller Preis %.0f € · Prognose %.0f €/Tag") % [int(account.occupied),int(account.capacity),float(account.price),float(account.forecast)]
			result.choices=[L.text("Attraktiven Tarif setzen · −10 %"),L.text("Kostenorientierten Tarif berechnen"),L.text("Premiumpreis setzen · +10 %")]
	return result

static func choose(model: RefCounted, session: Dictionary, option: int) -> Dictionary:
	if not session.get("ok",false) or int(session.get("day",-1))!=model.day or int(session.get("step",0))>=5 or option<0 or option>2:
		return {"ok":false,"message":L.text("Die Hotelschicht ist nicht mehr aktiv.")}
	var building: Dictionary=model.asset(int(session.id))
	if not _hotel(building):return {"ok":false,"message":L.text("Das Hotel ist nicht mehr verfügbar.")}
	if overview(model,building).shift_done:return {"ok":false,"message":L.text("Diese Hotelschicht wurde bereits abgerechnet.")}
	var stored: Dictionary=building.get("activity",{}).get("hotel_shift",{})
	if int(stored.get("day",-1))!=model.day or int(stored.get("steps",-1))!=int(session.step) or int(stored.get("score",-1))!=int(session.score):
		return {"ok":false,"message":L.text("Die Hotelschicht wurde bereits verändert. Bitte erneut öffnen.")}
	var stage: int=int(session.step)
	var gained := 0
	var message := ""
	var result: Dictionary={}
	var hotel: Dictionary=model.Hospitality.config(building)
	match stage:
		0:
			if option==0:
				gained=22 if Rooms.view(model,building).unassigned==0 else 16
				message=L.text("Buchungen und freie Zimmer geprüft. Keine Doppelbelegung.")
			elif option==1:
				if not model.Ops._expense(model,120,"building:%d"%int(building.id)):
					return {"ok":false,"message":L.text("Für zusätzlichen Gästeservice reichen 120 € nicht.")}
				hotel.rating=minf(5.0,float(hotel.rating)+0.04)
				building.hotel=hotel
				gained=25
				message=L.text("Zusätzliche Rezeptionsbetreuung bezahlt; Servicebewertung verbessert.")
			else:
				message=L.text("Ankünfte bleiben ungeprüft; keine Buchung wurde verändert.")
		1:
			var rows: Dictionary=Rooms.view(model,building)
			if option==0 and int(rows.dirty)>0:
				var dirty: Dictionary=rows.rooms.filter(func(r):return r.reservation=="" and not r.clean)[0]
				result=Rooms.clean_room(model,int(building.id),int(dirty.id))
				if not result.ok:return result
				gained=18
				message=str(result.message)
			elif option==1 and int(rows.dirty)>0:
				result=Rooms.clean_all(model,int(building.id))
				if not result.ok:return result
				gained=25
				message=str(result.message)
			elif option in [0,1]:
				gained=12
				message=L.text("Alle verfügbaren Zimmer sind bereits sauber und buchbar.")
			else:
				message=L.text("Zimmerreinigung verschoben; ungereinigte Zimmer bleiben gesperrt.")
		2:
			if option==0:
				result=model.Hospitality.configure(model,int(building.id),{"breakfast":true})
				gained=20 if not hotel.breakfast else 16
				message=str(result.message)
			elif option==1:
				result=model.Hospitality.configure(model,int(building.id),{"breakfast":false})
				gained=6
				message=str(result.message)
			else:
				if not model.Ops._expense(model,85,"building:%d"%int(building.id)):
					return {"ok":false,"message":L.text("Für die Serviceschulung reichen 85 € nicht.")}
				hotel.cleanliness=minf(100.0,float(hotel.cleanliness)+6.0)
				hotel.rating=minf(5.0,float(hotel.rating)+0.025)
				building.hotel=hotel
				gained=22
				message=L.text("Team geschult: Hotelhygiene und Gästebewertung steigen.")
		3:
			if option==0:
				gained=12
				message=L.text("Zimmerkomfort, Gästezufriedenheit und Serviceleistungen wurden geprüft.")
			elif option==1:
				result=model.Hospitality.upgrade(model,int(building.id))
				if not result.ok:return result
				gained=25
				message=str(result.message)
			else:
				if not model.Ops._expense(model,85,"building:%d"%int(building.id)):
					return {"ok":false,"message":L.text("Für die Serviceschulung reichen 85 € nicht.")}
				hotel.rating=minf(5.0,float(hotel.rating)+0.04)
				building.hotel=hotel
				gained=20
				message=L.text("Empfang geschult: Gästebewertung verbessert.")
		4:
			var current: int=roundi(model.Hospitality.room_price(model,building))
			var target := current
			if option==0:target=maxi(45,roundi(current*0.90))
			elif option==1:
				var data: Dictionary=model.Hospitality.dashboard(model,building)
				target=clampi(ceili(float(data.cost)/maxf(1.0,float(data.capacity)*0.7)),45,350)
			else:target=mini(350,roundi(current*1.10))
			result=model.Hospitality.configure(model,int(building.id),{"price":target})
			if not result.ok:return result
			gained=22 if option==1 else 17 if option==0 else 10
			message=L.text("Zimmerpreis ist auf %d € je Nacht eingestellt. Neue Buchungen verwenden den Tarif.") % target
	session.score=int(session.score)+gained
	session.step=stage+1
	session.actions.append(option)
	var finished: bool=int(session.step)>=5
	var activity: Dictionary=building.get("activity",{"day":0,"plays":0,"best":0,"bonus":0,"rounds":0}).duplicate(true)
	activity.hotel_shift={"day":int(model.day),"score":int(session.score),"steps":int(session.step),"actions":session.actions.duplicate()}
	building.activity=activity
	if finished:
		model.campaign.xp+=float(session.score)*0.25
		message+="\n"+(L.text("Schicht abgeschlossen · %d / 125 Punkte · echte Betriebsentscheidungen gespeichert.") % int(session.score))
	return {"ok":true,"finished":finished,"score":gained,"total":int(session.score),"message":message}

static func valid(building: Dictionary) -> bool:
	if not building.has("sanitation"):return true
	if not _hotel(building):return false
	var state: Variant=building.sanitation
	if not state is Dictionary or state.size()!=5:return false
	if not Terrain.number(state.get("version")) or state.version!=1:return false
	for key in ["extra_units","last_day","serviced"]:
		if not Terrain.number(state.get(key)) or state[key]!=floorf(float(state[key])):return false
	if state.extra_units<0 or state.extra_units>MAX_EXTRA_WCS or state.last_day<1 or state.last_day>100000 or state.serviced<0 or state.serviced>100000:return false
	return Terrain.number(state.get("hygiene")) and state.hygiene>=0 and state.hygiene<=100

static func valid_shift(building: Dictionary) -> bool:
	if not building.has("activity"):return true
	var value: Variant=building.activity.get("hotel_shift",{})
	if value=={}:return true
	if not _hotel(building) or not value is Dictionary or value.size() not in [3,4]:return false
	for key in ["day","score","steps"]:
		if not Terrain.number(value.get(key)) or value[key]!=floorf(float(value[key])):return false
	if value.day<1 or value.day>100000 or value.score<0 or value.score>125 or value.steps<0 or value.steps>5:return false
	if not value.has("actions"):return value.steps==5
	if not value.actions is Array or value.actions.size()!=int(value.steps):return false
	for choice in value.actions:
		if not Terrain.number(choice) or choice!=floorf(float(choice)) or int(choice)<0 or int(choice)>2:return false
	return true
