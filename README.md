<div align="center">

<img src="assets/icon.svg" width="96" alt="SkiZones Logo">

# SkiZones

**Dein Berg. Dein Resort. Dein nächster Winter.**

Ein eigenständiger 3D Ski Resort Tycoon für Android. Plane Abfahrten, erschließe neue Hänge und entwickle dein Skigebiet über mehrere Wintersaisons.

### [⬇ Android-APK direkt herunterladen · v0.5.0](https://github.com/chekento/SkiZones/releases/download/v0.5.0/SkiZones-0.5.0-android-arm64.apk)

[Release & Installation](https://github.com/chekento/SkiZones/releases/tag/v0.5.0) · [SHA-256-Prüfsumme](https://github.com/chekento/SkiZones/releases/download/v0.5.0/SkiZones-0.5.0-android-arm64.apk.sha256) · [Alle Downloads](https://github.com/chekento/SkiZones/releases)

[![Build und Tests](https://github.com/chekento/SkiZones/actions/workflows/validate-and-build.yml/badge.svg)](https://github.com/chekento/SkiZones/actions/workflows/validate-and-build.yml)

</div>

![SkiZones 0.5.0: begehbarer Stationsplatz mit sichtbarer Warteschlange und angeschlossenen Gebäuden](docs/screenshots/station-plaza.webp)

*Direkt aus dem Spiel: ein Testresort mit erzeugter Auslastung. Die Gäste stehen in der tatsächlichen Liftwarteschlange; die Gebäude und Pisten sind an die Stationsplätze angeschlossen. Die Karriere startet mit einem kleineren Resort.*

## Jetzt anspielen

1. Oben die **APK herunterladen** und auf deinem Android-Gerät öffnen.
2. Bei Bedarf die Installation aus dieser Quelle erlauben.
3. **Gebiete entdecken** und **Sonnenhang** wählen: Ein blauer Rundweg mit Lift, Hütte und Skiverleih ist bereits in Betrieb.
4. Im **Resort-Büro** einen Auftrag annehmen und die erste Forschung wählen. Während der Planung pausiert der Betrieb.

| Plattform | Voraussetzung |
|---|---|
| Android | Android 7.0 oder neuer · ARM64 · Querformat |
| Verbindung | Offline spielbar · kein Account erforderlich |
| Version | 0.5.0 Preview · mit einem Testschlüssel signiert |
| Computer | Godot 4.5.1 Standard · `project.godot` importieren · F5 |

Die APK, ihre Prüfsumme und Build-Metadaten liegen dauerhaft im GitHub-Release. Hinweise zu Updates und älteren Spielständen stehen in den [Release-Notizen](docs/releases/0.5.0.md).

## Neu in 0.5.0: richtige Lifte, lebendige Stationsplätze

**Schlepplift, Sessel und Gondel sind jetzt klar unterschiedliche Anlagen.** Jeder mitfahrende Gast hat ein konkretes Fahrzeug und einen festen Platz. Die Darstellung verwendet dieselbe Zuordnung wie die Simulation: keine nachträgliche Suche nach dem nächstgelegenen Sessel und keine Doppelbelegung.

![Vier Gäste sitzen in ihrem tatsächlichen Vierersessel](docs/screenshots/chair-four.webp)

| Änderung | Im Spiel |
|---|---|
| **Teller-Schlepplift** | Offene Antriebsstation mit Umlenkscheibe, Zugseil und einzelnen Tellern. Die Gäste bleiben mit ihren Ski auf dem Boden. Grundtempo 1,5 m/s, maximal 700 m. |
| **Einer, Zweier und Vierer** | Eigene schmale beziehungsweise breitere Sessel, einzelne Polster und passende Sitzplätze. Unterschiedliche Geschwindigkeiten, Kosten und Streckenlängen. |
| **Größere Anlagen freischalten** | Der Sechser braucht Fördertechnik, der Achter die Alpine Meisterklasse. Gondeltechnik öffnet die Achtergondeln. Im freien Aufbau sind alle Typen direkt verfügbar. |
| **Sichtbare Warteschlangen** | Die Gäste stehen in Ankunftsreihenfolge am jeweiligen Lift an und rücken nach. Die tatsächliche Fahrzeugbelegung, Wartezeit und Zahl der Mitfahrenden sind ablesbar. |
| **Begehbare Stationsplätze** | Tal- und Bergstation besitzen eigene geräumte Bereiche. Die Pisten beginnen und enden auf diesen Plätzen mit Abstand zur Lifttechnik. |
| **Gebäude erweitern das Gebiet** | Neue Gebäude docken mit Vorplätzen und Fußwegen an. Auch über weitere angeschlossene Gebäude kann der Fußgängerbereich wachsen. |
| **Umsteigen und einkehren** | Gäste gehen zu benachbarten Liften und zu Gebäudeeingängen. Besuche dauern tatsächlich eine Weile; Serviceerlöse entstehen nach dem Besuch. Wege führen um Gebäudewände herum. |
| **Durchgängige Darstellung** | Ruhigerer Schlepplift, variable Seillängen an den Tellern, getrennte Antriebsmodelle, geräumte Liftkorridore und sanftere Übergänge vom Schnee in den Stationsplatz. |

![Acht tatsächliche Plätze im freischaltbaren Panoramasessel](docs/screenshots/chair-eight.webp)

**Pisten schließen am Platz an.** Die kleinen Anschlusskreise zeigen die möglichen Andockpunkte. Die Strecke fährt nicht in die Liftmaschine hinein. Direkte Verbindungen zwischen Pisten bleiben möglich, auch als schwierigere Zwischenstücke einer leichteren Route.

[Alle Liftwerte und Stationsplätze erklärt](docs/LIFTE_UND_PLAETZE.md) · [Pisten planen und verbinden](docs/PISTENPLANUNG.md)

<details>
<summary>Schlepplift, Baukatalog und Gondeln ansehen</summary>

![Unterschiedliche Liftkarten mit Tempo und Längenbegrenzung sowie tatsächlicher Auslastung](docs/screenshots/drag-lift.webp)

![Achtergondeln mit zugeordneten Gästen im Kabineninneren](docs/screenshots/gondola-riders.webp)

</details>

## Seit 0.4.0: dein Verlauf entscheidet

**Plane ein Pistennetz mit echten Abzweigungen.** Eine lange Querung kann blau sein, während die direkte Abkürzung am selben Berg schwarz wird. Gäste wählen passende Rundwege für ihr Können und fahren nur die benötigten Teilstücke der verbundenen Pisten.

| Änderung | Im Spiel |
|---|---|
| **Wegpunkte bearbeiten** | Nummerierte Planungspunkte mit Finger oder Maus verschieben, einzeln löschen und den Verlauf vor dem Bau korrigieren. Preis, Höhenprofil und Farbe aktualisieren sich sofort. |
| **An Pisten andocken** | Kleine Kreise zeigen alle Wegpunkte bestehender Pisten. Neue Verbindungen rasten dort ein, auch mitten in einer Abfahrt. |
| **Wege nach Können** | Anfänger bleiben auf Blau, Geübte können Rot und Profis zusätzlich Schwarz fahren. Die Gäste nutzen gemeinsame Anfahrten und Ausfahrten; die Liftkapazität bleibt gemeinsam. |
| **Automatische Schwierigkeit** | Ein Werkzeug für alle Pisten. Das steilste Teilstück entlang der tatsächlichen Route bestimmt Blau, Rot oder Schwarz. Ein niedriger Durchschnitt verdeckt keine steilen Passagen. |
| **Runde Pistenschilder** | Farbe und eigene Pistennummer entstehen beim Bauen. Die Schilder stehen an Wegpunkten und entlang der Ränder und sind auf beiden Seiten beschriftet. |
| **Vier Kameraperspektiven** | Resort, Panorama, schräge Bauansicht und senkrechte Draufsicht. Dazu ein einstellbarer Blickwinkel; **C** wechselt die Perspektive. |
| **Berg und Tal erkennen** | Geländehilfe mit Höhenlinien im 20-m-Abstand, beschrifteten 100-m-Linien und Pfeilen bergab. Das Bauprofil zeigt Höhe, Höhenverlust, Durchschnitt und steilstes Gefälle. |

![Verschiebbare Planungspunkte und live berechnetes Höhenprofil](docs/screenshots/planning.webp)

**So baust du eine Abkürzung:** Öffne **Pisten → Abfahrt planen**, starte an einem kleinen Anschlusskreis der vorhandenen Piste und ende an einem weiter unten gelegenen Anschluss. Ziehe die nummerierten Punkte für einen anderen Verlauf. **Bauen** bestätigt die automatisch eingestufte Verbindung.

![Runde nummerierte Pistenschilder und individuelle Skispuren](docs/screenshots/signs.webp)

Die Schilder orientieren sich an runden alpinen Pistenmarkierungen. Die Gefällegrenzen bleiben die bisherigen **Spielwerte**: Blau ≤30 %, Rot ≤55 %, Schwarz ≤110 %. Die Einstufung nutzt das Längsgefälle deiner Route; reale Regelwerke berücksichtigen weitere Eigenschaften. Mehr dazu und zur Bedienung: [Pisten planen und verbinden](docs/PISTENPLANUNG.md).

<details>
<summary>Kamera und Geländehilfe ansehen</summary>

![Vier Perspektiven und ein einstellbarer Kamerawinkel](docs/screenshots/camera.webp)

![Höhenlinien, beschriftete Höhen und Pfeile bergab](docs/screenshots/relief.webp)

</details>

## Seit 0.3.0: mehr Berg, mehr Leben, mehr Ruhe

**Beobachte deine Gäste beim Skifahren.** Jeder Gast hat einen Namen, einen eigenen Fahrstil und ein persönliches Tempo. Die Skifahrer ziehen unterschiedliche Schwünge statt derselben geraden Linie zu folgen. Tippe einen Gast an, wähle **Diesem Gast folgen** und zoome bis in die Nahansicht.

![Individuelle Skifahrer und sichtbare Spuren im Schnee](docs/screenshots/skiers.png)

| Änderung | Was sich im Spiel verändert |
|---|---|
| **Ruhigeres Tempo** | Ein Betriebstag dauert bei 1× etwa 20 Minuten. Mit 4× kannst du Entwicklung und Bau beschleunigen. |
| **Nachvollziehbare Liftfahrten** | Die Fahrzeit folgt Länge und Liftart. Der erste Schlepplift benötigt bei 1× über zwei Minuten; Fahrzeuge und Förderkapazität passen dazu. Stützen und Seile folgen dem Gelände. |
| **Schnee mit Geschichte** | Ski ziehen Doppelspuren, verdichten Rinnen und schieben Schnee zu kleinen Buckeln auf. Die lokalen Unebenheiten beeinflussen spätere Fahrten und werden gespeichert. |
| **Präparierung** | Nachts werden Spuren und Unebenheiten geglättet. Mit Forschung und Garage kannst du tagsüber eine Pistenraupe einsetzen; die Piste ist währenddessen für neue Routen geschlossen. |
| **Größere Gebiete** | Vier unterschiedliche Landschaften mit 7,8 bis 29,1 km² Baufläche. Schon Sonnenhang bietet mehr als die vierzehnfache frühere Baufläche. |
| **Gebiete freischalten** | Sterne, Gäste und Aufträge öffnen neue Karten im Bergpass. Jedes Resort behält seinen eigenen Spielstand. |
| **Neuer Baukatalog** | Pisten, Lifte und Dorfangebote als übersichtliche Karten mit Preisen und Voraussetzungen. Gesperrte und zu teure Anlagen sind nicht auswählbar. |
| **Mehr bauen** | Fünf Liftarten und 14 Gebäudetypen; neu sind Zauberteppich, 6er-Panoramasessel, Punschstand, Terrasse, Wärmeunterstand, Snowpark, Spa und Skibus-Terminal. |
| **Bessere Übersicht** | Reliefkarte zum Navigieren, Gebietsübersicht, nähere Kamera, Beobachten einzelner Gäste, ausblendende Gebäude bei verdeckter Gastkamera und scrollbare Hilfe. |

![Der Bergpass mit vier Gebieten und ihren Freischaltzielen](docs/screenshots/regions.png)

| Gebiet | Baufläche | Freischaltung im Bergpass |
|---|---:|---|
| Sonnenhang | 7,8 km² | Von Anfang an |
| Fichtenkamm | 12,2 km² | 2 Sterne · 800 Gäste · 2 Aufträge |
| Gletscherwelt | 19,8 km² | 3 Sterne · 2.000 Gäste · 5 Aufträge |
| Drei Gipfel | 29,1 km² | 4 Sterne · 4.000 Gäste · 10 Aufträge |

Der höchste erreichte Resort-Rang sowie die Besucher- und Auftragsrekorde deiner Gebiete zählen für den Bergpass. Ein Gebietswechsel speichert das aktuelle Resort und lädt den Stand des nächsten Gebiets.

Die Karriere aus 0.2 bleibt dabei erhalten: **fünf Resort-Sterne, neun Forschungen, drei Ausbaustufen, wechselnde Aufträge und wiederkehrende Winter mit 28 Betriebstagen**. Das Resort-Büro pausiert den Betrieb für deine Planung.

![Neuer Baukatalog mit Punschstand, Panoramaterrasse und Wärmeunterstand](docs/screenshots/catalogue.png)

**Karriere** schaltet fortgeschrittene Technik durch Forschung frei. **Freier Aufbau** stellt die Anlagentypen und Ausbaustufen direkt bereit; neue Gebiete werden weiterhin über den Bergpass freigeschaltet. Ältere Spielstände behalten ihre bisherigen Baumöglichkeiten.

## Baue dein Skigebiet

| System | Bereits spielbar |
|---|---|
| Pisten | Verschiebbare Wegpunkte · Andockpunkte und Abzweigungen · automatische Farben und Schilder · Höhenprofil · Ausbau |
| Lifte | Acht Typen: Zauberteppich, Tellerlift, Einer-, Zweier-, Vierer-, Sechser-, Achtersessel und Achtergondel · feste Fahrzeugplätze · gemeinsame Förderkapazität · Windgrenzen · Ausbau |
| Gebäude | Hütte, Restaurant, Skiverleih, Skischule, Beschneiung, Garage, Hotel, Bergwacht und sechs neue Dorfangebote |
| Gäste | Können, Rundwege, geordnete Warteschlangen, konkrete Sitzplätze, Fußwege, Gebäudebesuche, Skirunden, Ausgaben und Zufriedenheit |
| Wirtschaft | Tageskarten, Bau- und Betriebskosten, Forschungskosten, Kredit, Prämien und Ergebnis nach Investitionen |
| Berg und Wetter | Schnee, Tauwetter, Windschließungen, Verschleiß, Präparierung und Forschungsprognose |
| Spielstände | Separate Gebiete · volle Gästerouten · Spuren und Schneerelief · Prüfsumme · Sicherung · Migration aus 0.1.x bis 0.4.x |

Gebäude besitzen angeschlossene Vorplätze, tatsächliche Besuche und Serviceerlöse. Nachfrage- und Komforteffekte bleiben teilweise über Kennzahlen abgebildet. Die lokale Schneeschicht verändert sich durch Skifahrer; das darunterliegende Berggelände lässt sich noch nicht frei bearbeiten. Einzelne Hotelbuchungen, Personal und die langfristige Feinabstimmung der Wirtschaft folgen im [Ausbauplan](docs/ROADMAP.md).

<details>
<summary>Gefälleansicht und Hauptmenü ansehen</summary>

![Gefälleansicht mit eingeblendeter Legende](docs/screenshots/slopes.png)

Die Farben zeigen die stärkste lokale Hangneigung. Die Schwierigkeit einer Abfahrt wird entlang ihrer tatsächlichen Route geprüft; Serpentinen können eine mildere Abfahrt ermöglichen.

![Hauptmenü mit dem freigegebenen Alpenpanorama](docs/screenshots/menu.png)

Das Panorama ist das Titelmotiv im Hauptmenü. Die anderen Bilder zeigen die tatsächliche 3D-Spielansicht.

</details>

## Deine erste Erweiterung

Im Baukatalog **Abfahrt planen** wählen, oben am Hang beginnen und weitere Wegpunkte bergab setzen. Nummerierte Punkte lassen sich ziehen und einzeln löschen; die Schwierigkeit entsteht automatisch. **Bauen** bestätigt die Route. Beim Lift zuerst die Talstation und dann die Bergstation setzen. Gäste benötigen einen vollständigen Rundweg vom Talzugang und zurück.

Pisten docken direkt an Pistenwegpunkten oder an begehbaren Stations- und Gebäudeplätzen an. Sichtbare Wege verbinden die vorbereiteten Bereiche; die Bauvorschau zeigt neue Gebäudeanschlüsse. **Blau ≤30 %, Rot ≤55 %, Schwarz ≤110 %** sind die Gefällegrenzen des Spiels.

| Aktion | Touch | Maus / Tastatur |
|---|---|---|
| Punkt setzen oder Anlage auswählen | Antippen | Linksklick |
| Karte bewegen | Ziehen | Ziehen mit linker/mittlerer Maustaste |
| Zoomen | Zwei Finger oder −/+ | Mausrad oder −/+ |
| Perspektive / Blickwinkel | Kamera | Kamera / C |
| Drehen | Kamera → Drehen | Q / E |
| Planungspunkt verschieben | Nummerierten Punkt ziehen | Nummerierten Punkt ziehen |
| Planungspunkt löschen | Punkt wählen → Punkt löschen | Punkt wählen → Entf |
| Pisten verbinden | Kleine Anschlusskreise antippen | Kleine Anschlusskreise anklicken |
| Größere Karte | Mehr Karte / Werkzeuge | Tab |
| Resort-Büro | Resort-Büro | M |
| Gäste beobachten | Gast antippen → folgen | Gast anklicken → folgen |
| Gebiet navigieren | Reliefkarte / Übersicht | Reliefkarte / Übersicht |
| Pause | Pause / Weiter | Leertaste |
| Speichern | Speichern | Strg+S |

## Entwicklung und Qualität

Das Projekt verwendet **Godot 4.5.1**, GDScript und den Compatibility-Renderer. Code, Oberfläche und prozedurale Modelle wurden für SkiZones erstellt. Das Hauptmenü nutzt das freigegebene Alpenpanorama. API-Schlüssel und kostenpflichtige Assets sind nicht erforderlich.

**362 automatisierte Prüfungen** decken Simulation, Spielstände, Karriere, Verbindungen, Liftkapazität, Oberfläche und Touch-Bedienung ab. Neue Prüfungen vergleichen direkte und querende Abfahrten am selben Hang, Verzweigungen nach Können, laufende Teilrouten nach dem Speichern, verschiebbare Punkte, vier Kameraperspektiven sowie Höhenlinien und tatsächliche Gefällepfeile. Ein Karrieretest spielt **56 vollständige Betriebstage** mit echten Gästen, Wetter, Forschung, Aufträgen und Speicherfortsetzungen durch. Die Tests prüfen auch echte Gebietswechsel mit getrennten Spielständen, feste Sitzplätze, Warteschlangen, Besuche und alte 0.4-Spielstände. Gerenderte Prüfungen lesen die tatsächlichen Fahrzeug- und Passagiertransformationen im Compatibility-Renderer aus. GitHub Actions prüft Projekt, APK-Signatur und Archiv vor der Veröffentlichung. Eine Prüfung auf einem physischen Android-Gerät steht noch aus.

```bash
godot --headless --editor --import --quit
godot --headless --script tests/run.gd
godot --headless --script tests/progression.gd
godot --headless --script tests/mountain_life.gd
godot --headless --script tests/piste_planning.gd
godot --headless --script tests/junctions.gd
godot --headless --script tests/lifts_and_plazas.gd
godot --script tests/scene.gd
godot --script tests/planning_scene.gd
godot --script tests/lift_scene.gd
godot --headless -- --smoke-test
```

[Android-Build](docs/ANDROID.md) · [Architektur und Spielsysteme](docs/DESIGN.md) · [Prüfstand](docs/VALIDATION.md) · [Roadmap](docs/ROADMAP.md)

## Rechte

Eine eigenständige Spielwelt von **KoSch**. Fremde Spielgrafiken, Marken oder Sounds werden nicht mitgeliefert. [Godot und seine Bestandteile](https://godotengine.org/license/) sowie die Android-Werkzeuge bleiben unter den Lizenzen ihrer Anbieter. Für dieses Repository ist bislang keine zusätzliche Open-Source-Lizenz erteilt.
