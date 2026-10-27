# Prüfung von SkiZones 0.4.0

Stand: 27.10.2026 · Godot 4.5.1 (`f62fdbde1`).

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 54 automatisierte Prüfungen |
| Karriere und Langzeitbetrieb | 48 automatisierte Prüfungen; Forschung, Aufträge, Ausbau, Migration und zwei vollständige Winter |
| Szene, UI, Touch und Liftanimation | 54 automatisierte Prüfungen mit aktiver Compatibility-Grafikausgabe |
| Schnee und Gebiete | 37 Prüfungen für persönliche Fahrten, Spuren, lokale Verformung, Präparierung, Karten und Bergpass |
| Automatische Pistenplanung | 20 Prüfungen für direkte und querende Routen, steilste Abschnitte, Nummerierung, Migration und beschädigte Daten |
| Verzweigungen und Teilstrecken | 30 Prüfungen; Können, Andocken, zusammenhängende Abschnitte, lokale Teilspuren, Speicherfortsetzung auf dem echten Sonnenhang und ein Netz mit 2.304 Wegpunkten |
| Kamera, Gelände und Punktbearbeitung | 21 Prüfungen mit tatsächlicher Grafikausgabe; Touch-/Maus-Drag, Abbruch, Löschen, vier Perspektiven, Geländepicking, Höhenlinien, Richtung der gerenderten Pfeile und sichtbare Bauaktionen |
| Tatsächliche Gebietswechsel | 8 Prüfungen mit getrennten Dateien in isolierter Laufzeitumgebung |
| Langzeitlauf | 56 vollständige Betriebstage mit echten Gästen, Abfahrten, erledigten Aufträgen und allen neun Forschungen |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Blaue Route mit roten/schwarzen Abkürzungen, verschiebbare Planungspunkte, Höhenprofil, Kameramenü, Höhenlinien/Gefällepfeile und runde nummerierte Schilder im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Die insgesamt 272 Prüfungen bestätigen die getesteten Abläufe; sie ersetzen keine abschließende Wirtschafts- oder Geräteprüfung. Der Langzeitlauf plant Forschung, Erweiterungen und Aufträge über reguläre Simulationsaktionen. Er prüft auch Speicherfortsetzungen in beiden Wintern und die rollierende Finanzhistorie.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.4.0/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.

Die Szenentests brauchen eine echte Grafikausgabe; unter Linux kann `xvfb-run -a godot --audio-driver Dummy --script tests/scene.gd` verwendet werden. Ein Dummy-Renderer speichert keine auslesbaren MultiMesh-Transformationen und ersetzt diese Prüfung nicht. Der Test misst am tatsächlichen Liftfahrzeug wenige Meter Weg pro Normaltempo-Sekunde und Stillstand bei pausierter Uhr.

Für den Test echter Gebietswechsel muss eine isolierte Laufzeit gewählt werden: `XDG_DATA_HOME=/tmp/skizones-test-regions godot --headless --script tests/regions.gd`. Er verweigert die Arbeit ohne passenden Testpfad und entfernt ausschließlich seine isolierten Spielstände.

Die Abschnittsprüfung verwendet einen steilen Testhang mit identischem Start und Ziel für direkte und querende Verläufe. Ergänzend wird eine ungefähr 945 m lange blaue Route auf dem tatsächlichen Sonnenhang mit roten und schwarzen Abkürzungen gebaut. Ein Gast auf der blauen Ausfahrt wird gespeichert und an derselben Position fortgesetzt. Ein größerer Test erzeugt 36 Pisten mit je 64 Wegpunkten und validiert alle vollständigen Routen.

Auch `tests/planning_scene.gd` benötigt eine echte Grafikausgabe. Die zusätzlichen Modelltests laufen mit `godot --headless --script tests/piste_planning.gd` und `godot --headless --script tests/junctions.gd`.
