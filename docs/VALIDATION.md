# Prüfung von SkiZones 0.7.0

Stand: 28.10.2026 · Godot 4.5.1 (`f62fdbde1`).

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 54 automatisierte Prüfungen |
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
| CPU-Belastung | Reproduzierbarer Vergleich mit unverändertem 0.6-Quellcode: 80 Gäste/1 Lift und 360 Gäste/24 Lifte bei 1× und 4×; Methode, Rohdaten und Grenzen in [PERFORMANCE.md](PERFORMANCE.md) |
| Langzeitlauf | 56 vollständige Betriebstage mit echten Gästen, Abfahrten, erledigten Aufträgen und allen neun Forschungen |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Stationsplatz mit Warteschlange, Tellerlift, Vierer-/Achtersessel und Gondeln mit tatsächlichen Mitfahrenden sowie blaue Route mit roten/schwarzen Abkürzungen, verschiebbare Planungspunkte, Höhenprofil, Kameramenü, Höhenlinien/Gefällepfeile und runde nummerierte Schilder im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Die insgesamt 467 Prüfungen bestätigen die getesteten Abläufe; sie ersetzen keine abschließende Wirtschafts- oder Geräteprüfung. Der Langzeitlauf plant Forschung, Erweiterungen und Aufträge über reguläre Simulationsaktionen. Er prüft auch Speicherfortsetzungen in beiden Wintern und die rollierende Finanzhistorie.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.7.0/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.

Die Szenentests brauchen eine echte Grafikausgabe; unter Linux kann `xvfb-run -a godot --audio-driver Dummy --script tests/scene.gd` verwendet werden. Ein Dummy-Renderer speichert keine auslesbaren MultiMesh-Transformationen und ersetzt diese Prüfung nicht. Der Test misst am tatsächlichen Liftfahrzeug wenige Meter Weg pro Normaltempo-Sekunde und Stillstand bei pausierter Uhr.

Für den Test echter Gebietswechsel muss eine isolierte Laufzeit gewählt werden: `XDG_DATA_HOME=/tmp/skizones-test-regions godot --headless --script tests/regions.gd`. Er verweigert die Arbeit ohne passenden Testpfad und entfernt ausschließlich seine isolierten Spielstände.

Die Abschnittsprüfung verwendet einen steilen Testhang mit identischem Start und Ziel für direkte und querende Verläufe. Ergänzend wird eine ungefähr 945 m lange blaue Route auf dem tatsächlichen Sonnenhang mit roten und schwarzen Abkürzungen gebaut. Ein Gast auf der blauen Ausfahrt wird gespeichert und an derselben Position fortgesetzt. Ein größerer Test erzeugt 36 Pisten mit je 64 Wegpunkten und validiert alle vollständigen Routen.

Auch `tests/planning_scene.gd` benötigt eine echte Grafikausgabe. Die zusätzlichen Modelltests laufen mit `godot --headless --script tests/piste_planning.gd` und `godot --headless --script tests/junctions.gd`.

Die neuen Modelltests laufen mit `godot --headless --script tests/lifts_and_plazas.gd`. `tests/lift_scene.gd` benötigt wie die anderen Szenentests aktive Grafikausgabe. Gespeicherte Testresorts aus der tatsächlichen 0.4.0-Version unter `tests/fixtures/` enthalten laufende Gäste; ihre Migration wird mit erhaltenem Geld, Forschung, Besucherzahlen und anschließendem Speichern im Format 6 geprüft. Es handelt sich um erzeugte Testdaten.

`tests/build_comfort.gd` läuft ohne Grafikausgabe; `tests/build_input_scene.gd` verwendet den Compatibility-Renderer und Godots Eingabeverarbeitung. Der zusätzliche Wochenlauf prüft tatsächliche Abfahrten, begrenzte Warteschlangen und gedeckte Betriebskosten eines unveränderten Starterresorts. Diese Stichprobe ersetzt keine umfassende Abstimmung aller Ausbauvarianten.

Die Finger- und Stiftpfade wurden mit erzeugten Godot-Eingabeereignissen am Desktop geprüft. Ein Test mit einem physischen Android-Gerät und dessen Stift steht für Version 0.7 noch aus.


Die neuen Prüfungen laufen mit `godot --headless --script tests/customization.gd` und mit aktiver Grafikausgabe `godot --script tests/customization_scene.gd`. Einstellungsprüfungen verwenden eigene temporäre Konfigurationsdateien. Der Höhentexturtest vergleicht alle lokalen Werte mit einer maximalen Abweichung von 2 mm. Spurtests prüfen die feste Grenze von höchstens 48 neu berechneten Fahrpunkten pro automatischem Durchlauf und Wiederverwendung unveränderter Daten. Der Belastungstest ersetzt weder vollständige GPU-Messungen noch ein Profiling auf einem physischen Smartphone.
