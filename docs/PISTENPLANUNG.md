# Pisten planen und verbinden

## Erst planen, dann bauen

1. **Pisten → Abfahrt planen** öffnen.
2. Oben am Berg anfangen und weitere Wegpunkte bergab setzen.
3. Einen nummerierten Punkt mit Finger oder Maus ziehen, um den Verlauf zu ändern. Antippen wählt ihn für **Punkt löschen** aus. Am Computer funktioniert auch **Entf**.
4. Höhenprofil, Gefälle, Farbe und Preis prüfen. Bergauf führende oder zu steile Pläne lassen sich nicht bestätigen.
5. Mit **Bauen** die Strecke und ihre Beschilderung anlegen.

Ziehen auf freier Karte bewegt weiterhin die Kamera. Zwei Finger bewegen und zoomen. Ein abgebrochener Touch-Drag setzt den gerade verschobenen Punkt zurück. **Zurück** entfernt den letzten Punkt; **Plan verwerfen** entfernt die ganze unbestätigte Planung. Vor dem Bestätigen wird kein Geld ausgegeben.

## Von der Serpentine zur Abkürzung

Kleine Kreise markieren die Wegpunkte vorhandener Pisten und die Liftstationen. Setze einen neuen Startpunkt dort; innerhalb von 18 m rastet er genau am Anschluss ein. Ende an einem weiter unten gelegenen Wegpunkt. Auch innere Wegpunkte einer langen Piste können so Abzweigungen werden.

Ein Anfänger kann die gesamte blaue Route fahren. Ein geübter Gast kann die blaue Anfahrt, eine rote Verbindung und anschließend die blaue Ausfahrt nutzen. Ein Profi bekommt zusätzlich schwarze Alternativen. Innerhalb ihres Könnens wählen die Gäste unterschiedliche passende Rundwege.

Die Simulation behandelt diese Anfahrten und Ausfahrten als tatsächliche Teilstücke. Die Gäste starten beim Wiedereinfädeln am Anschluss und ihre Spuren verändern nur den gefahrenen Schnee. Teilrouten und laufende Gäste werden gespeichert. Das Schließen einer Verbindung entfernt diese Alternative aus neuen Routen.

An inneren Wegpunkten müssen die Routen tatsächlich zusammentreffen; die Verbindungstoleranz beträgt 2 m. Die größere Fußweg-Toleranz von 42 m gilt weiterhin zwischen Stationen und Pistenenden. Im Tal sind dort Fußwege bis 220 m möglich. Benachbarte Kehren werden dadurch nicht zu unsichtbaren Fußweg-Abkürzungen. Reine Kreuzungen zwischen zwei Wegpunkten bilden keinen zusätzlichen Anschluss.

## Die Route bestimmt die Farbe

Das Spiel tastet den gesamten Verlauf in höchstens 3 m langen Schritten ab. Es teilt den Höhenverlust jedes Schritts durch dessen horizontale Länge. Das größte Längsgefälle bestimmt die Klasse; die mittlere Neigung dient als zusätzliche Information im Profil.

| Spielklasse | Maximales Längsgefälle | Baukosten |
|---|---:|---:|
| Blau | 30 % | 32 €/m |
| Rot | 55 % | 44 €/m |
| Schwarz | 110 % | 58 €/m |

Längere Querungen können die Route an einem steilen Hang deutlich milder machen. Ein einzelnes steiles Stück verschwindet dagegen nicht durch ein langes flaches Ende. Die Vorschau färbt die Teilstrecken entsprechend ein und zeigt Pfeile in Fahrtrichtung. Der Preis folgt der automatisch ermittelten Klasse und der räumlichen Streckenlänge.

Diese Spielgrenzen bleiben für vorhandene Gebiete und Spielstände erhalten. Sie bilden keine vollständige reale Pistenbewertung ab: beispielsweise nennt Tirol für Blau 25 % und Rot 40 % und berücksichtigt auch Quergefälle. SkiZones verwendet für die Klasse das Längsgefälle der geplanten Mittellinie und verändert das darunterliegende Berggelände nicht durch einen baulichen Geländeausgleich.

## Kamera und Höhen lesen

**Kamera** öffnet vier Ansichten: Resort, Panorama, Bauansicht und eine senkrechte orthografische Draufsicht. Der Blickwinkel der schrägen Ansichten lässt sich von 20° bis 80° einstellen. Im Kameramenü kannst du auch drehen oder ins Tal zurückkehren. **C** wechselt die Ansicht, **Q/E** dreht; die laufende Bauplanung bleibt dabei erhalten.

**Gelände** zeigt die stärkste örtliche Hangneigung als Fläche, Höhenlinien alle 20 m und Höhenbeschriftungen alle 100 m. Die hellen Pfeile weisen bergab. Die Farbe der Fläche beschreibt den Berg; die Farbe der Piste beschreibt den tatsächlichen Verlauf. Das Höhenprofil im Baukatalog zeigt Start und Ziel, Länge, Höhenverlust, Durchschnitt und Maximum.

## Runde nummerierte Markierungen

Jede Piste erhält eine eigene Nummer, unabhängig von den Kennungen der Lifte und Gebäude. Runde Schilder tragen diese Nummer auf beiden Seiten, mit weißem Rand und blauer, roter oder schwarzer Fläche. Sie stehen an den Wegpunkten, an beiden Enden und zusätzlich ungefähr alle 60 m am Rand. Bestehende Pisten behalten ihre Nummer beim Abbau anderer Strecken und beim Speichern.

Die Gestaltung orientiert sich an [Sitour Österreich: Pistenmarkierungen](https://www.sitour.at/de/produkt/pistenmarkierungen-1) und [Sitour Deutschland: Pistenmarkierung mit Beispiel Spitzingsee](https://www.sitour.de/de/produkt/pistenmarkierung-1). Reale Gefälleklassen beschreibt [Tirol: Verhaltensregeln beim Skifahren](https://www.tirol.at/reiseservice/how-to-tirol/verhaltensregeln-skifahren).

## Vorhandene Spielstände

Formate 1 bis 3 bleiben lesbar. Beim Laden werden alte manuell gewählte Farben anhand des tatsächlichen Verlaufs neu bestimmt und die Pisten in ihrer bisherigen Reihenfolge nummeriert. Die bezahlten Kosten, Geld, Anlagen, Forschung und Schneezustände bleiben erhalten. Das neue Format 4 speichert Nummern sowie ganze und teilweise laufende Gästerouten; unbekannte oder beschädigte Teilstücke werden beim Laden abgelehnt.
