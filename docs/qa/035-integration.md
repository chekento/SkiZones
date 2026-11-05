# SkiZones 0.35 — Anforderungsabgleich und Integrationsnachweis

Stand: 5. November 2026. Basis `b3a3f29` / 0.34.1, lokaler Zweig `release/035-complete-resort`. **Noch keine öffentliche 0.35-APK.**

Die Anforderungen wurden gegen die letzten Projektgespräche, offene Issues #10, #15, #20, #21, #25, #44–47, #63–69, #71, #73, #75 und #76 sowie den tatsächlich vorhandenen Quellcode geprüft. „Im Code“ bedeutet keine Android-Freigabe.

| Anforderung | Tatsächlicher Stand dieses Kandidaten | Nachweis / verbleibende Arbeit |
| --- | --- | --- |
| Besucher ab jedem neuen Tag | Hotfix aus 0.34.1 integriert, Schneeschmelze mit korrigiertem Zeitmaß, echte Aufnahme und Tickets | 49 Hotfix-Prüfungen |
| Hotelmorgen 07–09 Uhr | Individuelle Zeiten 07:00–08:59, Familien gemeinsam, Wiederholung bei fehlender Route | Hotfix-, Hotel- und Nachtprüfungen |
| Alte Spielstände, freie Slots, eindeutiges Speichern | Recovery und vier freie Slots aus 0.33.2 erhalten; neue Zusatzfelder validiert | 21 Save-Recovery-Prüfungen und v16→v17; je 48 Wiederherstellungsprüfungen mit Original-0.19-/0.27-Daten |
| Voll bedienbares Radio ohne Checkbox-Leiste | Ein/Aus, 15 Presets, Sender vor/zurück, nächster Titel, Credits, 3 Lautstärken; 16 eigene SVG-Logos | 64 Geräte-/Layoutprüfungen; kompaktere Mobilansicht nach Sichtkontrolle |
| Senderwechsel sofort, laufende Sendersynchronität | Bestehender Echtzeit-Programmplan bleibt aktiv, kein Übernehmen | 100 Offline-Radio-Prüfungen |
| Mehr und passendere freie Musik | Bestehende CC0-Bibliothek und Genrezuordnung übernommen; kein SoundCloud | Kein neu beschafftes externes Musikpaket; echte zusätzliche Punk-/Volksmusik-Recherche bleibt offen |
| Gemeinsames Banner für Songs, Missionen und Erfolge | Priorisiert, dedupliziert, transparent, touchdurchlässig; Meldungsarchiv mit Navigation | 20 Modell- und 10 Radio/HUD-Prüfungen |
| Schneewege nach Neuladen | Echte Fußabnutzung in atomarem v17-Save; saubere Slot-/Resorttrennung | 12 Persistenzprüfungen, ungültige Daten atomar abgewiesen |
| Fünf wirtschaftliche Startstufen | Bestehende Kapitalprofile erhalten; differenzierte Kreditzinsen und echte Wareneinsätze ergänzt | 13 Startprofil-Prüfungen; vollständiger 100-Seed-/Mehrwinter-Balancebericht noch offen |
| 33 Gebäude mit eigenen Angeboten | 167 benannte Angebote und reale Ausbauoberfläche; Stufen 1–5 erreichbar | 457 Katalog-/Kreditprüfungen, Retail-Test bis Stufe 5 |
| Tatsächliche Speisen-/Getränke-/Souvenirverkäufe | Gewählter Artikel pro Gast/Gruppe ersetzt Pauschalgebühr, Wareneinsatz getrennt von Lohn | 20 reale Verkaufs-/Ausbau-/Save-Prüfungen |
| Pizzakarten mit Zutaten, Preisen und mehreren Plätzen | Alte Namen/Zutaten erhalten; Kalkulation, optionale Preise, bis 5 Plätze; höhere Preise senken Käufe | Wirtschaft, Hospitality und Familienbedürfnisse geprüft |
| Kurse, Rettung, Fahrzeuge, Warenlager | Bestehende Betriebsmodelle und Katalog vorhanden | Neue tiefe Inventar-, Kurs-, Fahrzeug- und Forschungsmechanik noch unvollständig |
| 6+1 echte Kredite | 6 feste Pakete, Wunschkredit, 3 Tilgungsarten, Stundung, Vorschau, reale Rückzahlung und Altvertrag | 16 Kredit-/Save-/Idempotenzprüfungen plus Katalogrechnung |
| Intelligente Pistenplanung | Fixierte Route-/Statistikumschaltung, automatisch ab Punkt 1, live bei Verschieben, manuelle Tabwahl und Reset | 28 integrierte Planungs-/Spiel-/Kredit-UI-Prüfungen |
| Mindestens ein weiteres echtes Minispiel | Reaktionsspiel mit 5 zeitgemessenen Startrunden, Fehlstart, Median/Bestzeit in vorhandenen Spielecken | Integrierte UI-Prüfung; keine künstliche Geldbelohnung |
| Vollständige mobile Oberflächenüberarbeitung | Bestehende responsive Panels erhalten; Radio, Angebot-/Finanzseiten und Planungsfläche erweitert | 360×740, 420×860, 740×360; eine komplette Neugestaltung jeder Ansicht bleibt offen |
| Logo, Kompass, Kamera, Bauansicht | Breiter Schriftzug, Portrait-HUD, Liftgeländekamera und 1×/4×/8× aus 0.34 erhalten | Bestehende Mobil-/Header-/Kameratests im vollständigen Workflow |
| Fahrbare Szenarien und Missionen | Alle vier Szenarien aktiv; Personal-, Bauplatz- und Missionstests übernommen; einzelne Missionen melden einmalig | Nicht jede importierte Realpiste besitzt einen vollständigen Rundweg; siehe 032-route-coverage.md |
| Mehr NPC-Tiefe, Hotel-/Busverknüpfung | Bestehende Bedürfnisse, Familien, echte Hotelwege, Nachtverkehr und Transit erhalten | Keine neue vollständige Reise-/Bus-/Crew-Simulation in diesem Kandidaten |
| Hotel-Tycoon, freier Modulbau und Forschung | Bestehende lineare 8er-Ketten, Hotelverwaltung, echte Übernachtungen und Hotelgeschichte bleiben erhalten | Freier mehrgeschossiger Bauplan, Einzelzimmerzustände und 100 Hotel-Forschungen noch offen |
| Toilet Tycoon und 100 WC-Forschungen | Anforderung vollständig erfasst | Noch kein implementierter Sanitärsimulator; keine als spielbar ausgegebene Platzhalterseite |
| 10 grafisch unterschiedliche Themes und Saisonassets | Bestehende Asset-Sprachen und Festtagsobjekte erhalten | Nicht alle 750 Hotel-Theme-/Saisonkombinationen produziert |
| Advent, Weihnachten, Silvester und Zeitung | Vorhandene Kalender-/Zeitungs-/Festivalfunktionen erhalten | Vollständige Geschenk-/Markt-/Festhandlungswelt noch offen |
| 1000 Erfolge und 500 Ränge | Bestehende Definitionen und Fortschritt erhalten | 2499 Achievement-Prüfungen; kein vollständiger menschlicher Erreichbarkeits-/Balanceaudit |
| Weniger Ruckeln, bessere Geometrie | Vorberechnete exakte Geländeabfragen, Liftzustand einmal pro Bild, konservativer Bauplatzcache | 19 Gelände- und 29 Personal-/Szenarioprüfungen; keine neue Android-FPS-Zusage |
| Neue signierte APK und vollständiger Changelog | 0.35.0 / Android versionCode 44 vorbereitet; alle neuen Tests in Hauptworkflow | Öffentlicher Upload und anschließende Veröffentlichung freigegeben; CI, Signatur und Android-30/36-Upgrade sind die laufenden Release-Gates |

## Zusammenführung

Die tatsächlichen Codeänderungen der Entwicklungszweige #74 (Radio/Meldungen), #72 (Angebote/Kredite), #65 (Schneepersistenz) und #41 (Bewegungsleistung) sind auf der 0.34.1-Basis kombiniert. Übersetzungskonflikte wurden unter Erhalt beider Kataloge und ohne doppelte msgids aufgelöst. Zusätzlich wurden Kompilierungsfehler in den neuen Gebäude-/Kreditoberflächen behoben.

## Testumgebung und Grenzen

Lokale Prüfung mit der offiziellen Godot-Version **4.5.2**, deren Editorarchiv gegen den offiziellen SHA-512-Katalog geprüft wurde. Headless-Modelltests verwenden voneinander isolierte `XDG_DATA_HOME`-Verzeichnisse. Oberflächen werden mit Xorg-Dummy und Mesa llvmpipe tatsächlich gerendert; Screenshots sind keine Mockups. Alle Sprachtexte werden auf Katalogdeckung und unveränderte Platzhalter geprüft.

Mehrere bestehende UI-Tests melden beim Prozessende verbliebene Ressourcen/Canvas-RIDs. Das wird nicht als bestandener Android-Lifecycle-Test dargestellt. Maßgeblich bleiben das vollständige Android-Gate und die signierte Upgradeprüfung nach dem öffentlichen Upload.

## Nachweis alter Originaldaten

Die offiziellen Tags `v0.19.0` und `v0.27.0` wurden jeweils in einem getrennten, unveränderten Arbeitsbaum ausgeführt. Aus jeder der acht ursprünglichen Fantasiekarrieren wurden mit dem jeweiligen Originalcode Prüfsummen-Saves mit aktiven Gästen erzeugt. Der 0.35-Kandidat hat für beide Ursprungsfassungen **48 von 48** Prüfungen bestanden: Geld, Kalender, Missionen, Forschung, Baugeometrie und aktive Gäste erhalten, Hintergrundladen erfolgreich und die Originaldatei beim Laden unverändert. Diese Prüfung benötigt weder erfundene Legacy-Fixtures noch ein neues Spiel.

## Lokale Abschlussrunde

**27 Testreihen, 3904 bestandene Assertions, 0 fehlgeschlagene Assertions.** Der vollständige maschinenlesbare Nachweis steht in `035-local-results.json`. Die letzte gerenderte Portrait-HUD-Reihe hat 58 Prüfungen, die Arcade-Touch-Reihe 80, das Radio 64 und die neue Planungs-/Spiel-/Kredit-UI 28 Prüfungen bestanden. Übersetzungskatalog: 2.745 vollständig abgedeckte Texte mit geprüften Platzhaltern. Workflow-YAML, beide Android-Versionskennungen und Patch-Anwendbarkeit auf die unveränderte 0.34.1-Basis wurden geprüft.
