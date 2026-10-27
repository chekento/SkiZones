# Prüfung von SkiZones 0.1.1

Stand: 27.10.2026 · Godot 4.5.1 (`f62fdbde1`).

| Prüfung | Umfang |
|---|---|
| Simulation und Speicherstände | 54 automatisierte Prüfungen |
| Szene, UI und Touch | 32 automatisierte Prüfungen |
| Neue Funktionen | Gefälleansicht, Wiederverwendung der Geometrie, große Karte mit erhaltenem Bauplan, sichere Displaybereiche |
| Start | Projektimport und Szenen-Starttest |
| Darstellung | Resort und Gefälleansicht werden im tatsächlichen Spiel gerendert und visuell geprüft |
| Android | Export mit passendem offiziellen Godot-Template; Signaturprüfung per apksigner und Archivprüfung |
| Download | Versionierte APK, SHA-256 und manifest.json im GitHub-Release |
| Physisches Android-Gerät | Noch nicht geprüft |

GitHub Actions führt Tests und Export vor dem Veröffentlichen aus. Ein fehlgeschlagener Build wird nicht als neuer APK-Download veröffentlicht. Bereits bestehende Releases werden bei wiederholten Builds erhalten.

Dateigröße, Prüfsumme und Quellcode-Commit der veröffentlichten APK stehen im [Release-Manifest](https://github.com/chekento/SkiZones/releases/download/v0.1.1/manifest.json). Der [Prüfstand von 0.1.0](validation/0.1.0.md) bleibt separat dokumentiert.
