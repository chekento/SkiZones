# Prüfung von SkiZones 0.17.0

Die vollständige Veröffentlichung wird derzeit geprüft. Der öffentliche Download bleibt bis zum erfolgreichen Abschluss bei 0.16.0.

Neue Modellprüfungen: vier Karrieren und Migration (29), GitHub-Angebote und Manifestvalidierung und Wiederaufnahme (27), längere Tage und Nachtbesuche (17), einzelne Familienmitglieder mit Betreuung, Treffen und Heimkehr (24), Kartenzugänge und automatische Liftwege und Umbauten (54). Neue gerenderte Prüfungen: Karriereauswahl (16), Personenprofile und Updatebedienung (11).

Alle zwölf Zugänge wurden zusätzlich auf begehbares Gefälle und freie Wege um Gebäude und Lifttechnik geprüft. Die geänderte Android-Java-Erweiterung wurde bereits im CI-Build erfolgreich kompiliert. Der vollständige Android-Installer-Wechsel und der Abschlusslauf stehen noch aus.

Godot 4.5.2 · Android-Versionscode 22 · Spielstandformat 15. Der öffentliche ARM64-Export enthält keinen Emulator-Testtreiber. Ein physisches Smartphone wurde nicht geprüft.

# Vorheriger Veröffentlichungsstand 0.16.0


**Modell und Grafik: 1.165 Prüfungen in 36 Suiten bestanden. Android: 43 Activity-/Oberflächenfälle bestanden — 21 unter Android 11 (API 30), 22 unter Android 16 (API 36).** Signaturprüfung, APK-Archivprüfung und Veröffentlichung sind abgeschlossen.

Geprüfter APK-Quellcode: `162e4ade91e653db6bd55f44f91421a5bd2e5015`.
[Veröffentlichungslauf](https://github.com/chekento/SkiZones/actions/runs/41106447886) mit Godot 4.5.2, Android-Versionscode 21 und Spielstandformat 14.

Die neuen Gästetests bestehen 72 Fälle: Komfortgrenzen auf allen Routenabschnitten, echte Snowpark-Besuche, Sammler mit vollständiger Pistenabdeckung und unbenutzten Liften, einzelne Familienmitglieder, reale Sitzbelegung, Wiedervereinigung am Berg, Versorgungswege, Platzbedarf, tatsächliche Besuchserlöse, Rückmeldungen, Werbekosten und Übernachtung. Der Speichervergleich mit einem veröffentlichten 0.11-Spielstand sowie die Fortsetzung einer teilweise eingestiegenen Familie sind erfolgreich.

Die neue Grafiksuite besteht 18 Fälle für einzeln sichtbare Familienmitglieder, getrennte Reihen, antippbare Kinder, persönliche Wünsche, die deutsche/englische Übersicht, Kartensperre, Preise und kleine Querformat-Bildschirme. Die bisherige Karten-/Personalprüfung besteht weiterhin 53 Fälle, einschließlich der vier realen Szenarien, voller Renderfläche und passender Planungspunkte. Der Sprachkatalog umfasst 969 geprüfte Einträge.

Die Android-Prüfungen verwenden echte Emulator-Activities und Oberflächenbilder. Die Grafikanpassung bleibt bei 100 % Rendergröße. Ein physisches Smartphone wurde nicht geprüft.

Veröffentlicht: [APK und Prüfsumme](https://github.com/chekento/SkiZones/releases/tag/v0.16.0), ARM64, 33.378.475 Bytes. SHA-256: `9027981b20ee016c84bfb0feb75471a36bf1e3e400b821d0809a0a7d0467a5c7`.

## Veröffentlichter Nachweis für 0.15.0


**Modell und Grafik: 1.075 Prüfungen in 34 Suiten bestanden.** Die ARM64-APK hat Signatur- und Archivprüfung bestanden. **Android: 43 Activity-/Oberflächenfälle bestanden — 21 unter Android 11 (API 30), 22 unter Android 16 (API 36).** Beide Jobs und die Veröffentlichung sind erfolgreich abgeschlossen.

Geprüfter APK-Quellcode: `86e97baf0284e9001988ed57de4b90a180e15d17`.
[Veröffentlichungslauf](https://github.com/chekento/SkiZones/actions/runs/41095498344) mit Godot 4.5.2, Android-Versionscode 19 und Spielstandformat 14.

Die zusätzlichen Grafikprüfungen kontrollieren volle Rendergröße bei jeder
Grafikstufe und bei automatischer Überlastanpassung, asymmetrische sichere
Handyränder, Punktziehen ohne Kameraverschiebung und die Hauptspiel-Reihenfolge.
Alle vier realen Szenarien werden als vollständige 3D-Szene aufgebaut. Pro Gebiet
werden Schneeflächen gegen die tatsächlich gerenderten Bodendreiecke sowie die
sichtbare Abdeckung der Pistenmittellinien geprüft. Die Prüfung umfasst auch
direkte Einstellknöpfe, Kosten, doppelte Einstellungen, Schichtwechsel,
Reservezuweisung, gemeinsame Mittelstationen und englische Stationsanzeigen.

Lokal sind die Modellprüfungen für Pistenverbindungen (19), Schneeflächen (25),
reale Betriebsabläufe (103), Nachtbetrieb und Rettung (30) sowie Bauplätze und
Wege (24) erfolgreich. Die vorhandene Punkteditor-Grafikprüfung besteht 15 Fälle.
Die Skifahrer-Kontaktprüfung verwendet jetzt zusätzlich einen unabhängigen
Strahlschnitt mit dem sichtbaren Bodendreieck; die zugehörige Grafiksuite
besteht 31 Fälle. Der Sprachkatalog enthält 925 Einträge mit unveränderten
Platzhaltern und vollständiger Quelltextabdeckung.

Die Android-Tests prüfen die vier Kameraperspektiven zusammen mit den vier
Grafikstufen. Bei Automatik wird zusätzlich Überlastung simuliert. Jeder echte
Emulator-Bildnachweis verlangt eine Rendergröße von 100 %. Versionscode 19 wurde nach den erfolgreichen vollständigen CI- und Android-Läufen veröffentlicht.
Ein physisches Smartphone wurde nicht geprüft.

Die neue Szenariografiksuite besteht 53 Fälle. Dabei wurden 20.818 Schneeflächendreiecke sowie Punkte auf den Pistenmittellinien kontrolliert: keine geprüfte Fläche lag unter dem sichtbaren Boden, keine geprüfte Mittellinie hatte eine Schneelücke.

Neue Regression: `tests/display_staff_scene.gd`. Die zugehörigen tatsächlichen
Spielbilder werden unter `build/qa/` erzeugt. Die bestehende Prüfung für
Punktgriffe und letzte Touch-Positionen bleibt aktiv.

# Vorheriger Veröffentlichungsstand 0.14.3

**Modell und Grafik: 1.021 Prüfungen in 33 Suiten bestanden.** Die signierte ARM64-APK hat Signatur- und Archivprüfung bestanden.

**Android: 43 echte Activity-/Oberflächenfälle bestanden — 21 unter Android 11 (API 30), 22 unter Android 16 (API 36).** Beide Jobs und die Veröffentlichung sind erfolgreich abgeschlossen.

Geprüfter APK-Quellcode: `75f57a7562e46ea81910a66b9343ccaf4e7880a2`.
[Veröffentlichungslauf](https://github.com/chekento/SkiZones/actions/runs/41056304323)
mit Godot 4.5.2, Android-Versionscode 18 und Spielstandformat 14.

| Bereich | Nachweis |
|---|---|
| Pistenverbindungen | 19 Fälle: Projektion auf Segmentmitten, Vorschau ohne Nebenwirkungen, wirkliche Gästerunden über Abzweige, gemeinsame Punktverschiebung, besetzter JSON-Spielstand, Stationskollision ohne automatisches Versetzen und atomare Ablehnung bei ausgeschöpfter Punktzahl |
| Gemeinsame Schneeflächen | Flächeninhalt entspricht der Vereinigung dreier kreuzender Korridore; gemeinsame Höhen trotz unterschiedlicher Breiten und Schneehistorien; identische GPU-/CPU-Gewichte; gemischte importierte und selbst gebaute Raster auf gekrümmtem Gelände |
| Sichtbare Punktbearbeitung | 15 Grafikfälle: asymmetrischer Handy-Bildschirmrand, echte Pixelprüfung der Griffposition, alle vier Kameramodi, dichte Punktfolgen, Einzelpunktauswahl, Ziehen und Abbrechen, direkter Bestandseditor, letzte Loslasskoordinate für Touch und Maus sowie geschlossene Bauvorschau über dem Schnee |
| Bestehende Bau- und Betriebslogik | Gesamter bisheriger Modell- und Grafiklauf einschließlich 24 Bauplatz-/Wegefällen, 103 realen Geografie-/Betriebsfällen und 30 Maschinen-/Rettungs-/Nachtfällen |
| Übersetzungen | 876 Katalogeinträge mit Platzhaltern und vollständiger Quelltextabdeckung |
| Android | Tatsächliche Activity, Oberflächenwiederaufnahme, vier Bildschirm-Taps und vier Wischgesten pro API; zusätzlich sichtbare Griffpixel, besetztes Wurmberg aus den APK-Ressourcen und Wiederherstellung nach Prozessneustart |
| Veröffentlichung | ARM64-APK mit Signatur- und Archivprüfung, SHA-256-Datei und Quellcode-Manifest |

Die Android-Prüfung verlangt außerdem einen Laufzeitnachweis für die korrigierte Weitergabe der letzten Berührungsposition. Die bisherige Zielgenauigkeit wird beibehalten.

Die zusätzlichen Android-Prüfungen verwenden absichtlich asymmetrische sichere
Bildschirmränder im separaten x86-64-Testexport. Der öffentliche ARM64-Download
enthält den Testtreiber nicht. Ein physisches Smartphone wurde nicht gemessen.
Die Prüfung ist kein Nachweis einer bestimmten Bildrate auf allen Geräten.

Zusätzlich wurde Kitzbühel mit 88 Lift- und 448 Pistenabschnitten als vollständige
3D-Szene auf dem lokalen llvmpipe-Renderer aufgebaut und visuell kontrolliert.
Dieser einzelne Sichttest misst keine Android-Spielgeschwindigkeit. Große reale
Gebiete benötigen beim ersten Öffnen merklich mehr Vorbereitungszeit als die
kleinen Originalresorts.

Reproduzierbare neue Prüfpunkte: `tests/piste_connections.gd`,
`tests/piste_editor_scene.gd`, `tests/android_lifecycle_driver.gd` und
`tools/android_resume_smoke.py`. Alle bisherigen Suiten bleiben im Workflow.

# Vorheriger Stand 0.14.0 / 0.14.1

Die neue Fassung ergänzt 103 Modellprüfungen für reale Geografie, alle vier
Szenarien, Rundwege jeder Könnensstufe, gemeinsame Mittelstationen, Personal,
Reparaturen, Mitternacht, Speichern und identische feste Simulationsschritte.
30 weitere Fälle prüfen tatsächliche Pistenraupenarbeit, Stillstand und
Wartung, Rettung, Hotelgäste über Mitternacht, Ersatzteile und Talfahrten.
Die Grafikprüfung öffnet Szenarien, Betrieb, Einstellungen und Quellen durch
den echten Controller und prüft sichtbare Schwimmer sowie den Abendhinweis.
Die bisherigen 816 Modell- und Grafikfälle bleiben Bestandteil des Workflows.

Der Android-Testexport prüft zusätzlich das Öffnen von Wurmberg aus den
gebündelten Kartendaten und die Wiederherstellung dieses besetzten Resorts
nach einem Prozessneustart. Die öffentliche ARM64-APK enthält diesen
Testtreiber nicht. Veröffentlichung erfolgt erst nach erfolgreich beendeten
Modell-, Grafik-, Export- und Android-30-/Android-36-Prüfungen.

Die neuen Prüfungen sind in `tests/real_operations.gd`,
`tests/operating_nights.gd`, `tests/operating_scene.gd` und
`tools/android_resume_smoke.py` nachvollziehbar. Ein physisches Smartphone
wurde nicht geprüft; die großen Geodaten-Gebiete benötigen je nach Hardware
Vorbereitungszeit und zeigen dafür eine Ladeansicht.

## Vorheriger Veröffentlichungsstand 0.13.0

Stand: 29.10.2026 · Godot 4.5.2 (`6ce3de25a`).

Der aktuelle Prüfumfang beträgt **816 Modell- und Grafikprüfungen**, dazu 31 Activity-/Darstellungsfälle in Android-11- und Android-16-Emulatoren. Veröffentlichung erfolgt erst nach erfolgreichen Modell-, Grafik- und Android-Läufen. Ein physisches Smartphone wurde nicht geprüft.

Der [Veröffentlichungslauf für 0.13.0](https://github.com/chekento/SkiZones/actions/runs/40932845746) prüft den APK-Quellcode-Commit `5800b9295cdf4ef6102c09aa34ef5cf82d833fcb`. Alle **816 Modell-/Grafikprüfungen und 31 Android-Fälle** sind erfolgreich abgeschlossen. Darunter sind 50 zusätzliche Modellfälle und 14 neue Grafikfälle für die acht Startpakete, die wirkliche Dorfpromenade und ihre Eingangssteuerung. Die Kartensuite prüft vier zusätzliche Regionen. Je vier echte Android-Bildschirm-Taps prüfen weiterhin Display-Skalierung und Griffe bei allen vier Kameraperspektiven.

Vorheriger Stand: [0.12.0](https://github.com/chekento/SkiZones/actions/runs/40913453185), APK-Quellcode `e17ce99d5538a1d1100ccb3a251c21a5826ae1dd`: 748 Modell-/Grafikprüfungen und 31 Android-Fälle.

Vorheriger freigegebener Stand: der [Veröffentlichungslauf für 0.11.0](https://github.com/chekento/SkiZones/actions/runs/40873205388) prüft den APK-Quellcode-Commit `500190986df4a021bfbf10ed4136fe675ba42677`. Alle **697 Modell-/Grafikprüfungen und 23 Android-Fälle** sind erfolgreich abgeschlossen (Versuch 2). Unter Android 11 wurde nach acht erfolgreichen App-Wechseln der erste Lauf durch einen Emulator-/ADB-Timeout beim Bildschirmwechsel beendet. Der unveränderte Export bestand den vollständigen Wiederholungslauf; Android 16 bestand bereits im ersten Veröffentlichungslauf alle zwölf Fälle.

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 55 automatisierte Prüfungen |
| Karriere und Langzeitbetrieb | 48 automatisierte Prüfungen; Forschung, Aufträge, Ausbau, Migration und zwei vollständige Winter |
| Szene, UI, Touch und Liftanimation | 54 automatisierte Prüfungen mit aktiver Compatibility-Grafikausgabe |
| Schnee und Gebiete | 41 Prüfungen für persönliche Fahrten, Spuren, lokale Verformung, Präparierung, Karten und Bergpass |
| Automatische Pistenplanung | 20 Prüfungen für direkte und querende Routen, steilste Abschnitte, Nummerierung, Migration und beschädigte Daten |
| Verzweigungen und Teilstrecken | 30 Prüfungen; Können, Andocken, zusammenhängende Abschnitte, lokale Teilspuren, Speicherfortsetzung auf dem echten Sonnenhang und ein Netz mit 2.304 Wegpunkten |
| Kamera, Gelände und Punktbearbeitung | 21 Prüfungen mit tatsächlicher Grafikausgabe; Touch-/Maus-Drag, Abbruch, Löschen, vier Perspektiven, Geländepicking, Höhenlinien, Richtung der gerenderten Pfeile und sichtbare Bauaktionen |
| Liftflotte und Fußwegenetz | 52 Prüfungen; acht Liftarten, Längengrenzen, feste Plätze, Anstellreihenfolge, 360 Wartende, Halt, Gebäudeanschlüsse, Umsteigen, Besuche, Speicherdaten und Migration |
| Gerenderte Fahrzeuge und Stationsplätze | 38 Prüfungen mit tatsächlicher Grafikausgabe; exakte Fahrzeug-/Sitztransformationen auch zwischen Simulationsschritten, maximale Belegung, Teller-Zugseile, Sesselbreiten, Kabinengäste, Platzgeometrie und Schneeübergänge |
| Baukomfort, Kurven und Wochenbilanz | 25 Prüfungen; geschlossene Schneeflächen in drei Kehrenformen, eindeutige Dreiecksrichtung, sichere Fußwege, 360 Wartende, baubare Gehflächen, beschädigte Speicherwerte, tatsächliche 0.5-Migration und sieben vollständige Betriebstage |
| Tatsächliche Baueingaben | 16 Prüfungen mit Grafikausgabe; gesperrter Werkzeugwechsel, wiederholte konkurrierende Klicks, Android-Zurück, Pausenfortsetzung, doppelte Bestätigung, Zwei-Finger-Verschieben und tatsächliche Finger-/Stift-Mauseingaben auf Baukarten |
| Tatsächliche Gebietswechsel | 8 Prüfungen mit getrennten Dateien in isolierter Laufzeitumgebung |
| Gestaltung und Gäste | 34 Prüfungen für transaktionale Umbauten, Kosten, sichere gedrehte Eingänge, gemeinsame Pistenpunkte, Breite und Unterhalt, persönliche Bedürfnisse, Präferenzen sowie tatsächliche 0.6-Migration |
| Gerenderte Gestaltung und Performancegrenzen | 30 Prüfungen mit aktiver Grafikausgabe: vorhandene Gebäude ziehen, abbrechen und einmalig bestätigen; tatsächliche Drehung, passende Dialoggröße, GPU-Schnee, Höhengenauigkeit, feste Spur-Arbeitsgrenze, Cache-Wiederverwendung, Waldmodelle, exakte Liftbelegung, Sichtbarkeitswechsel, persönliche Profile und stetige Bewegung |
| Chronologischer Tagesabschluss und Routenwahl | 54 Prüfungen: laufende Abfahrt und besetzter Zweiersessel über 18 Uhr, physischer Rückweg, genau einmal verbuchte Kosten, Sturm und Wiederanlauf, individuelle Routen ab dem Pistenende, korrekt skalierte Warteschlangen, alternative Liftzufahrt bei Überlastung, Verlassen geschlossener Schlangen, Rückholung aus einem durch manuelle Liftsperre getrennten Seitental mit Speicherfortsetzung und Sturmhalt, Fahrtbeschleunigung und Kurvenbremsen sowie tatsächliche 0.7-Migration |
| Scrollbarer Tagesbericht | 15 Szenenprüfungen: In-Scene-Dialog mit allen Finanzfeldern, angepasste Größe und dauerhaft sichtbare nächste-Tages-Schaltfläche bei 1536×710, 1280×800 und 960×540, echte Finger-Ereignisse und fortlaufender Feierabendbetrieb |
| Wege, Schwung und Stapfen | 41 Prüfungen für Energieverlust, Fahrt mit und ohne Anlauf, Gehzeiten am Hang, direkte Liftzugänge, Fußwegbau und Bearbeitung, Schließung, Kosten, tatsächliches Stapfen auf dem Sonnenhang, persönliche Fahrprofile und 0.8-Migration |
| Gerenderte Wege und Gegenanstiege | 18 Prüfungen mit echter Grafikausgabe: Baukatalog, Mehrpunktplanung, Punktziehen, Abbruch, genau einmal bestätigter Bau, Auswahl entlang des Weges, Bestandsbearbeitung, tatsächlicher Stapfgast mit passendem Modell und Profil sowie übereinstimmende Schneeintervalle |
| Drei Wintersportarten | 16 Prüfungen: echter gemischter Gästebetrieb, Ausrüstung, persönliche Bewegung, gespeicherte Spuren, deterministische Fortsetzung, beschädigte Daten, kanonische Gastkennungen und tatsächliche 0.9-Migration |
| Drehgeste und Wiederaufnahme | 22 Prüfungen mit Grafikausgabe: kombinierte Gesten, Geländeanker, drei Ausrüstungen und Spuren, Liftplätze, Rückkehr nach deaktivierter Darstellung, sichtbares Bild, Hintergrundzeit, exakte Kamera und Resortfortsetzung nach Prozessneustart sowie beschädigter Sitzungspunkt |
| Kleine Winterwelt | 4 Prüfungen der geschlossenen, korrekt sichtbaren Modellgeometrie, einfachen Fernbäume, persönlichen Stofffarben und festen Instanzgrenzen; echte Resort-, Dorf- und Menüaufnahmen |
| Planung und Bedürfnisse | 40 neue Prüfungen: sanftere tatsächliche Route, erhaltene Wegpunkte, reale Anschlussprüfung, wirkliche Restaurantbesuche und Gebühren, gezielte Erholung, wiederholte Einkehr, Kapazität, geschlossene und abgetrennte Angebote, Format-13-Rundlauf und tatsächliche 0.10-Migration |
| Deutsch und Englisch | 19 Prüfungen der echten Oberfläche: Systemauswahl, alle Menüs, Hilfe, Gebiete, aktive Forschung, Gastprofile, Bericht, Sprachwechsel mit unverändertem Resort und Bauplan, 3D-Beschriftungen, eigene Namen und kleine Displays; zusätzlicher Katalogtest für 675 Einträge und Formatplatzhalter |
| Breite, Korridore und Gelände | 25 neue Modellprüfungen: 14–36 m Bauauswahl, 44 m nach Ausbau, wirkliche Preise und gespeicherte Breite, seitliche Einschnitte/Auffüllungen bis 1,2 m, geschützte Mittellinien und Anschlüsse, volle Gebäudekorridore, Beschneiung, sichere Kurven, beschädigte Daten und tatsächliche 0.11-Migration |
| Tatsächliche Oberflächen-Klicks | 26 neue Prüfungen mit Grafikausgabe: vier Kameramodi × fünf Drehwinkel × drei Zoomstufen, reale Dreiecke und verformter Schnee, Pixelgrenze fürs Andocken, Griffe mit Abstand, Bau-/Umbau-Breitensteuerung einschließlich Ausbau, echte Möbelgeometrie, örtliche Verfeinerung und Sprachwechsel |
| Acht Resortwelten | 50 neue Modellprüfungen: unterschiedliche Landschaften und Startlifte, kompletter Anfänger-Rundweg in jedem Gebiet, finanzierte Starts, Promenadenknoten, Stichwege, Zweige mitten am Weg, Eingangsrichtung, Ausrüstungsreibung, Rauigkeit, Abstand und deterministische Speicherfortsetzung sowie tatsächliche 0.12-Migration |
| Gerenderte Resortwelten | 14 neue Fälle mit echten Bildern: acht vollständige Kartenwechsel, gültige Eingangsrichtung, tatsächlicher Drehknopf und bestätigte Orientierung, begrenzte Dorfdekoration, alle Möbelvertices außerhalb der Pisten und englischer Acht-Resort-Bergpass |
| Android-App-Wechsel und Display-Taps | 15 Fälle unter Android 11 (API 30) und 16 unter Android 16 (API 36): Start, acht Home-/Rückkehrzyklen, Bildschirm aus/an und Prozessneustart; zusätzlich System-Overlay unter Android 16. Je vier echte Android-Bildschirm-Taps prüfen die Koordinatenumrechnung und Wegpunktgriffe bei allen Kameraperspektiven. Beide Jobs müssen vor der Veröffentlichung erfolgreich sein. |
| CPU-Belastung | Aktueller 0.13-Prüflauf mit 80 Gästen/1 Lift und 360 Gästen/24 Liften bei 1× und 4×; zusätzlich historischer Vergleich mit unverändertem 0.6-Quellcode. Methode, Rohdaten und Grenzen in [PERFORMANCE.md](PERFORMANCE.md) |
| Langzeitlauf | 56 vollständige Betriebstage mit echten Gästen, Abfahrten, erledigten Aufträgen und allen neun Forschungen |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Stationsplatz mit Warteschlange, Tellerlift, Vierer-/Achtersessel und Gondeln mit tatsächlichen Mitfahrenden sowie blaue Route mit roten/schwarzen Abkürzungen, verschiebbare Planungspunkte, Höhenprofil, Kameramenü, Höhenlinien/Gefällepfeile und runde nummerierte Schilder im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Die insgesamt 816 Prüfungen bestätigen die getesteten Abläufe; sie ersetzen keine abschließende Wirtschafts- oder Geräteprüfung. Der Langzeitlauf plant Forschung, Erweiterungen und Aufträge über reguläre Simulationsaktionen. Er prüft auch Speicherfortsetzungen in beiden Wintern und die rollierende Finanzhistorie.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.13.0/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.

Die Szenentests brauchen eine echte Grafikausgabe; unter Linux kann `xvfb-run -a godot --audio-driver Dummy --script tests/scene.gd` verwendet werden. Ein Dummy-Renderer speichert keine auslesbaren MultiMesh-Transformationen und ersetzt diese Prüfung nicht. Der Test misst am tatsächlichen Liftfahrzeug wenige Meter Weg pro Normaltempo-Sekunde und Stillstand bei pausierter Uhr.

Für den Test echter Gebietswechsel muss eine isolierte Laufzeit gewählt werden: `XDG_DATA_HOME=/tmp/skizones-test-regions godot --headless --script tests/regions.gd`. Er verweigert die Arbeit ohne passenden Testpfad und entfernt ausschließlich seine isolierten Spielstände.

Die Abschnittsprüfung verwendet einen steilen Testhang mit identischem Start und Ziel für direkte und querende Verläufe. Ergänzend wird eine ungefähr 945 m lange blaue Route auf dem tatsächlichen Sonnenhang mit roten und schwarzen Abkürzungen gebaut. Ein Gast auf der blauen Ausfahrt wird gespeichert und an derselben Position fortgesetzt. Ein größerer Test erzeugt 36 Pisten mit je 64 Wegpunkten und validiert alle vollständigen Routen.

Auch `tests/planning_scene.gd` benötigt eine echte Grafikausgabe. Die zusätzlichen Modelltests laufen mit `godot --headless --script tests/piste_planning.gd` und `godot --headless --script tests/junctions.gd`.

Die neuen Modelltests laufen mit `godot --headless --script tests/lifts_and_plazas.gd`. `tests/lift_scene.gd` benötigt wie die anderen Szenentests aktive Grafikausgabe. Gespeicherte Testresorts aus der tatsächlichen 0.4.0-Version unter `tests/fixtures/` enthalten laufende Gäste; ihre Migration wird mit erhaltenem Geld, Forschung, Besucherzahlen und anschließendem Speichern im Format 6 geprüft. Es handelt sich um erzeugte Testdaten.

`tests/build_comfort.gd` läuft ohne Grafikausgabe; `tests/build_input_scene.gd` verwendet den Compatibility-Renderer und Godots Eingabeverarbeitung. Der zusätzliche Wochenlauf prüft tatsächliche Abfahrten, begrenzte Warteschlangen und gedeckte Betriebskosten eines unveränderten Starterresorts. Diese Stichprobe ersetzt keine umfassende Abstimmung aller Ausbauvarianten.

Die Finger- und Stiftpfade wurden mit erzeugten Godot-Eingabeereignissen am Desktop geprüft. Ein Test mit einem physischen Android-Gerät und dessen Stift steht für Version 0.7 noch aus.


Die neuen Prüfungen laufen mit `godot --headless --script tests/customization.gd` und mit aktiver Grafikausgabe `godot --script tests/customization_scene.gd`. Einstellungsprüfungen verwenden eigene temporäre Konfigurationsdateien. Der Höhentexturtest vergleicht alle lokalen Werte mit einer maximalen Abweichung von 2 mm. Spurtests prüfen die feste Grenze von höchstens 48 neu berechneten Fahrpunkten pro automatischem Durchlauf und Wiederverwendung unveränderter Daten. Der Belastungstest ersetzt weder vollständige GPU-Messungen noch ein Profiling auf einem physischen Smartphone.

Version 0.8 beendet den Betriebstag erst nach dem letzten tatsächlichen Rückweg. Die 56-Tage- und Wochenläufe warten auf `day_finished()`, statt Gäste bei einer festen Uhrzeit zu löschen. Kapazitäts-Stresstests setzen ihre Gäste vor der Schlange ein; die reguläre Einlassentscheidung lehnt planbar zu lange Aufenthalte ab. Das tatsächliche 0.7-Testresort wird bei 17:59 geladen, über 18 Uhr weitergeführt und im Format 8 erneut gespeichert.

Version 0.9 übernimmt die pauschale 1,5-m-Grenze nicht. Das vereinfachte Energiemodell arbeitet mit Energie pro Kilogramm; Masse kürzt sich. Es berücksichtigt Gleitreibung und einen geschwindigkeitsabhängigen Widerstand. Gehbare Abschnitte ohne ausreichenden Schwung erhalten eine zusammenhängende Gehphase bis zum Gefällewechsel. Das ist keine vollständige biomechanische Ski- oder Kollisionssimulation.

Alte Fußkorridore werden für aktive 0.8-Gäste bis zum folgenden Tageswechsel erhalten. Neue Resorts beginnen unmittelbar mit dem übersichtlicheren Netz. Das reale 0.8-Testresort wurde mit dem veröffentlichten Quellcode erzeugt; es enthält synthetische Gäste.

Der Rückholtest erzeugt auf dem tatsächlichen Sonnenhang ein Seitental, dessen Rückweg einen zweiten Lift benötigt. Ohne Korrektur bleibt dessen geschlossene Schlange auch nach dem Zeitlimit bestehen. Die korrigierte Simulation bedient ausschließlich Heimwege, behält die manuelle Sperre und die tatsächliche Position bei und beendet nach der letzten Rückkehr den Tag. Bei Sturm steht auch dieser Lift still. Neue reguläre Routen verwenden die gesperrte Anlage nicht.

Die Aufnahmen von [Fußwegplanung](screenshots/footpath-preview-090.webp), [Stapfgast](screenshots/hiking-090.webp) und [Tagesbericht](screenshots/day-report-090.webp) wurden aus dem erfolgreichen 0.9-Grafikprüflauf übernommen und visuell kontrolliert. Sie zeigen erzeugte Testsituationen mit der tatsächlichen Spieloberfläche.

Die Android-Lifecycle-Prüfung verwendet einen gesonderten x86-64-Testexport mit aktiviertem Testtreiber. Die öffentliche ARM64-APK enthält diesen Treiber und die Testdaten nicht. Kamera, Betrieb und Darstellung stammen in beiden Exporten aus denselben Spielskripten. Ein Emulator bestätigt weder die Fehlerfreiheit jedes Geräte-Grafiktreibers noch die Bildrate auf einem physischen Smartphone.

Der Grafikumbau wird mit `tests/cute_scene.gd` zusätzlich durch echte Compatibility-Ausgabe erfasst. Nahdetails werden in vorhandene Asset-Meshes gebacken; das Gäste-Material trennt die Jackenfarbe von Gesicht, Brille und Schal. Die Aufnahmen zeigen reguläre 3D-Spielgeometrie, keine Konzeptbilder.

Die native Android-Prüfung umfasst acht Home-Wechsel und vier echte Bildschirm-Taps (15 sichtbare Fälle unter Android 11 und 16 unter Android 16 einschließlich eines tatsächlichen System-Overlay-Wechsels). Sie prüft zusätzlich die Ausführung des Java-Surface-Patches im Log, fortschreitende Bilder und Spielzeit sowie die unveränderte Prozessidentität bei normalen App-Wechseln. Der Prozessneustart wird separat absichtlich ausgelöst.

Die neuen Prüfungen laufen mit `tests/piste_surfaces.gd` und `tests/piste_surfaces_scene.gd`. Die grafische Prüfung projiziert tatsächliche Gelände- und Schneegitter und setzt reale Mausereignisse; der Android-Lauf erzeugt zusätzlich native Bildschirm-Taps per ADB. Die Modellmigration nutzt einen unveränderten 0.11-Quellcode-Spielstand mit zwölf synthetischen Gästen. Die Geländeangleichung ist seitlich begrenzt und ändert nicht das Höhenprofil der Mittellinie.

Version 0.13 trennt die neue Gelände-Generation von vorhandenen Resorts. Echte Spielstände bis 0.12 behalten ihre Höhenfunktion und beginnen nicht plötzlich in einem anderen Tal. Die vier bisherigen Gebietskennungen und die zugehörigen Freischaltungen bleiben gültig. Die zusätzliche Fortsetzungsprüfung toleriert ausschließlich numerische JSON-Rundungsabweichungen unter 1e-7; Identitäten, Routen, Geld, Zustände und Verlauf bleiben gleich.
