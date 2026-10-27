# Spielsysteme und Architektur

## Spielidee

SkiZones verbindet die Gestaltung eines eigenen Berggebiets mit einer lesbaren Betriebssimulation. Eine neue Anlage soll eine Entscheidung ermöglichen: Welchen Hang erschließt sie, welche Gäste können ihn fahren, wo entstehen Engpässe und trägt sich der Ausbau wirtschaftlich?

Der Kernkreislauf lautet: Gelände lesen, einen Rundweg planen, Betrieb eröffnen, Besucherströme und Ergebnis beobachten, gezielt ausbauen.

## Verantwortlichkeiten

| Datei | Aufgabe |
|---|---|
| `src/core/terrain.gd` | Einheitliche Höhe, Baugrenzen, vollständige Pistenprofilprüfung, Streckenabtastung |
| `src/core/catalog.gd` | Kosten und Kennzahlen von Liften, Gebäuden und Wetter |
| `src/core/resort.gd` | Geld, Zeit, Netz, Gäste, Warteschlangen, Schnee, Tagesabschluss, Fortschritt |
| `src/core/progression.gd` | Karriere, Sterne, Forschung, Aufträge, Ausbau, Jahreszeiten und Finanzhistorie |
| `src/core/save_store.gd` | Spielstand-Hülle, Prüfsumme, atomarer Austausch, Sicherung und Wiederherstellung |
| `src/world/resort_view.gd` | 3D-Darstellung, Gelände, Baum- und Gästeinstanzen, Bauvorschau, Kamera und Geländeauswahl |
| `src/world/alpine_art.gd` | Gebündelte eigene Modelle für Chalets, Liftstationen, Fahrzeuge, Tannen, Felsen und Skifahrer |
| `src/ui/hud.gd` | Menü, Bauwerkzeuge, Anlageninspektor, Preisanpassung, Berichte und Hilfe |
| `src/ui/management.gd` | Pausierendes Resort-Büro mit fünf handlungsfähigen Verwaltungsseiten |
| `src/ui/finance_chart.gd` | Finanzdiagramm aus den letzten 28 tatsächlichen Tagesergebnissen |
| `src/main.gd` | Verbindet Simulation, Darstellung, Eingaben und App-Lebenszyklus |

Die Simulation kann ohne Fenster, Grafikkarte oder Android-Gerät getestet werden. Die Grafik nutzt dieselbe Höhenfunktion wie die Bauprüfung. Die Karte misst 720 × 740 horizontale Spielmeter; die Landschaft ist zunächst fest vorgegeben.

## Pisten und Lifte

Pisten bestehen aus zwei bis 64 Wegpunkten. Jeder Abschnitt wird mindestens alle drei Meter auf Gefälle und Gegenanstieg geprüft. Die Farbe begrenzt das maximale lokale Gefälle. Mindestens 40 m Länge und 7 m Höhenverlust sind notwendig.

Lifte verlaufen von der Tal- zur Bergstation. Die Seillinie wird über die gesamte Trasse auf Geländedurchdringung geprüft. Kosten und Fahrzeit hängen von der Länge ab. Windgrenzen unterscheiden die Liftarten.

Das Wegenetz besteht aus dem Talzugang, Liftstationen sowie Pistenanfängen und -enden. Fußwege verbinden nahe Knoten; Lifte sind bergauf, Pisten bergab gerichtet. Die Simulation sucht vollständige, für das Können geeignete Runden zurück zum Talzugang. Unerschlossene Abfahrten können bereits gebaut werden, bringen aber noch keine zahlenden Gäste.

## Gäste und Betrieb

Eine Simulationsminute ist ein fester Schritt, unabhängig von der Bildrate. Bei 1× laufen zwei Spielminuten je realer Sekunde; 4× beschleunigt denselben Ablauf.

Gäste besitzen Können, Aufenthaltsdauer, Alter, eine konkrete Reiseroute, Wegabschnitt, Wartezeit und Ausgabenstatus. Die Zustände sind Unterwegs, Warteschlange und Verlassen. Ein Ticket wird beim Einlass genau einmal bezahlt. Gebäudeerlöse werden in dieser Version einmal pro Gast nach dessen erster abgeschlossener Runde angerechnet.

Jeder Lift verwaltet ein gemeinsames Beförderungsbudget. Mehrere Pisten oder Könnensstufen vervielfachen seine Kapazität nicht. Gäste werden in Einlassreihenfolge abgefertigt. Lange Wartezeiten senken die Zufriedenheit.

Der Tagesabschluss berechnet Betriebskosten einmalig, schließt Gästebesuche ab und hält die Uhr bei 18:00 an. Erst „Nächsten Tag starten“ setzt auf 08:00 zurück, präpariert Pisten und bestimmt das neue Wetter. Die vier Meilensteine zahlen ihre Prämien jeweils einmal aus.

## Karriere und Winter

Karrieren beginnen mit sechs Forschungspunkten. Die neun Projekte verbrauchen Geld und Punkte beim Start; Voraussetzungen und eine Laufzeit von ein bis drei Betriebstagen bestimmen die Reihenfolge. Fertigstellung und Freischaltung erfolgen erst am passenden Morgen. Pro 1.000 Erfahrung gibt es zwei Forschungspunkte; Betriebstage, Aufträge und Sterne liefern weitere.

Die fünf Sterne verbinden Erfahrung mit nutzbarer Infrastruktur. Ein unerschlossener Hang zählt nicht zum Netzziel. Bis zu drei Aufträge können laufen; zwei neue pro Tag stammen aus drei deterministisch wechselnden Angeboten. Zählziele beginnen bei der Annahme, Infrastrukturziele prüfen den aktuellen Bestand. Erfüllte Aufträge behalten ihre abholbare Prämie; beanspruchte Prämien können nicht erneut ausgezahlt werden.

Anlagen haben drei Stufen. Liftkapazität wächst je Stufe um 25 %, Fahrtempo um 10 %. Gebäude verbessern Komfort und Erlöse; Pisten werden breiter und verschleißen langsamer. Höhere Stufen verursachen mehr Betriebskosten. Im freien Aufbau gelten keine Forschungsbausperren.

Ein Winter umfasst 28 Betriebstage. Eine Saisonprämie belohnt Sterne und abgeschlossene Aufträge. Resort, Forschung und Ausbau bleiben über den Jahreswechsel bestehen. Der Wochenkalender verändert Nachfrage und Können der anreisenden Gäste. Die erforschbare Wettervorschau benutzt dieselbe Funktion wie das nächste tatsächliche Tageswetter.

Die letzten 28 Tagesabschlüsse halten Erlöse, Betriebskosten, Investitionen, Prämien und das Ergebnis nach Investitionen fest. Kreditaufnahme und Tilgung sind keine Betriebserlöse oder Kosten; offene Kredite verursachen die angegebenen täglichen Zinsen.

## Speicherstände

Die JSON-Nutzdaten liegen in einer Hülle mit Formatkennung und SHA-256-Prüfsumme. Vor dem Austausch wird eine temporäre Datei geschrieben und geschlossen. Ein lesbarer vorheriger Stand bleibt als `.bak` erhalten. Beim Laden werden Version, Wertebereiche, Typen, Kennungen, Geometrie und Gästeindizes an einer separaten Simulationsinstanz geprüft.

Der Zufallszustand wird als Zeichenkette gespeichert, damit große Ganzzahlen durch JSON nicht an Genauigkeit verlieren. Aus JSON geladene Meilensteine werden wieder in Integer konvertiert. Ein Regressionstest prüft, dass der weitere Ablauf nach dem Laden gleich bleibt.

Format 2 ergänzt Karriere, Forschungsprojekt, Aufträge, Finanzhistorie und Ausbaustufen. Format 1 aus 0.1.x wird weiter gelesen; bestehende Anlagen beginnen auf Stufe 1 und behalten alle früher verfügbaren Baumöglichkeiten. Ungültige Karrierewerte werden vor dem Austausch der laufenden Simulation abgelehnt.

Ist eine Piste bereits erschöpft und inzwischen für neue Routen geschlossen, kann die Rekonstruktion eines darauf befindlichen Besuchs beim Laden entfallen. Geld, Tageszahlen und Anlagen bleiben erhalten. Für einen späteren produktiven Spielstand sind versionierte vollständige Reiserouten und Migrationsregeln vorgesehen.

## Darstellung und Budget

Gelände und Gebäude sind eigene prozedurale Geometrien. Tannen, Felsen, Skifahrer und Liftfahrzeuge verwenden MultiMesh-Instanzen. Gebäudeteile und Pistenmarkierungen sind je Anlage in einem Mesh gebündelt. Die Perspektivkamera, Licht, Dunst und Schneefall hängen an der tatsächlichen Zeit beziehungsweise dem Wetter. Das Hauptmenü verwendet das freigegebene Panorama, die 3D-Spielwelt bleibt eigene Geometrie. Die Compatibility-Pipeline vermeidet eine Vulkan-Pflicht.

Version 0.2.0 begrenzt aktive Gäste auf 360, Pisten auf 80, Lifte auf 24 und Gebäude auf 60. Das sind Entwicklungsgrenzen, keine zugesicherte Bildrate bei voller Auslastung. Gästeziele werden je Simulationstakt zwischengespeichert und zwischen Bildern interpoliert. Für große Resorts sollen Landschaften aufgeteilt und Darstellungsdetails nach Entfernung reduziert werden.
