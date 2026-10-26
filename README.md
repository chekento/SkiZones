# SkiZones

Ein eigenständiger **3D Ski Resort Tycoon für Android**, entwickelt mit **Godot 4.5.1** und GDScript. Version 0.1.0 ist eine spielbare Grundlage für den weiteren Ausbau.

![SkiZones im Spiel](docs/screenshots/resort.png)

## Direkt losspielen

Unter [Actions → Validate and build Android](https://github.com/chekento/SkiZones/actions/workflows/validate-and-build.yml) den letzten erfolgreichen Lauf öffnen und das Artefakt **SkiZones-Android-debug** herunterladen. Die ZIP-Datei enthält die signierte Test-APK und ihre SHA-256-Prüfsumme. Auf dem Android-Gerät die APK installieren und bei Bedarf das Installieren aus dieser Quelle erlauben.

Das ist eine ARM64-Testversion für die lokale Installation. Sie ist keine Veröffentlichung im Google Play Store. Physische Android-Geräte müssen zusätzlich auf Leistung, Darstellung und Bedienung getestet werden.

Am Computer: Das Repository klonen, `project.godot` in **Godot 4.5.1 Standard** importieren und **F5** bzw. „Projekt ausführen“ wählen. Es sind keine Erweiterungen, API-Schlüssel oder kostenpflichtigen Assets erforderlich.

## Was bereits spielbar ist

- **Mehrere erschließbare Hänge** auf einer eigenen, prozedural gestalteten 3D-Karte mit Wald, Talzugang und gefrorenem See.
- **Frei geplante Pisten**: Wegpunkte für blaue, rote und schwarze Abfahrten setzen. Das gesamte Geländeprofil entscheidet über die zulässige Schwierigkeit.
- **Drei Liftarten**: Schlepplift, 4er-Sessel und Gondel, mit unterschiedlichen Kosten, Kapazitäten und Windgrenzen.
- **Ein zusammenhängendes Wegenetz**: Gäste benötigen einen nutzbaren Rundweg vom Talzugang und zurück. Auch aufeinanderfolgende Lifte und mehrere Abfahrten in einer Route funktionieren.
- **Gäste mit drei Könnensstufen**, Eintrittspreisen, Aufenthaltsdauer, Warteschlangen, Beförderungen, Skirunden, Ausgaben und Zufriedenheit.
- **Acht Gebäudetypen**: Berghütte, Restaurant, Skiverleih, Skischule, Beschneiung, Pistenraupengarage, Hotel und Bergwacht. Gebäude wirken in dieser Version über betriebliche Kennzahlen.
- **Tagesbetrieb von 08:00 bis 18:00**, Wetter, Windschließungen, Schneemangel, Pistenverschleiß und nächtliche Präparierung.
- **Baukosten, Betriebskosten, Tagesberichte, Aufbaukredit und vier Meilensteine** mit einmaligen Prämien.
- **Touch- und Mausbedienung**, drehbare und zoombare Kamera, Pause, 1×/4× Geschwindigkeit, Auswählen, Schließen und Abbauen von Anlagen.
- **Lokale Spielstände** mit Prüfsumme, geprüfter Wiederherstellung, atomarem Dateiaustausch und einer vorherigen Sicherung. Speichern ist manuell, beim Tageswechsel und bei App-Pause möglich.

## Erste Schritte im Resort

1. **Neues Resort · Sonnenhang** eröffnet einen betriebsbereiten blauen Rundweg mit Schlepplift, Hütte und Skiverleih. Für einen Start ohne Anlagen gibt es **Freier Aufbau**.
2. Im linken Menü eine Pistenfarbe wählen. Oben am Hang beginnen und weitere Punkte bergab setzen. **Bauen** bestätigt die gesetzte Route.
3. Für neue Hänge zuerst die **Talstation**, dann die **Bergstation** eines Lifts planen. Lift und Abfahrt müssen zusammen einen Rückweg ermöglichen.
4. Stationen und Pistenenden verbinden sich innerhalb von **42 m**. Im Tal sind zusätzliche Fußwege bis **220 m** möglich.
5. Gebäude im Tal oder nahe einer Station ergänzen. Gäste, Warteschlangen, Ruf und Tagesergebnis beobachten; die Tageskarte im Resort-Kompass einstellen.

Die Schwellen **Blau ≤30 %, Rot ≤55 %, Schwarz ≤110 %** sind bewusst gewählte Spielregeln, keine zugesicherte reale Pistenklassifizierung. Strecken mit nennenswerten bergauf führenden Abschnitten werden abgewiesen.

| Aktion | Android / Touch | Computer |
|---|---|---|
| Punkt setzen / Anlage auswählen | Antippen | Linksklick |
| Karte bewegen | Ziehen | Ziehen mit linker/mittlerer Maustaste |
| Zoomen | Zwei Finger oder −/+ | Mausrad oder −/+ |
| Drehen | ↶ / ↷ | Q / E oder ↶ / ↷ |
| Pause | Pause / Weiter | Leertaste |
| Werkzeug | Linkes Baumenü | Baumenü; B/R/K/L/G |
| Speichern | Speichern | Strg+S |
| Menü / Plan verlassen | Menü / Zurück-Taste | Esc / Rechtsklick für Werkzeug verlassen |

## Entwickeln und prüfen

```bash
godot --headless --editor --import --quit
godot --headless --script tests/run.gd
godot --headless --script tests/scene.gd
godot --headless -- --smoke-test
```

Die Tests decken Geländeprofile, Baukosten, Transportnetze, gemeinsame Liftkapazitäten, Tageswechsel, Wetter, aktive Gäste beim Speichern/Laden und Touch-Gesten in der echten Szene ab. GitHub Actions führt dieselben Prüfungen vor dem APK-Export aus.

- [Android-Export und Installation](docs/ANDROID.md)
- [Spielsysteme und Architektur](docs/DESIGN.md)
- [Roadmap und bewusste Grenzen des Prototyps](docs/ROADMAP.md)

## Originalität und Rechte

Code, Oberfläche, Namensgestaltung und prozedurale Modelle wurden für dieses Projekt erstellt. Fremde Spielinhalte, Marken, Grafiken oder Sounds werden nicht mitgeliefert. [Godot und seine Bestandteile](https://godotengine.org/license/) sowie die Android-Werkzeuge bleiben unter den jeweiligen Lizenzen ihrer Anbieter. Für dieses Repository wird mit diesem ersten Stand noch keine zusätzliche Open-Source-Lizenz erteilt.
