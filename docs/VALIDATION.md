# Prüfung von SkiZones 0.12.0

Stand: 29.10.2026 · Godot 4.5.2 (`6ce3de25a`).

Der aktuelle Prüfumfang beträgt **748 Modell- und Grafikprüfungen**, dazu 31 Activity-/Darstellungsfälle in Android-11- und Android-16-Emulatoren. Veröffentlichung erfolgt erst nach erfolgreichen Modell-, Grafik- und Android-Läufen. Ein physisches Smartphone wurde nicht geprüft.

Der [Veröffentlichungslauf für 0.12.0](https://github.com/chekento/SkiZones/actions/runs/40913453185) prüft den APK-Quellcode-Commit `e17ce99d5538a1d1100ccb3a251c21a5826ae1dd`. Alle **748 Modell-/Grafikprüfungen und 31 Android-Fälle** sind im ersten Veröffentlichungslauf erfolgreich abgeschlossen. Darunter sind vier echte Android-Bildschirm-Taps je Plattform, die Display-Skalierung und Griffe bei allen vier Kameraperspektiven prüfen.

Vorheriger freigegebener Stand: der [Veröffentlichungslauf für 0.11.0](https://github.com/chekento/SkiZones/actions/runs/40873205388) prüft den APK-Quellcode-Commit `500190986df4a021bfbf10ed4136fe675ba42677`. Alle **697 Modell-/Grafikprüfungen und 23 Android-Fälle** sind erfolgreich abgeschlossen (Versuch 2). Unter Android 11 wurde nach acht erfolgreichen App-Wechseln der erste Lauf durch einen Emulator-/ADB-Timeout beim Bildschirmwechsel beendet. Der unveränderte Export bestand den vollständigen Wiederholungslauf; Android 16 bestand bereits im ersten Veröffentlichungslauf alle zwölf Fälle.

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 55 automatisierte Prüfungen |
| Karriere und Langzeitbetrieb | 48 automatisierte Prüfungen; Forschung, Aufträge, Ausbau, Migration und zwei vollständige Winter |
| Szene, UI, Touch und Liftanimation | 54 automatisierte Prüfungen mit aktiver Compatibility-Grafikausgabe |
| Schnee und Gebiete | 37 Prüfungen für persönliche Fahrten, Spuren, lokale Verformung, Präparierung, Karten und Bergpass |
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
| Planung und Bedürfnisse | 40 neue Prüfungen: sanftere tatsächliche Route, erhaltene Wegpunkte, reale Anschlussprüfung, wirkliche Restaurantbesuche und Gebühren, gezielte Erholung, wiederholte Einkehr, Kapazität, geschlossene und abgetrennte Angebote, Format-11-Rundlauf und tatsächliche 0.10-Migration |
| Deutsch und Englisch | 19 Prüfungen der echten Oberfläche: Systemauswahl, alle Menüs, Hilfe, Gebiete, aktive Forschung, Gastprofile, Bericht, Sprachwechsel mit unverändertem Resort und Bauplan, 3D-Beschriftungen, eigene Namen und kleine Displays; zusätzlicher Katalogtest für 636 Einträge und Formatplatzhalter |
| Breite, Korridore und Gelände | 25 neue Modellprüfungen: 14–36 m Bauauswahl, 44 m nach Ausbau, wirkliche Preise und gespeicherte Breite, seitliche Einschnitte/Auffüllungen bis 1,2 m, geschützte Mittellinien und Anschlüsse, volle Gebäudekorridore, Beschneiung, sichere Kurven, beschädigte Daten und tatsächliche 0.11-Migration |
| Tatsächliche Oberflächen-Klicks | 26 neue Prüfungen mit Grafikausgabe: vier Kameramodi × fünf Drehwinkel × drei Zoomstufen, reale Dreiecke und verformter Schnee, Pixelgrenze fürs Andocken, Griffe mit Abstand, Bau-/Umbau-Breitensteuerung einschließlich Ausbau, echte Möbelgeometrie, örtliche Verfeinerung und Sprachwechsel |
| Android-App-Wechsel und Display-Taps | 15 Fälle unter Android 11 (API 30) und 16 unter Android 16 (API 36): Start, acht Home-/Rückkehrzyklen, Bildschirm aus/an und Prozessneustart; zusätzlich System-Overlay unter Android 16. Je vier echte Android-Bildschirm-Taps prüfen die Koordinatenumrechnung und Wegpunktgriffe bei allen Kameraperspektiven. Beide Jobs müssen vor der Veröffentlichung erfolgreich sein. |
| CPU-Belastung | Aktueller 0.12-Prüflauf mit 80 Gästen/1 Lift und 360 Gästen/24 Liften bei 1× und 4×; zusätzlich historischer Vergleich mit unverändertem 0.6-Quellcode. Methode, Rohdaten und Grenzen in [PERFORMANCE.md](PERFORMANCE.md) |
| Langzeitlauf | 56 vollständige Betriebstage mit echten Gästen, Abfahrten, erledigten Aufträgen und allen neun Forschungen |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Stationsplatz mit Warteschlange, Tellerlift, Vierer-/Achtersessel und Gondeln mit tatsächlichen Mitfahrenden sowie blaue Route mit roten/schwarzen Abkürzungen, verschiebbare Planungspunkte, Höhenprofil, Kameramenü, Höhenlinien/Gefällepfeile und runde nummerierte Schilder im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Die insgesamt 748 Prüfungen bestätigen die getesteten Abläufe; sie ersetzen keine abschließende Wirtschafts- oder Geräteprüfung. Der Langzeitlauf plant Forschung, Erweiterungen und Aufträge über reguläre Simulationsaktionen. Er prüft auch Speicherfortsetzungen in beiden Wintern und die rollierende Finanzhistorie.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.12.0/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.

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
