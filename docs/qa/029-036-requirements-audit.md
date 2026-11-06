# Anforderungsabgleich 0.29 bis 0.36

Stand: 6. November 2026. Geprüfte öffentliche Basis: `ebb193d`, Spielcode der veröffentlichten **v0.36.0**, Android versionCode **46**. Dieser Bericht unterscheidet die ausgelieferte Basis von den Änderungen auf dem neuen Arbeitszweig. Eine offene Checkbox im Issue allein beweist keine fehlende Implementierung: Release-Notizen, Quellcode und Prüfbelege wurden gemeinsam betrachtet.

## Tatsächlich ausgelieferte Schritte

| Version | Nachweisbarer neuer Umfang |
| --- | --- |
| 0.29 | Kein eigenständiger öffentlicher Release/Tag im geprüften Archiv. Entwicklungsarbeiten an Radio, Hotel-Lobby-Kontext und Betriebsaktivitäten gingen in 0.30 ein. Nicht als separate APK zählen. |
| 0.30 | Erweiterte lokale Radiosender mit Titel-/Künstlerangaben und Hotel-Lobby-Musik; weitere Alt-Karriere-Wiederherstellung; mobile Anpassungen; an Betriebswerte gebundene Trainingsaktivitäten. |
| 0.31 | Alpen-ExtraBlatt mit echten Resortdaten und Radiozugang; Rathaus mit Chronik/Plan; Neon Noir, Aurora Ink und Bauhaus; zusätzliche Dorfdekoration und November-Plakate. |
| 0.32 | Fünf Startkapitalprofile, Bewerbermarkt, Pistenraupenkauf und Szenario-Betriebsgebäude; Kameratour und interaktiver Relief-Pistenplan; zehn Themes einschließlich Monochrom mit eigener Geometrie; breite originale Wortmarke und Betriebskennzahlen. |
| 0.33 | Seltenere Stürme und unterscheidbare Wetterbilder; tatsächlich spielbares Tic-Tac-Toe; geordneter Nachtbetrieb/Morgenandrang; sofort gespeicherte Radioeinstellungen und uhrzeitsynchrone Sender; nach Bau direkt zur fertigen Anlage. |
| 0.33.1 | Lesbarkeit und Hintergrund der Spielecke in allen zehn Themes verbessert. |
| 0.33.2 | Geometrische Rettung gültiger Alt-Saves mit Originalarchiv; vier getrennte freie Speicherplätze und sichere Neustarts; eindeutiger Speicherstatus. |
| 0.34 | 1×/4×/8×; automatische Geländekamera beim Liftbau; erste vierstufige Fußabnutzung; bewegte Vegetation und Betriebsanimationen; weitere Landschaftsmodelle; SoundCloud entfernt und elf zusätzliche lokale CC0-Titel. |
| 0.34.1 | Korrigierte Schneeschmelze und reale Tagesgäste auch nach Tag 1; Hotelaufbruch zwischen 07:00 und 08:59 mit gemeinsamem Familienstart. |
| 0.35 | Bedientes Radiogerät mit 15 Presets/16 Logos; gemeinsames Ereignis-Banner und Verlauf; 33 Gebäudekataloge/167 Angebote, reale Artikelverkäufe und Wareneinsatz, Ausbau bis Stufe 5; Pizzapreise/-kalkulation; sechs feste und ein konfigurierbares Darlehen; Reaktionsspiel; gespeicherte Schneeabnutzung; Teilüberarbeitung der Pistenstatistik und Geländeabfragen. |
| 0.35.1 | Mehr parallele Bewegungskorridore, bessere Auswahl alter Pisten/Lifte und sichere kurze Altanschlüsse; freies Bauen ohne Forschungs-/Budgethürden; zusätzliche Original-Save-Prüfungen früher Fassungen. |
| 0.36 | Optionale reale Hotelzimmerbelegung für Einzelgäste/Familien; schmutzige, gereinigte und gesperrte Zimmer; dienstabhängiges Housekeeping; interner speicherbarer Etagenplan und kostenpflichtiges Versetzen. Enthält den 0.35.1-Stabilitätsstand. |

Die 1.000 Erfolge, 500 Ränge, linearen Hotelketten und Grundfunktionen der vier realen Szenarien waren schon vor diesem Zeitraum vorhanden. Sie sind kein neuer 0.36-Umfang. Die veröffentlichten Notizen enthalten zum Teil alte Kandidatentexte; ein tatsächlich vorhandener Release mit APK ist für den Veröffentlichungsstatus maßgeblich.

## Besprochen, aber in der öffentlichen 0.36 nicht vollständig erfüllt

| Anforderung / Ursprung | Stand 0.36 | Konkrete Lücke |
| --- | --- | --- |
| Vollständiger Pistenplaner, #66 | Teilweise | Oben nur Länge/Höhenverlust; ausführliches Profil weiter im Scrollkatalog, zwei zusätzliche Reiter. Keine Grade in Grad, keine feste Segmentanzeige, kein vollständiger gleichzeitiger Statistik-/Kosten-/Anschlussblick. |
| Gesamte mobile UI-Runde, #15/#44/#66 | Teilweise | Einzelne Ansichten angepasst; kein durchgehender Abnahmebeleg für jede Seite. Die Bedienbarkeit des Pistenplaners bleibt trotz einzelner bestandener Sichtbarkeitsprüfungen unzureichend. |
| Landschaft, #15/#25 | Teilweise | 30 Zusatzmodelle, fünf Baumformen und Wind vorhanden. Großflächig sehr helle Schneegrundflächen; zusätzliche Modelle allein erzeugen noch keine gut gegliederte Landschaft. |
| Fußspuren → natürliche Wege, #65 / Nutzerbericht | Teilweise | Abnutzung persistent, Darstellung aber aus separaten flachen Rechtecken. Auf erhöhten Geh-/Stationsflächen können diese unter der Oberfläche liegen. Noch keine zusammenhängenden, abgerundeten Pfadformen. |
| Wegbau / aktueller Nutzerauftrag | Punktweise Grundfunktion vorhanden | Genau ein acht Meter breiter Wegtyp; keine freie Zeichenbewegung mit anschließender Punktberechnung. Die Sichtbarkeit/Beläge müssen verbessert werden. Die Freihand- und Belagsanforderung wird hier als neuer Auftrag dokumentiert, nicht rückwirkend als zugesagte 0.35-Auslieferung. |
| Durchgängig fahrbare reale Szenarien, #10/#63 | Teilweise | Vier Szenarien spielbar, aber nicht jede importierte Piste bildet einen vollständigen Rückweg. [Dokumentierter Audit](032-route-coverage.md): Braunlage 21/26, Filzmoos 12/25, Kitzbühel 219/448, Seiser Alm 96/146 volle Experten-Rundwege auf der damaligen geprüften Basis. Das sind keine neu gemessenen 0.36-Zahlen. |
| Hotel-Tycoon, #20/#69 | Teilweise | Erste Zimmerzustände und Etagenpositionen jetzt vorhanden. Freie äußere mehrgeschossige Architektur, 20 neue Modularten, 100 wirksame Hotel-Forschungen, sichtbare Personal-/Wäscherouten und tiefe Rezeption fehlen weiterhin. |
| Toilet Tycoon für 0.36, #67/#20 | Nicht umgesetzt | Kein Sanitärsimulator, keine bedarfsabhängigen WC-Wege, kein Sanitär-Dashboard/Heatmap und kein 100er-WC-Forschungsbaum. **Dieser für 0.36 geplante Umfang wurde mit der veröffentlichten Hotelzimmer-Version nicht geliefert.** |
| Alle Betriebe als tiefe Simulatoren, #71 | Teilweise | Angebote, Ausbau und echte Einzelverkäufe vorhanden. Vollständige Lager-/Nachschub-, Kurs-, Rettungsfahrzeug-, Trainings- und sichtbare Fahrzeug-Upgrades fehlen. Ein Katalog ist kein vollständiger Spezialsimulator. |
| Fünf Startstufen langfristig balancieren, #71 | Teilweise | Startprofile und Kredit-/Wirtschaftsregeln vorhanden; kein vollständiger reproduzierbarer Mehrwinter-Bericht über acht Karten × fünf Profile × mindestens 100 Seeds. |
| Genres und lange Musikprogramme, #25/#63 | Teilweise | Lokale Musik und synchrone Programme vorhanden. Nicht jeder Sender besitzt mindestens zehn neue einzigartige und authentisch genrepassende Aufnahmen; nicht alle Space-/Atmospherics-Titel erfüllen die gewünschte Mindestlänge. |
| Mehr echte Freizeitspiele, #47 | Teilweise | Tic-Tac-Toe und Reaktionsspiel. Koch-/Barkeeper-Spiele, Donut Toss, Billard, Schach, Blackjack sowie eigenständige Zimmerpflege-Spiele fehlen. Betriebstraining wird nicht als deren Umsetzung gezählt. |
| 750 Theme-/Saisonvarianten, #68/#69 | Teilweise | Zehn Stilsprachen und erste Festdekoration. Nicht das gesamte Hotel-/Sanitär-/Fahrzeug-/NPC-/Umweltinventar in allen gewünschten Ausbau- und Saisonvarianten. |
| Crew, Busse und lebendiger Ort, #10/#25 | Teilweise | Bestehende Arbeits-/Besucherwege und Darstellungen. Kein vollständiges individuelles Mitarbeiterwohn-/Pendelsystem und keine lückenlose originalgetreue Bus-/Straßen-/POI-Simulation aller vier Orte. |
| Echte Festhandlungen und begehbare Welt, #21 | Langfristig offen | Kalender und Dekoration vorhanden; freie Avatar-Erkundung, begehbare zusammenhängende Innenräume, Geschenkeübergaben und vollständige Fest-NPC-Handlungen fehlen. Dieser Umfang war ausdrücklich langfristig geplant. |

## Aktueller Arbeitszweig nach 0.36

`fix/037-planning-paths-landscape` ist als Kandidat **0.37.0 / Android versionCode 47** vorbereitet und adressiert den aktuellen Nutzerbericht:

- Feste Pistenwerte und Höhenprofil ohne Route-/Statistikreiter oder Scrollcontainer; Neigung in Prozent und Grad, ausgewählter/letzter Abschnitt, Länge, Breite, Auf-/Abstieg, Kosten und Anschlussstatus.
- Nach Ende der Planung wieder eine erreichbare Pistenbauaktion; fertige Anlagen bleiben über den Inspektor bedienbar.
- Freihand-Fußwege für Touch und Maus, anschließend vereinfachte editierbare Wegpunkte. Zwei-Finger-Gesten brechen einen unvollständigen Strich ab; bestehende Geometrie-/Budget-/Anschlussregeln bleiben wirksam.
- Vier Beläge: Schnee, Kies, Holz und Pflaster, mit eigenen Kosten, sichtbaren Oberflächen und kompatibler optionaler Speicherung. Alle haben denselben tatsächlich navigierbaren acht Meter breiten Korridor.
- Echte Sohlenformen und zusammenhängende abgerundete Schneepfade, die auch auf Stations-/Platzflächen auf deren sichtbarer Oberfläche liegen. Bestehende gespeicherte Abnutzungszellen bleiben lesbar.
- Mehr Fels-/Heide-/Schattierungsvariation und dunklere Vegetation; keine Änderung der Geländephysik oder gespeicherter Anlagenpositionen.

**Dieser Abschnitt beschreibt Entwicklungsarbeit, keine neue öffentliche APK.** Modell-, echte Render-/Touch- und Kompatibilitätsprüfungen werden separat protokolliert. Android-30/36-Releasefreigabe ist damit nicht ersetzt.

## Quellen im Repository

- [Veröffentlichte Versionshistorie](../../CHANGELOG.md) und `docs/releases/0.30.0.md` bis `0.36.0.md`.
- [Bisheriger 0.35-Anforderungsabgleich](035-integration.md), [Hotelzimmer-QA](hotel-room-operations.md), [Zwei-Monats-Plan](../ROADMAP_2026_11_2027_01.md).
- GitHub-Issues [#10](https://github.com/chekento/SkiZones/issues/10), [#15](https://github.com/chekento/SkiZones/issues/15), [#20](https://github.com/chekento/SkiZones/issues/20), [#21](https://github.com/chekento/SkiZones/issues/21), [#25](https://github.com/chekento/SkiZones/issues/25), [#66](https://github.com/chekento/SkiZones/issues/66), [#67](https://github.com/chekento/SkiZones/issues/67), [#68](https://github.com/chekento/SkiZones/issues/68), [#69](https://github.com/chekento/SkiZones/issues/69), [#71](https://github.com/chekento/SkiZones/issues/71).
