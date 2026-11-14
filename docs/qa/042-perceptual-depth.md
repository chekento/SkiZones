# PMDD 4.0 – räumliche Staffelung und Eigenbewegung

Implementierungskandidat für 0.42. Die bestehende perspektivische Kamera bleibt die gemeinsame Grundlage für Darstellung, Auswahl und Bauen. Kameraschwenks, Verschieben, Zoomen und das Mitfahren bei einem Gast verändern die Perspektive tatsächlich. Eine subjektive Bewegungsillusion wird dadurch unterstützt, aber weder garantiert noch als echtes Stereo beschrieben.

## Tiefenaufbau

| Bereich | Verankerung und Wahrnehmung |
| --- | --- |
| Naher Schnee | Weltfeste gerichtete Mikrostrukturen; ihre Facetten reagieren dezent auf den Blickwinkel. |
| Vordergrund | Bestehende große Bäume, Felsen und bauliche Details geben nahe Verdeckungs- und Größenhinweise. |
| Aktive Motive | Bestehende Gäste und Liftfahrzeuge bewegen sich relativ zur festen Umgebung. |
| Resort | Gebäude, Wege und Pisten bleiben geometrisch stabile Referenzen. |
| Wald und Hänge | Bestehende Größen-, Kontrast- und Detailstaffelung trennt den Mittelgrund. |
| Lokale Atmosphäre | Drei neue, ortsfeste Dunstschichten bei 10, 38 und 105 Metern über ihrem jeweiligen Geländepunkt. |
| Bergkulisse | Bestehende ferne Grate, Himmel und distanzabhängiger Nebel bilden den ruhigen Hintergrund. |

Die Dunstvolumen folgen niemals der Kamera. Lokale Strukturen enthalten keinen zeitgesteuerten Versatz. Berge und Architektur erhalten keine Scheinbewegung. Die neue Schneeschattierung bleibt ebenfalls an Weltkoordinaten gebunden: Kamerabewegung verändert lediglich die Sicht auf ihre gerichteten Facetten. Die Änderung des lokalen Schneekontrasts ist auf etwa ±4,4 % begrenzt und wird vor subpixeliger Darstellung weich ausgeblendet. Keine Bildschirmverzerrung, künstliche Kamerawackler, zusätzliche Unschärfe oder blinkende Kontrastmuster.

## Bedienung und Budget

- Drei MultiMesh-Knoten mit insgesamt höchstens 24 einfachen Dunstkörpern; auf mittlerer Qualität zwölf, im Sparmodus null.
- Wetter und Tageslicht bestimmen Dichte und Farbe. Beim Stillstand der Kamera bleiben die neuen Strukturen zeitlich ruhig.
- Effekte aus deaktiviert Dunst und Schneefacetten. Monochrom und Pistenatlas behalten ihre klare Darstellung.
- In Bauansicht, Draufsicht und mit aktivem Hangplan werden die Dunstschichten ausgeblendet.
- Keine zusätzlichen Partikelemitter oder Kollisionsobjekte. Die bestehende Simulation, Spielstände und Auswahlstrahlen bleiben unverändert.

## Abnahme

44 lokale Modell-/Integrationsprüfungen bestanden unter dem gepinnten Godot 4.5.2: Geländeanker, unveränderte Auswahlstrahlen, Determinismus, feste Instanzbudgets und klare Planungsmodi. Die separate Renderer-Prüfung kontrolliert GPU-Transformationen, stationäre Bildstabilität, echte Tiefenparallaxe, Geländeverdeckung sowie die beiden tatsächlich ausgelieferten Schneeshader. Sie erzeugt Vergleichsaufnahmen einer kontrollierten Szene mit echten Spiel-Assets; diese ist kein vollständiges Resort und kein Android-FPS-Nachweis.

Renderer-Abnahme und Android-Abnahme dieses Kandidaten stehen zunächst aus. Eine reale Samsung-Abnahme und eine Wahrnehmungsprüfung auf dem Zielbildschirm bleiben erforderlich, bevor die Stärke der Wirkung bewertet werden kann.
