# Spielsysteme und Architektur

## Spielidee

SkiZones verbindet die Gestaltung eines eigenen Berggebiets mit einer lesbaren Betriebssimulation. Eine neue Anlage soll eine Entscheidung ermöglichen: Welchen Hang erschließt sie, welche Gäste können ihn fahren, wo entstehen Engpässe und trägt sich der Ausbau wirtschaftlich?

Der Kernkreislauf lautet: Gelände lesen, einen Rundweg planen, Betrieb eröffnen, Besucherströme und Ergebnis beobachten, gezielt ausbauen.

## Verantwortlichkeiten

| Datei | Aufgabe |
|---|---|
| `src/core/terrain.gd` | Gemeinsame Koordinaten, Grenzwerte und kompatible ursprüngliche Talform |
| `src/core/maps.gd` | Acht Originalregionen und Einbindung vier realer Gebiete, Topografie, Schnee und Startpakete |
| `src/core/mountain.gd` | Instanzbezogene Höhe, Grenzen, Pistenprüfung, Pfad-Cache und Seilprofile |
| `src/core/passport.gd` | Gebietsübergreifende Rekorde, Freischaltungen und letztes Resort mit eigener Sicherung |
| `src/core/ski_motion.gd` | Gemeinsame persönliche Fahrlinien für Figuren, Spuren und Schneeinteraktion |
| `src/core/snow_surface.gd` | Lokale Rinnen, aufgeschobener Schnee, begrenzte Spurhistorie und Präparierung |
| `src/core/catalog.gd` | Kosten und Kennzahlen von Liften, Gebäuden und Wetter |
| `src/core/lift_fleet.gd` | Gemeinsamer Fahrzeugtakt, Umlauf, Stationen und feste Sitzplatzpositionen |
| `src/core/real_resorts.gd` | Offline-Geodaten, unabhängiger Höhenraster und Szenarienstarts |
| `src/core/operations.gd` | Stationsbesetzung, Schichten, Werkstätten, Maschinen, Rettung und durchlaufende Betriebstage |
| `src/core/piste_links.gd` | Räumlicher Segmentindex, projizierte Andockpunkte und atomar bestätigte Anschlussknoten |
| `src/core/foot_junctions.gd` | Tatsächliche Wegkreuzungen und Überlappungen im Fußgängernetz |
| `src/core/foot_network.gd` | Stationsplätze, Gebäudevorplätze, sichtbare Fußwege, Hindernisse und Pistenanschlüsse |
| `src/core/resort.gd` | Geld, Zeit, Netz, Gäste, Warteschlangen, Schnee, Tagesabschluss, Fortschritt |
| `src/core/progression.gd` | Karriere, Sterne, Forschung, Aufträge, Ausbau, Jahreszeiten und Finanzhistorie |
| `src/core/save_store.gd` | Spielstand-Hülle, Prüfsumme, atomarer Austausch, Sicherung und Wiederherstellung |
| `src/world/resort_view.gd` | 3D-Darstellung, Gelände, Baum- und Gästeinstanzen, Bauvorschau, Kamera und Geländeauswahl |
| `src/world/alpine_art.gd` | Gebündelte eigene Modelle für Chalets, Liftstationen, Fahrzeuge, Tannen, Felsen und Skifahrer |
| `src/ui/hud.gd` | Menü, Bauwerkzeuge, Anlageninspektor, Preisanpassung, Berichte und Hilfe |
| `src/ui/management.gd` | Resort-Büro mit neun Seiten einschließlich Betrieb, Technik, Rettung und Kostenstellen |
| `src/ui/build_palette.gd` | Baukatalog mit gesperrten, bezahlbaren und ausgewählten Einträgen |
| `src/ui/drag_scroll.gd` | Finger-, Stift- und Mausziehen mit Klickunterdrückung nach Scrollbewegungen |
| `src/world/piste_mesh.gd` | Abgerundeter Pistenumriss und geschlossene, ausgeschnittene Rastertriangulierung |
| `src/ui/lift_icon.gd` | Eigene prozedurale Symbole für die acht Liftarten |
| `src/ui/route_profile.gd` | Live-Höhenprofil und Abschnittsfarben aus der tatsächlichen Bauprüfung |
| `src/ui/plan_overlay.gd` | Größengleiche nummerierte Punktgriffe und sichtbare Andockpunkte |
| `src/ui/atlas.gd` | Originalregionen mit Freischaltzielen und eigenem Resortzugang |
| `src/ui/minimap.gd` | Relief aus der tatsächlichen Kartenhöhe und Navigation zum gewählten Ort |
| `src/ui/finance_chart.gd` | Finanzdiagramm aus den letzten 28 tatsächlichen Tagesergebnissen |
| `src/main.gd` | Verbindet Simulation, Darstellung, Eingaben und App-Lebenszyklus |

Die Simulation kann ohne Fenster, Grafikkarte oder Android-Gerät getestet werden. Die Grafik nutzt dieselbe Höhenfunktion wie die Bauprüfung. Acht Originalregionen ergänzen vier Offline-Gebiete aus OSM-Linien und unabhängigen Höhendaten; die jeweiligen Baugrenzen stammen aus ihrer Kartenspezifikation. Die Landschaften sind fest vorgegeben; die Schneedecke auf den Pisten verändert sich lokal. Jede Simulationsinstanz besitzt ihre eigene Karte, sodass Laden und Prüfen anderer Resorts die laufende Landschaft nicht verändern.

## Pisten und Lifte

Pisten bestehen aus zwei bis 64 Wegpunkten. Jeder Abschnitt wird mindestens alle drei Meter auf Gefälle und Gegenanstieg geprüft. Das größte Längsgefälle entlang der tatsächlichen Route bestimmt automatisch die Farbe mit den bisherigen Spielgrenzen 30/55/110 %. Die Planung zeigt ein Höhenprofil, richtungsabhängige Farben und verschiebbare nummerierte Griffe. Mindestens 40 m Länge und 7 m Höhenverlust sind notwendig.

Lifte verlaufen von der Tal- zur Bergstation. Die Seillinie folgt dem Gelände über Stützen. Zusätzliche Profilpunkte sichern die Bodenfreiheit an lokalen Kuppen. Die tatsächliche räumliche Seillänge bestimmt Kosten und Fahrzeit. Acht Liftarten unterscheiden sich in Bauform, Sitzen, Tempo, Förderleistung, Windgrenze und maximaler Länge. Der Teppich ist auf 250 m und der Tellerlift auf 700 m begrenzt; größere Anlagen reichen bis 3.200 m. Die vollständigen Spielwerte stehen unter [Lifte und Stationsplätze](LIFTE_UND_PLAETZE.md).

Das Wegenetz besteht aus dem Talzugang, sichtbaren Stationsplätzen, angeschlossenen Gebäudevorplätzen und Wegen sowie allen Pistenwegpunkten. Die interaktive Bauprüfung erhält die gesetzten Pistenpunkte. Liftmaschinen und der gesamte breite Pistenstreifen müssen frei bleiben. Ältere programmatische Starts und Migrationen können vorbereitete Stationsenden verwenden. Innere Wegpunkte verbinden sich beim tatsächlichen Andocken innerhalb von 2 m. Andere Fußverbindungen folgen ausschließlich dem vorbereiteten Fußwegenetz. Verbindungswege dürfen höchstens 40 m Lücke überbrücken und umgehen Gebäude; Reservierungen vor Türen bleiben frei. Zwei Dijkstra-Suchen mit Prioritätswarteschlange pro Können erschließen alle Ziele vom Tal und zurück. Gondeln können im Betriebsmodus auch talwärts genutzt werden; klassische reguläre Liftkanten führen bergauf. Pisten sind in geplanter Fahrtrichtung gerichtet und können berechnete Gegenanstiege enthalten. Die Simulation sucht vollständige, für das Können geeignete Runden zurück zum Talzugang. Unerschlossene Abfahrten können bereits gebaut werden, bringen aber noch keine zahlenden Gäste.

## Gäste und Betrieb

Eine Simulationsminute ist ein fester Schritt, unabhängig von der Bildrate. Bei 1× laufen 0,5 Spielminuten je realer Sekunde. Ein klassischer Tagabschnitt dauert etwa 20 reale Minuten; im durchlaufenden Betriebsmodus entsprechen volle 24 Spielstunden etwa 48 realen Minuten. 4× beschleunigt denselben Ablauf. Eine reale Fahrminute entspricht in neuen Originalregionen 30 Spielminuten, in neuen realen Szenarien 10 Spielminuten. Die optionale gespeicherte Zeitskalierung erhält bei alten Spielständen den bisherigen Wert 30; reale Entfernungen und Höhen bleiben unverändert. Liftgeschwindigkeit und Förderkapazität werden entsprechend umgerechnet, sodass Fahrzeuge und Gäste im Normaltempo nachvollziehbare Fahrzeiten haben.

Gäste besitzen Können, Aufenthaltsdauer, Alter, eine konkrete Reiseroute, Wegabschnitt, Wartezeit und Ausgabenstatus. Eine stabile persönliche Kennung bestimmt Namen, Kleidung, Fahrstil und Tempo. Die Darstellung interpoliert den Bruchteil des aktuellen Simulationsschritts; individuelle Skilinien werden auch für Schneeinteraktion und Spuren verwendet. Gäste gehen zu Türen, verbringen 12 bis 20 Spielminuten im Gebäude und kehren auf ihren Rundweg zurück. Bedürfnisse können mehrere aufeinanderfolgende Besuche auslösen; abgerechnet wird nach dem tatsächlich abgeschlossenen Besuch. Ein Ticket wird beim Einlass genau einmal bezahlt. Gebäude führen eigene Besuchs- und Erlöszähler; Komfort und Nachfrage bleiben teilweise abstrahiert.

Jeder Lift besitzt eine eigene Uhr und eine Flotte mit festen Abfahrtszeiten. Das Intervall beträgt `60 × Reisezeitskalierung × Plätze / Stundenkapazität` Spielminuten. Eine Stationwartezeit ergänzt den Umlauf aus Bergfahrt, Umlenkungen und Talfahrt, damit Fahrzeugzahl und Förderleistung zusammenpassen. Beim Halt frieren Flotte und Mitfahrende gemeinsam ein. Gäste erhalten Fahrzeug, Abfahrt und eindeutigen Sitz; beide Darstellungen lesen dieselbe Position. Ausbauten verändern Tempo und Förderleistung, niemals die Zahl der Sitze.

Gäste werden nach tatsächlicher Anstellzeit abgefertigt; bei gleicher Zeit entscheidet ihre Kennung. Ein später eingetroffener Gast kann kein bereits abgefahrenes Fahrzeug mehr erreichen. Unbenutzte Plätze werden nicht angespart. Sichtbare Reihen und die gemessene Belegung der letzten Abfahrten zeigen die Auslastung. Wartende rücken in begrenztem Gehtempo nach und stehen bei Pause still. Mehrere Routen teilen dieselben Fahrzeuge und Sitze. Lange Wartezeiten senken die Zufriedenheit.

In klassischen Spielständen endet um 18:00 der Einlass. Laufende Liftfahrten, Abfahrten und Rückwege laufen mit denselben Gästen weiter; der nächste sichere Netzknoten dient der Rückwegplanung. Erst wenn das Resort leer ist, berechnet der Tagesabschluss die Betriebskosten einmalig und schreibt den vollständigen Bericht. „Nächsten Tag starten“ setzt auf 08:00 zurück, präpariert die Pisten und bestimmt das neue Wetter. Fahrzeugtakte bleiben erhalten; historische Belegungen werden gelöscht. Die vier Meilensteine zahlen ihre Prämien jeweils einmal aus.

Im Betriebsmodus der realen Szenarien läuft die Uhr über Mitternacht weiter. Stationsöffnungszeiten, Schichten und Reparaturzustand begrenzen den Liftbetrieb. Neue Routen müssen ihre Lift-Einstiege rechtzeitig erreichen; die letzte Skiabfahrt darf nach dem Schließen der Lifte enden. Um Mitternacht werden Bericht und Kostenstelle abgeschlossen, während Übernachtungsgäste und Abendangebote erhalten bleiben.


Für die Routenwahl sind statische Erreichbarkeit und warteschlangengewichtete Wegsuche getrennt. Die Wegsuche verwendet Acht-Personen-Bereiche zur Wiederverwendung ihrer Pfad-Caches; die Aufenthalts- und Feierabendentscheidung rechnet mit der aktuellen Wartezeit. Gäste planen ab ihrem tatsächlichen Pistenende weiter. Zeitabhängige, begrenzte Fahrprofile bilden Hangbeschleunigung, Widerstand und Kurvenbremsen ab und werden gemeinsam für Darstellung und Schneespuren verwendet.

## Karriere und Winter

Karrieren beginnen mit sechs Forschungspunkten. Die neun Projekte verbrauchen Geld und Punkte beim Start; Voraussetzungen und eine Laufzeit von ein bis drei Betriebstagen bestimmen die Reihenfolge. Fertigstellung und Freischaltung erfolgen erst am passenden Morgen. Pro 1.000 Erfahrung gibt es zwei Forschungspunkte; Betriebstage, Aufträge und Sterne liefern weitere.

Die fünf Sterne verbinden Erfahrung mit nutzbarer Infrastruktur. Ein unerschlossener Hang zählt nicht zum Netzziel. Bis zu drei Aufträge können laufen; zwei neue pro Tag stammen aus drei deterministisch wechselnden Angeboten. Zählziele beginnen bei der Annahme, Infrastrukturziele prüfen den aktuellen Bestand. Erfüllte Aufträge behalten ihre abholbare Prämie; beanspruchte Prämien können nicht erneut ausgezahlt werden.

Anlagen haben drei Stufen. Liftkapazität wächst je Stufe um 25 %, Fahrtempo um 10 %. Gebäude verbessern Komfort und Erlöse; Pisten werden breiter und verschleißen langsamer. Höhere Stufen verursachen mehr Betriebskosten. Im freien Aufbau gelten keine Forschungsbausperren.

Ein Winter umfasst 28 Betriebstage. Eine Saisonprämie belohnt Sterne und abgeschlossene Aufträge. Resort, Forschung und Ausbau bleiben über den Jahreswechsel bestehen. Der Wochenkalender verändert Nachfrage und Können der anreisenden Gäste. Die erforschbare Wettervorschau benutzt dieselbe Funktion wie das nächste tatsächliche Tageswetter.

Die letzten 28 Tagesabschlüsse halten Erlöse, Betriebskosten, Investitionen, Prämien und das Ergebnis nach Investitionen fest. Kreditaufnahme und Tilgung sind keine Betriebserlöse oder Kosten; offene Kredite verursachen die angegebenen täglichen Zinsen.

## Lokaler Schnee

Jede Piste besitzt ein Längsraster im Abstand von acht Metern mit neun Querwerten. Ski drücken lokale Rinnen ein und schieben Schnee auf die Nachbarbereiche. Die Verformung ist auf −0,34 bis +0,58 m begrenzt; sie beeinflusst die Dauer späterer Abfahrten und wird in der sichtbaren Pistenoberfläche abgebildet. Die Schneemenge sinkt auch durch Verkehr.

Bis zu 64 Fahrspuren pro Piste bleiben gespeichert. Die Darstellung zeichnet daraus ein begrenztes Budget jüngerer Doppelspuren. Dies begrenzt Speicher und Geometrie über lange Wintersaisons. Die Spur folgt derselben persönlichen Linie wie die sichtbare Figur.

Nachts werden Spuren entfernt und das Schneerelief geglättet; eine Garage verstärkt die Wirkung. Tagsüber kann eine erforschte Garage eine Piste gegen Geld 45 Spielminuten für neue Routen sperren. Eine sichtbare Pistenraupe fährt die Strecke ab. Danach ist das Relief geglättet und der Zustand wiederhergestellt. Bereits zugelassene Gäste behalten ihre vollständige Fahrt.

## Gebiete und Spielstände

Der Bergpass speichert die höchsten erreichten Sterne sowie Besucher- und Auftragsrekorde je Gebiet. Rekorde werden beim Speichern und Öffnen der Gebietsübersicht aktualisiert. Ein Neustart zählt dieselben Besucher nicht erneut. Neue Regionen erhalten eigene Resorts und eigene Zufallsabläufe. Jeder Gebietswechsel speichert vor dem Laden; ein fehlgeschlagener Speichervorgang verhindert den Wechsel.


Die JSON-Nutzdaten liegen in einer Hülle mit Formatkennung und SHA-256-Prüfsumme. Vor dem Austausch wird eine temporäre Datei geschrieben und geschlossen. Ein lesbarer vorheriger Stand bleibt als `.bak` erhalten. Beim Laden werden Version, Wertebereiche, Typen, Kennungen, Geometrie und Gästeindizes an einer separaten Simulationsinstanz geprüft.

Der Zufallszustand wird als Zeichenkette gespeichert, damit große Ganzzahlen durch JSON nicht an Genauigkeit verlieren. Aus JSON geladene Meilensteine werden wieder in Integer konvertiert. Ein Regressionstest prüft, dass der weitere Ablauf nach dem Laden gleich bleibt.

Format 6 ergänzt separat gebaute Gehflächen und abgeschlossene Abfahrten je Gast. Laufende Gäste aus Formaten bis 5 werden auf die Hindernisse berücksichtigende Wegeführung verteilt. Geld und bisherige Statistiken bleiben dabei erhalten.

Format 5 ergänzt Fahrzeuguhren, Abfahrten, feste Sitzplätze, Anstellzeiten, Besuchsabschnitte und Gebäudezähler. Beim Laden werden Plätze auf Eindeutigkeit, Fahrzeug und Fahrtdauer auf den tatsächlichen Takt sowie Routen auf die vorbereiteten Plätze geprüft. Formate 1 bis 4 werden auf das neue Netz übertragen; laufende Gäste werden dabei neu verteilt, ohne ein weiteres Ticket zu bezahlen. Alte Pistenenden und Schneeraster werden an die Stationsplätze angepasst. Ein alter Tellerlift über 700 m wird bei erhaltenen Investitionskosten zum Vierersessel.

Format 4 ergänzt feste Pistennummern und überprüfbare zusammenhängende Wegpunkt-Teilstücke in den gespeicherten Reiserouten. Spurdatensätze speichern Anfang und Ende der tatsächlich gefahrenen Teilroute; persönliche Fahrlinien laufen an Abzweigungen zur Mittellinie aus. Ganze durchgehende Skiabschnitte werden im Netz wieder zusammengeführt. Format 3 ergänzt Kartenkennung, geteilte vollständige Reiserouten, persönliche Fahrdauer, Schneerelief, Spurhistorie und laufende Präparierung. Format 2 enthält Karriere, Forschungsprojekt, Aufträge, Finanzhistorie und Ausbaustufen. Format 1 aus 0.1.x und Format 2 aus 0.2.x werden weiter gelesen; bestehende Anlagen beginnen auf Stufe 1 und behalten alle früher verfügbaren Baumöglichkeiten. Ungültige Karrierewerte werden vor dem Austausch der laufenden Simulation abgelehnt.

Neue Speicherstände behalten laufende Reiserouten auch dann, wenn eine Piste inzwischen für neue Routen geschlossen ist. Die Routen werden einmalig geteilt gespeichert und vor dem Laden gegen die Anlagen und Geometrie geprüft. Ältere Formate können eine bereits geschlossene Route weiterhin nur näherungsweise rekonstruieren. Ihre Fahrzeiten werden bei der Migration angepasst.

Die Nutzdaten sind auf 16 MB begrenzt. Auch der kleine Bergpass besitzt Prüfsumme, atomaren Austausch und vorherige Sicherung. Das ursprüngliche Resort benutzt weiterhin seinen bisherigen Dateinamen; weitere Regionen haben getrennte Dateien im privaten App-Verzeichnis.

## Darstellung und Budget

Gelände und Gebäude sind eigene prozedurale Geometrien. Tannen, Felsen, Skifahrer und Liftfahrzeuge verwenden MultiMesh-Instanzen. Gebäudeteile sind je Anlage in einem Mesh gebündelt. Jede Liftart besitzt eigene Fahrzeug-MultiMeshes; sitzende Sessel- und Kabinenfiguren, stehende Tellerliftgäste und Fußgänger verwenden passende Modelle. Passagiere und Fahrzeuge lesen denselben Flottentakt. Die Stationsplätze nutzen ein gemeinsames Geländeraster ohne überlagerte Flächen; Wald und Felsen bleiben aus dem Fußwegenetz und dem Liftkorridor frei. Runde beidseitig nummerierte Pistenschilder verwenden pro Piste ein gemeinsames Mesh mit MultiMesh-Instanzen. Die Perspektivkamera, Licht, Dunst und Schneefall hängen an der tatsächlichen Zeit beziehungsweise dem Wetter. Das Hauptmenü verwendet das freigegebene Panorama, die 3D-Spielwelt bleibt eigene Geometrie. Die Compatibility-Pipeline vermeidet eine Vulkan-Pflicht.

Version 0.7.0 begrenzt aktive Gäste auf 360, Pisten auf 80, Lifte auf 24 und Gebäude auf 60. Das sind Entwicklungsgrenzen, keine zugesicherte Bildrate bei voller Auslastung. Geometrische Pfadlängen werden zwischengespeichert. Figuren und Liftfahrzeuge folgen dem kontinuierlichen Anteil der Simulationszeit. Gebäudemodelle blenden aus, wenn sie die Nahkamera eines beobachteten Gasts verdecken. Die Reliefkarten verwenden zwischengespeicherte Bilder aus den tatsächlichen Höhenwerten. Stützen und Seile werden je Lift in einem Mesh gebündelt. Wälder sind in separat sichtbare Gruppen geteilt; entfernte Bäume verwenden einfachere Modelle. Jede Liftflotte besitzt ihre eigene, exakt dimensionierte Instanzgruppe. Schneeflächen bleiben auf der GPU und erhalten kleine Höhentexturen; historische Fahrpunkte werden begrenzt zwischengespeichert. Der ausgewählte Gast bleibt exakt, andere Skifahrer werden stetig zwischen zeitlich versetzten Fahrproben interpoliert. Automatische Qualität reduziert nur die Darstellungskosten. [Messmethode und Grenzen](PERFORMANCE.md).

Vier wählbare Kameraperspektiven teilen sich Geländeauswahl, Navigation und Bauplan. Die senkrechte Ansicht verwendet eine orthografische Projektion. Geländehilfe und Höhenlinien werden aus denselben Dreiecken wie das sichtbare Gelände erzeugt und zwischen Umschaltungen wiederverwendet; Gefällepfeile folgen dessen Normalen.

## Bauablauf und Bedienung ab 0.6

Ein nicht leerer Plan sperrt andere Werkzeuge und pausiert die Simulation, ohne die persönliche Pauseneinstellung umzuschalten. Bau oder Abbruch geben die Werkzeuge frei. Abbruch, Android-Zurück und Escape löschen auch aktive Maus-/Touchkontakte und Wegpunkt-Drags. Karten reagieren beim Loslassen nur, wenn keine Scrollbewegung stattfand. Dieselbe Scrollklasse wird im Katalog, Inspektor, Bergpass und Resort-Büro verwendet. Kamera-Verschieben und Zoom verwenden Geländeanker statt eines festen Schätzfaktors je Blickwinkel.

Fußwege verwenden ein Sichtbarkeitsnetz um vereinigte Gebäude-, Stations- und Zugspur-Umrisse. Die Darstellungsbewegung beim Nachrücken verwendet dieselben Hindernisse. Zusätzliche Gehflächen werden in `walk_areas` gespeichert, im Netz verwendet und als eigene Anlagen ausgewählt und abgebaut.

Die Pistenoberfläche entsteht aus dem abgerundeten Gesamtumriss einer breiten Linie und wird zellenweise am Gelände ausgeschnitten. Diese Geometrie wird bis zur nächsten Anlagenänderung wiederverwendet; Schneeverformung aktualisiert ihre Höhen und Farben. Die Schwierigkeit folgt weiterhin der geprüften Mittellinie.

Die Grundkosten betragen 450 € plus 80 € je Lift und 35 € je Gebäude; zusätzliche Gehflächen kosten je Radiusmeter 0,35 € bei Betrieb. Stark ausgelastete Warteschlangen reduzieren den Neuzulauf bis auf 35 %. Aufenthalte dauern 300 bis 520 Spielminuten. Tatsächlich abgeschlossene Abfahrten und Wartezeiten beeinflussen die Zufriedenheit. Das sind abstimmbare Spielwerte, keine Prognose einer realen Resortwirtschaft.


## Gestaltung und persönliche Gäste seit 0.7

Umbauten werden in einem vom Live-Modell getrennten Prüfkontext vorbereitet. Erst nach Prüfung aller betroffenen Pisten, Geometrie, Namen, Farben und des verfügbaren Budgets wird gemeinsam übernommen. Identitäten, Anlagenstatistiken und Schneehistorie bleiben erhalten. Fußwege berücksichtigen gedrehte Gebäudeeingänge. Charaktereigenschaften sind aus der Gast-ID reproduzierbar; Mimik und Bedürfnisse entstehen aus tatsächlichen Fahrten, Wartezeit, Einkehr und Wetter. Profile werden beim Betrachten berechnet, nicht für jeden Gast in jedem Bild.

## Wege und Energiemodell ab 0.9

Das Fußnetz enthält sichtbare und tatsächlich benutzte Anschlüsse zu Türen, Liftzugängen und Pistenenden. Direkte Pisten-Zugänge sind feste Verbindungen. Weitere automatische Verbindungen bilden ein zusammenhängendes Grundnetz, ohne jede nahe Fläche mit jeder anderen zu verbinden. Benutzerwege liegen als `kind: walkway` mit eigenen Punkten in `walk_areas`; dieselben Punkte bilden Graphkanten und sichtbare Oberfläche. Gesperrte Wege behalten ihre physische Fläche für laufende Gäste, werden für neue Routen aber nicht als durchgängige Verbindung verwendet.

`ski_dynamics.gd` integriert spezifische Bewegungsenergie mit Höhenarbeit, Gleitreibung und geschwindigkeitsabhängigem Widerstand. Kurven und die kontrollierte Ankunft begrenzen das Tempo. Es gibt keine künstliche Mindestgeschwindigkeit beim Bergauffahren: Ohne ausreichende Energie beginnt eine langsame Gehphase. Sie bleibt bis zum folgenden Gefälle zusammenhängend, damit Darstellung und Bewegung nicht bei jedem Messpunkt zwischen Fahren und Stapfen wechseln. Tempo, Schnee und persönlicher Stil werden beim Fahrtbeginn berücksichtigt und als normierte Zeit-/Distanz-/Moduswerte gespeichert. Die Modellmasse kürzt sich; eine Biomechanik- oder Kollisionssimulation ist das nicht.

Format 9 ergänzt die persönlichen Profile und `legacy_foot`. Bei älteren laufenden Resorts bleiben die bisherigen Korridore bis zum vollständigen Tagesabschluss verfügbar, um bestehende Gäste nicht umzuplatzieren. Das nächste leere Resortnetz verwendet die neuen Verbindungen. Die bestehenden Gefälleklassen behalten ihre Grenzwerte, damit alte Pisten beim Laden ihre gültige Einstufung behalten.

## Bestätigte Pistenanschlüsse und gemeinsame Schneeflächen

`PisteLinks` indiziert Mittellinien in räumlichen Zellen. Die Vorschau kann auf ganze Segmente projizieren und prüft Erreichbarkeit ohne Änderungen an Nachbarn. Beim Bestätigen werden gemeinsame kollineare Knoten eingefügt; das bestehende Schneeprofil, der physische Verlauf und die ursprünglichen Baukosten bleiben erhalten. Reine Flächenüberlappung erzeugt keine Abkürzung. Gemeinsame verschobene Punkte werden samt Nachbarn vor der Zahlung geprüft.

Die Schneeflächen erhalten eine feste, disjunkte Flächenzuordnung. Innere Anschlussränder verlieren ihre Randwülste und lokale Verformung weich zugunsten einer gemeinsamen Höhe. Der GPU-Shader und die CPU-Dreiecksauswahl verwenden dieselben Gewichte. Gröbere importierte Raster erhalten feinere gemeinsame Randpunkte. Längenprofile werden einmal pro Korridor vorbereitet; Möbel- und Schilderabstände verwenden denselben Segmentindex.

Der Bildschirmbereich für die Oberfläche kann auf Handys um einen sicheren Rand versetzt sein. Kamera-Projektion und Eingabe bleiben in Viewport-Koordinaten; `PlanOverlay` wandelt beim Zeichnen in seine lokalen Koordinaten um. Jeder sichtbare Planungspunkt bleibt auswählbar. Die Bauvorschau unterteilt ihre Dreiecke an Schneekanten und hält gemeinsame Stützpunkte über der sichtbaren Fläche.

Auf Android speichert Godot 4.5.2 die letzte Bewegungsposition im nativen Eingabeteil und gibt sie beim Loslassen wieder aus. Der mit SHA-256 gepinnte Java-Dispatcher reicht die tatsächlichen Koordinaten von `ACTION_UP` beziehungsweise `ACTION_POINTER_UP` deshalb vor dem Freigeben als letzten Bewegungsschritt weiter. Gestenerkennung und Abbruchpfad werden dabei nicht erneut ausgeführt. Die App übernimmt anschließend die Loslassposition; Desktop-Maus und Touch werden zusätzlich mit fehlender letzter Bewegungsmeldung geprüft. Native Bibliotheken und andere AAR-Ressourcen bleiben unverändert. Quellen und begrenzter Patch stehen in `tools/android/README.md`.
