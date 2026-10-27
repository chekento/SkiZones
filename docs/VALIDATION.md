# Prüfung von SkiZones 0.2.0

Stand: 27.10.2026 · Godot 4.5.1 (`f62fdbde1`).

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 54 automatisierte Prüfungen |
| Karriere und Langzeitbetrieb | 48 automatisierte Prüfungen; Forschung, Aufträge, Ausbau, Migration und zwei vollständige Winter |
| Szene, UI und Touch | 41 automatisierte Prüfungen; auch Büro-Aktionen, Planungspause und Perspektivkamera |
| Langzeitlauf | 56 Tage, 31.231 Gäste, 217.923 Abfahrten, 70 erledigte Aufträge, alle neun Forschungen |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Hauptmenü, ausgebautes Testresort, Gefälleansicht und Resort-Büro im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Die insgesamt 143 Prüfungen bestätigen die getesteten Abläufe; sie ersetzen keine abschließende Wirtschafts- oder Geräteprüfung. Der Langzeitlauf plant Forschung, Erweiterungen und Aufträge über reguläre Simulationsaktionen. Er prüft auch Speicherfortsetzungen in beiden Wintern und die rollierende Finanzhistorie.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.2.0/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.
