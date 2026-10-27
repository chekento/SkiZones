<div align="center">

<img src="assets/icon.svg" width="96" alt="SkiZones Logo">

# SkiZones

**Dein Berg. Dein Resort.**

Ein eigenständiger 3D Ski Resort Tycoon für Android. Plane Abfahrten, erschließe neue Hänge und entwickle dein eigenes Skigebiet.

### [⬇ Android-APK direkt herunterladen · v0.1.1](https://github.com/chekento/SkiZones/releases/download/v0.1.1/SkiZones-0.1.1-android-arm64.apk)

[Release & Installation](https://github.com/chekento/SkiZones/releases/tag/v0.1.1) · [SHA-256-Prüfsumme](https://github.com/chekento/SkiZones/releases/download/v0.1.1/SkiZones-0.1.1-android-arm64.apk.sha256) · [Alle Downloads](https://github.com/chekento/SkiZones/releases)

[![Build und Tests](https://github.com/chekento/SkiZones/actions/workflows/validate-and-build.yml/badge.svg)](https://github.com/chekento/SkiZones/actions/workflows/validate-and-build.yml)

</div>

![Das laufende SkiZones-Resort](docs/screenshots/resort.png)

## Jetzt anspielen

1. Oben die **APK herunterladen** und auf deinem Android-Gerät öffnen.
2. Bei Bedarf die Installation aus dieser Quelle erlauben.
3. **Neues Resort · Sonnenhang** wählen: Ein blauer Rundweg mit Lift, Hütte und Skiverleih ist bereits in Betrieb. **Freier Aufbau** startet mit leerem Gelände.

| Plattform | Voraussetzung |
|---|---|
| Android | Android 7.0 oder neuer · ARM64 · Querformat |
| Verbindung | Offline spielbar · kein Account erforderlich |
| Version | 0.1.1 Preview · mit einem Testschlüssel signiert |
| Computer | Godot 4.5.1 Standard · `project.godot` importieren · F5 |

Der Download liegt als versionierte APK im GitHub-Release. Dort bleiben APK, Prüfsumme und Build-Metadaten verfügbar. Hinweise zum Aktualisieren einer früheren Testinstallation stehen in den [Release-Notizen](docs/releases/0.1.1.md).

## Neu in 0.1.1

- **Gefälle einschalten:** Die farbige Hangneigung hilft dir, geeignete Pisten zu planen.
- **Mehr Karte:** Blende Seitenleisten aus und betrachte dein Resort groß. Ein laufender Bauplan bleibt erhalten.
- **Smartphone-Layout:** Die Oberfläche berücksichtigt den vom Gerät gemeldeten sicheren Displaybereich.
- **Bessere Lesbarkeit:** Ruhigere Beleuchtung und präzisere Beschriftungen.
- **Ein Klick zur APK:** Direkter Download oben auf dieser Seite.

<details>
<summary>Gefälleansicht und große Karte ansehen</summary>

![Gefälleansicht mit eingeblendeter Legende](docs/screenshots/slopes.png)

Die Farben zeigen die stärkste lokale Hangneigung. Die Schwierigkeit einer gebauten Abfahrt wird entlang ihrer tatsächlichen Route geprüft; Serpentinen können eine mildere Abfahrt ermöglichen.

</details>

## Baue dein Skigebiet

| System | Bereits spielbar |
|---|---|
| Pisten | Frei gesetzte Wegpunkte · blau, rot und schwarz · Prüfung des gesamten Streckenprofils |
| Lifte | Schlepplift, 4er-Sessel und Gondel · Länge, Kapazität, Kosten und Windgrenzen |
| Gebäude | Hütte, Restaurant, Skiverleih, Skischule, Beschneiung, Garage, Hotel und Bergwacht |
| Gäste | Können, Rundwege, Warteschlangen, Skirunden, Ausgaben und Zufriedenheit |
| Betrieb | Tageskarten, Bau- und Betriebskosten, Kredit, Tagesbericht und Meilensteine |
| Berg und Wetter | Mehrere Hänge, Schnee, Tauwetter, Windschließungen, Verschleiß und Präparierung |
| Spielstände | Lokal speichern und fortsetzen · Prüfsumme und vorherige Sicherung |

Gebäude wirken in der aktuellen Version über Kennzahlen. Die vorgegebene Landschaft ist noch nicht verformbar. Echte Hotelbuchungen, Personal, Forschung und weitere Karten folgen im [Ausbauplan](docs/ROADMAP.md).

## Deine erste Erweiterung

Eine Pistenfarbe wählen, oben am Hang beginnen und weitere Wegpunkte bergab setzen. **Bauen** bestätigt die Route. Beim Lift zuerst die Talstation und dann die Bergstation setzen. Gäste benötigen einen vollständigen Rundweg vom Talzugang und zurück.

Stationen und Pistenenden verbinden sich innerhalb von **42 m**. Im Tal können Gäste zwischen Anlagen bis **220 m** zu Fuß gehen. **Blau ≤30 %, Rot ≤55 %, Schwarz ≤110 %** sind die Gefällegrenzen des Spiels.

| Aktion | Touch | Maus / Tastatur |
|---|---|---|
| Punkt setzen oder Anlage auswählen | Antippen | Linksklick |
| Karte bewegen | Ziehen | Ziehen mit linker/mittlerer Maustaste |
| Zoomen | Zwei Finger oder −/+ | Mausrad oder −/+ |
| Drehen | ↶ / ↷ | Q / E |
| Größere Karte | Mehr Karte / Werkzeuge | Tab |
| Pause | Pause / Weiter | Leertaste |
| Speichern | Speichern | Strg+S |

## Entwicklung und Qualität

Das Projekt verwendet **Godot 4.5.1**, GDScript und den Compatibility-Renderer. Code, Oberfläche und prozedurale Modelle wurden für SkiZones erstellt. Erweiterungen, API-Schlüssel und kostenpflichtige Assets sind nicht erforderlich.

**86 automatisierte Prüfungen** decken Simulation, Speicherstände, Verbindungen, gemeinsame Liftkapazität, Oberfläche und Touch-Bedienung ab. GitHub Actions prüft das Projekt und die APK vor jeder neuen Veröffentlichung. Eine Prüfung auf einem physischen Android-Gerät steht noch aus.

```bash
godot --headless --editor --import --quit
godot --headless --script tests/run.gd
godot --headless --script tests/scene.gd
godot --headless -- --smoke-test
```

[Android-Build](docs/ANDROID.md) · [Architektur und Spielsysteme](docs/DESIGN.md) · [Prüfstand](docs/VALIDATION.md) · [Roadmap](docs/ROADMAP.md)

## Rechte

Eine eigenständige Spielwelt von **KoSch**. Fremde Spielgrafiken, Marken oder Sounds werden nicht mitgeliefert. [Godot und seine Bestandteile](https://godotengine.org/license/) sowie die Android-Werkzeuge bleiben unter den Lizenzen ihrer Anbieter. Für dieses Repository ist bislang keine zusätzliche Open-Source-Lizenz erteilt.
