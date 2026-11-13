extends RefCounted
## Three practical decisions, earned qualifications, no invented guest sales.
const L=preload("res://src/core/i18n.gd")
const FEE=90
const DAILY_LIMIT=2
const CASES={
	"operator":["Ein Kind erreicht den Einstieg mit einem verdrehten Skistock.","Einstieg sichern und beim Ordnen helfen","Den Einstieg beschleunigen","Die Warteschlange ignorieren","Ein sicherer Einstieg hat Vorrang vor einer kürzeren Warteschlange."],
	"technician":["Eine Seilrolle meldet wiederholt ungewöhnliche Schwingungen.","Anlage sichern und die Ursache prüfen","Nur den Alarm quittieren","Die Geschwindigkeit erhöhen","Eine Störungsmeldung braucht eine geprüfte Ursache und eine dokumentierte Freigabe."],
	"electrician":["Nach einem Ausfall soll eine Steuerung wieder freigegeben werden.","Gesicherte Prüfung und Freigabe dokumentieren","Die Sicherung ungeprüft überbrücken","Den Alarm abschalten","Eine dokumentierte technische Prüfung gehört zur sicheren Wiederinbetriebnahme."],
	"driver":["Auf der vorgesehenen Präparierungsroute fahren noch Gäste.","Piste räumen lassen und den Einsatz abstimmen","Mit der Pistenraupe dazwischenfahren","Die Sperrung auslassen","Eine Präparierung beginnt erst auf einer freigegebenen, geräumten Strecke."],
	"rescue":["Ein Hilferuf kommt von der Mitte einer langen Abfahrt.","Zufahrt und Rücktransport gemeinsam prüfen","Nur die Luftlinie betrachten","Ohne Rückwegplanung starten","Zum Einsatz gehört ein erreichbarer Rückweg mit dem Patienten."],
	"medic":["Ein Rücktransport ist angekündigt, der Behandlungsplatz ist belegt.","Übergabe und freien Behandlungsplatz koordinieren","Die Ankunft unvorbereitet abwarten","Die Belegung verschweigen","Eine abgestimmte Übergabe hält Rettungsweg und Versorgungskapazität verlässlich."],
	"snow":["Starker Wind treibt den erzeugten Schnee von der Piste.","Bedingungen prüfen und Beschneiung anpassen","Unverändert mehr Wasser einsetzen","Die Wetterdaten ignorieren","Beschneiung muss zu Wetter und tatsächlichem Schneebedarf passen."],
	"hotel":["Eine Familie kommt an, ihr Zimmer ist noch nicht freigegeben.","Zimmerstatus prüfen und eine Warteoption anbieten","Ein ungeprüftes Zimmer zuweisen","Die Familie ohne Auskunft warten lassen","Eine verlässliche Auskunft und ein geprüfter Zimmerstatus verhindern Doppelbelegungen."],
	"receptionist":["Zwei Buchungen scheinen dasselbe Zimmer zu beanspruchen.","Belegung prüfen und eine verfügbare Alternative suchen","Beide Schlüssel ausgeben","Eine Buchung ungeprüft löschen","Erst die echte Belegung klären, dann eine nachvollziehbare Lösung anbieten."],
	"housekeeper":["Ein gereinigtes Zimmer hat noch einen gemeldeten Defekt.","Defekt melden und Freigabe zurückhalten","Das Zimmer sofort freigeben","Die Meldung entfernen","Sauberkeit und technische Freigabe sind unterschiedliche Voraussetzungen."],
	"catering":["Eine Bestellung enthält einen Hinweis auf Unverträglichkeiten.","Zutaten prüfen und Rückfrage mit der Küche halten","Die Zutaten erraten","Ein beliebiges Gericht servieren","Unklare Zutaten werden geklärt, bevor die Bestellung ausgegeben wird."],
	"chef":["Eine Zutat ist ausgegangen, mehrere Bestellungen warten.","Karte und Service über verfügbare Alternativen abstimmen","Die fehlende Zutat verschweigen","Alle Bestellungen ungeprüft bestätigen","Küche und Service brauchen dieselbe Information über das reale Angebot."],
	"waiter":["Am Tisch warten zwei ähnliche Bestellungen mit verschiedenen Wünschen.","Bestellung und Sonderwünsche vor dem Servieren abgleichen","Die Teller zufällig verteilen","Die Sonderwünsche überspringen","Ein kurzer Abgleich verhindert vermeidbare Reklamationen."],
	"barista":["Zwei Kakaobestellungen wünschen unterschiedliche Milchsorten.","Becher eindeutig zuordnen und Zutaten prüfen","Beide Becher gleich befüllen","Die Zuordnung dem Gast überlassen","Klare Zuordnung und geprüfte Zutaten gehören zum Getränkeservice."],
	"bartender":["An der Bar bestellt ein minderjähriger Gast ein alkoholisches Getränk.","Ein alkoholfreies Getränk anbieten","Trotzdem ausschenken","Die Altersprüfung überspringen","Zum verantwortlichen Service gehört eine passende alkoholfreie Alternative."],
	"vendor":["Die Kasse zeigt mehr verkaufte Waren als im Regal verfügbar waren.","Bestand und Buchungen abgleichen","Den Bestand willkürlich erhöhen","Die Differenz ignorieren","Verkauf und Warenbestand müssen auf denselben tatsächlichen Vorgängen beruhen."],
	"shop_assistant":["Ein Gast sucht ein kleines, transportierbares Andenken.","Passende verfügbare Artikel vergleichen","Nur den teuersten Artikel anbieten","Einen ausverkauften Artikel zusagen","Ein passendes Angebot berücksichtigt den Wunsch und die echte Verfügbarkeit."],
	"rental_specialist":["Die ausgegebene Ausrüstung passt nicht zur angegebenen Nutzung.","Eignung und Anpassung vor der Ausgabe prüfen","Die Ausrüstung ungeprüft herausgeben","Nur die Farbe vergleichen","Die Ausgabe folgt einer fachlichen Prüfung von Eignung und Anpassung."],
	"ski_instructor":["Ein Anfänger soll mit einer deutlich schnelleren Gruppe fahren.","Können prüfen und eine passende Gruppe wählen","Sofort die schwerste Piste wählen","Das Lerntempo der Anfänger ignorieren","Unterricht folgt dem tatsächlichen Können und einem erreichbaren Lernziel."],
	"fitness_trainer":["Ein Gast findet die vorgesehene Übung deutlich zu schwer.","Eine passende leichtere Variante anbieten","Die Belastung weiter erhöhen","Die Rückmeldung ignorieren","Eine angepasste Übung ermöglicht einen kontrollierten, verständlichen Einstieg."],
	"lifeguard":["Eine beaufsichtigte Zone ist schlecht einsehbar.","Sicht und Zuständigkeit vor der Öffnung klären","Die Zone unbeaufsichtigt öffnen","Nur ein weiteres Schild aufstellen","Aufsicht braucht eine einsehbare Zone und eine klare Zuständigkeit."],
	"therapist":["Zwei Wellness-Termine überschneiden sich im selben Raum.","Raumbelegung prüfen und einen Termin abstimmen","Beide gleichzeitig bestätigen","Die Überschneidung verschweigen","Termine müssen zur verfügbaren Raum- und Personalkapazität passen."],
	"watchmaker":["Eine Reparatur benötigt ein noch nicht verfügbares Ersatzteil.","Teil und Liefertermin vor der Zusage prüfen","Eine sofortige Fertigstellung versprechen","Ein beliebiges Teil einsetzen","Ein verlässlicher Werkstattauftrag braucht passende Teile und realistische Termine."],
	"artisan":["Ein Auftrag verlangt ein anderes Material als das vorhandene.","Eine geeignete Alternative mit dem Gast abstimmen","Das Material unbemerkt austauschen","Den Auftrag ungeprüft bestätigen","Änderungen am Auftrag werden erklärt und gemeinsam abgestimmt."],
	"printer":["Die Vorschau einer neuen Ausgabe zeigt einen abgeschnittenen Rand.","Druckvorlage vor dem Serienlauf korrigieren","Die ganze Auflage trotzdem drucken","Nur die Auflage erhöhen","Eine geprüfte Vorlage vermeidet Ausschuss in der gesamten Auflage."],
	"editor":["Eine wichtige Meldung enthält eine widersprüchliche Zeitangabe.","Quelle und Zeitpunkt vor Veröffentlichung prüfen","Die erste Angabe ungeprüft übernehmen","Den Widerspruch verschweigen","Eine belastbare Meldung braucht geprüfte Angaben und einen nachvollziehbaren Zeitpunkt."],
	"security":["Ein vereister Zugang liegt auf dem Hauptweg der Gäste.","Bereich sichern und die Beseitigung koordinieren","Den Zugang offen lassen","Nur die Meldung schließen","Eine gemeldete Gefahr bleibt gesichert, bis der Zugang wieder nutzbar ist."],
	"sanitation":["Der Füllstand eines Sanitärmoduls erreicht seine Betriebsgrenze.","Modul sichern und Entsorgung beauftragen","Weiter ohne Prüfung öffnen","Nur die Anzeige zurücksetzen","Reinigung, Entsorgung und Freigabe müssen zum tatsächlichen Zustand passen."]
}
const PRIORITIES={
	"technical":["Eine Störung ist gemeldet, gleichzeitig wartet ein Routineauftrag.","Die Störung bewerten und Einsätze abstimmen","Nur den kürzesten Auftrag wählen","Die Störung aus der Liste löschen","Dringlichkeit und Auswirkungen bestimmen die Reihenfolge."],
	"service":["Mehrere Gäste warten, eine Bestellung wurde falsch zugeordnet.","Fehler klären und die wartenden Gäste informieren","Den Fehler verbergen","Alle neuen Wünsche sofort zusagen","Ein geklärter Fehler und transparente Wartezeiten machen den Service verlässlich."],
	"care":["Die nächste Gruppe wartet, die Übergabe der vorherigen ist unklar.","Die Übergabe klären, bevor die nächste Betreuung beginnt","Die Zuständigkeit offenlassen","Beide Gruppen ungeprüft zusammenlegen","Eine klare Übergabe verhindert Lücken in der Betreuung."],
	"craft":["Mehrere Aufträge konkurrieren um dasselbe knappe Material.","Bestand prüfen und realistische Termine abstimmen","Alle Aufträge sofort bestätigen","Material doppelt verplanen","Ein vorhandener Bestand kann nicht gleichzeitig mehrfach eingesetzt werden."]
}
const HANDOFF=["Die Schicht endet mit einem noch offenen Auftrag.","Status, Zuständigkeit und nächsten Schritt übergeben","Den Auftrag als erledigt markieren","Ohne Übergabe gehen","Eine gute Übergabe benennt den realen Status und den nächsten verantwortlichen Schritt."]

static func group(role:String)->String:
	if role in ["operator","technician","electrician","driver","snow"]:return "technical"
	if role in ["rescue","medic","ski_instructor","fitness_trainer","lifeguard","therapist","security","sanitation"]:return "care"
	if role in ["watchmaker","artisan","printer","editor"]:return "craft"
	return "service"

static func person(model:RefCounted,id:int)->Dictionary:
	for employee in model.operations.staff:
		if int(employee.id)==id:return employee
	return {}

static func roster(model:RefCounted,asset:Dictionary)->Array:
	var targets:Array=["building:%d" % int(asset.get("id",-1))]
	if asset.has("bottom"):
		targets.clear()
		for part in model.Ops.line_lifts(model,asset):
			for station in model.Ops.station_demands(part):targets.append(str(station.key))
	return model.operations.staff.filter(func(p):return str(p.assignment) in targets and CASES.has(str(p.role)))

static func valid(state:Variant)->bool:
	if not state is Dictionary:return false
	for field in ["xp","day","attempts","best","serial","settled"]:
		var v:Variant=state.get(field)
		if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=floorf(float(v)) or float(v)<0:return false
	return state.xp<=600 and state.day<=1000000000 and state.attempts<=DAILY_LIMIT and state.best<=100 and state.serial<=1000000 and state.settled<=state.serial

static func start(model:RefCounted,id:int)->Dictionary:
	var employee:=person(model,id)
	if employee.is_empty() or not CASES.has(str(employee.role)):return model._result(false,L.text("Diese Fachkraft ist nicht mehr verfügbar."))
	if model.Ops._assigned_active_rescue(model,employee):return model._result(false,L.text("Ein laufender Rettungseinsatz hat Vorrang vor dem Training."))
	var old:Dictionary=employee.get("training",{})
	var attempts:int=int(old.get("attempts",0)) if int(old.get("day",0))==int(model.day) else 0
	if attempts>=DAILY_LIMIT or int(old.get("serial",0))>=1000000:return model._result(false,L.text("Heute sind beide Trainingsrunden dieser Fachkraft verbraucht."))
	if not model.can_afford(FEE):return model._result(false,L.text("Für dieses Training fehlen 90 € im Budget."))
	if model.campaign.get("mode","")!="free":model.Ops._expense(model,FEE,"training:%d" % id)
	var serial:int=int(old.get("serial",0))+1
	employee.training={"xp":int(old.get("xp",0)),"day":model.day,"attempts":attempts+1,"best":int(old.get("best",0)),"serial":serial,"settled":int(old.get("settled",0))}
	return {"ok":true,"person":id,"role":str(employee.role),"assignment":str(employee.assignment),"day":model.day,"serial":serial,"step":0,"score":0,"finished":false}

static func current(model:RefCounted,session:Dictionary)->bool:
	var employee:=person(model,int(session.get("person",-1)))
	if employee.is_empty() or not session.get("ok",false) or session.get("finished",false):return false
	var state:Dictionary=employee.get("training",{})
	return str(employee.role)==str(session.get("role","")) and str(employee.assignment)==str(session.get("assignment","")) and int(model.day)==int(session.get("day",-1)) and int(state.get("serial",-1))==int(session.get("serial",-2)) and int(state.get("settled",0))<int(session.serial)

static func challenge(model:RefCounted,session:Dictionary)->Dictionary:
	if not current(model,session) or int(session.get("step",3)) not in [0,1,2]:return {}
	var step:int=session.step
	var data:Array=CASES[str(session.role)] if step==0 else PRIORITIES[group(str(session.role))] if step==1 else HANDOFF
	var choices:Array=[]
	var offset:int=posmod(int(session.person)*7+int(session.serial)*11+step,3)
	for i in range(3):choices.append(data[1+posmod(i+offset,3)])
	return {"prompt":data[0],"choices":choices,"answer":posmod(-offset,3),"explanation":data[4]}

static func answer(model:RefCounted,session:Dictionary,choice:Variant)->Dictionary:
	var task:=challenge(model,session)
	if task.is_empty() or not choice is int or choice<0 or choice>=3:return model._result(false,L.text("Diese Trainingsrunde ist nicht mehr aktiv."))
	var score:int=100 if int(choice)==int(task.answer) else 0
	session.score=int(session.score)+score
	session.step=int(session.step)+1
	var result:Dictionary={"ok":true,"score":score,"explanation":task.explanation,"correct":task.choices[int(task.answer)],"finished":int(session.step)==3}
	if not result.finished:return result
	var employee:=person(model,int(session.person))
	var average:int=roundi(float(session.score)/3.0)
	var earned:int=roundi(float(average)*0.36)
	var state:Dictionary=employee.training
	state.settled=int(session.serial)
	state.xp=mini(600,int(state.xp)+earned)
	state.best=maxi(int(state.best),average)
	var before:int=employee.qualification
	employee.qualification=maxi(before,3 if int(state.xp)>=240 else 2 if int(state.xp)>=100 else 1)
	employee.motivation=minf(100,float(employee.motivation)+(3.0 if earned>0 else 0.0))
	model._duty_cache.clear()
	model.Ops.refresh_duty(model)
	model._operational_change()
	session.finished=true
	result.merge({"average":average,"earned":earned,"qualification":employee.qualification,"promoted":int(employee.qualification)>before})
	return result
