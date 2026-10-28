# Performance in SkiZones 0.7.0

Stand: 28.10.2026. Das Update reduziert wiederholte CPU-Arbeit und die Menge entfernter Geometrie. Es garantiert keine feste Bildrate auf beliebiger Hardware.

## Reproduzierbarer CPU-Vergleich

Godot 4.5.1 Standard, Linux x86-64 in derselben Ausführungsumgebung, nacheinander gemessen. Das identische Skript [performance_benchmark.gd](../tools/performance_benchmark.gd) läuft gegen den unveränderten 0.6-Stand `f235a57e5e4fbc18083c312bc07a069c5954fc79` und gegen den 0.7-Quellcode. Es verwendet drei tatsächliche Sonnenhang-Pisten mit verbundenen Abschnitten, erzeugte Skifahrer sowie für den großen Fall zusätzlich kopierte Liftdefinitionen. Diese zusätzlichen Lifte bilden eine künstliche Lastanordnung; sie wurden nicht durch einen Spieler regulär gebaut.

Je Fall und Spieltempo werden nach 24 Aufwärmbildern 120 Darstellungsaktualisierungen gemessen. Die Gäste bewegen sich auf echten Skiabschnitten, die Liftuhren und Zwischenzeiten laufen weiter; bestehende Spuren werden berücksichtigt. Gemessen wird ausschließlich die CPU-Dauer des Darstellungsupdates. Der anschließende GPU-Renderdurchlauf, die gesamte Spielsimulation, Eingabeverarbeitung und Android-Hardware sind **nicht** Bestandteil dieser Bildzeitmessung. Die gezählten Gäste und Lifte bleiben in beiden Versionen vollständig erhalten.

| Gäste / Lifte | Tempo | 0.6: Median / P95 / Maximum in ms | 0.7: Median / P95 / Maximum in ms |
|---|---|---|---|
| 80 / 1 | 1× | 11.87 / 14.96 / 1073.80 | 1.28 / 1.84 / 16.80 |
| 80 / 1 | 4× | 12.34 / 14.44 / 22.82 | 2.37 / 2.98 / 6.67 |
| 360 / 24 | 1× | 74.84 / 86.37 / 91.09 | 9.36 / 11.14 / 12.53 |
| 360 / 24 | 4× | 73.38 / 84.05 / 114.34 | 15.92 / 22.94 / 39.54 |

P95 bedeutet: 95 Prozent der gemessenen Updates waren höchstens so lang. Insbesondere der frühere gelegentliche Spuren-Neubau kann ein Bild um mehr als eine Sekunde blockieren. Der kleine Fall erfasst einen solchen Ausreißer; ein begrenztes Messfenster muss ihn nicht in jedem Fall treffen. Auch 0.7 zeigt unter hoher Last einzelne längere Updates, insbesondere bei 4×.

| Weitere Arbeit bei 360 Gästen / 24 Liften | 0.6 | 0.7 |
|---|---|---|
| Einmaliger Szenen-Neubau | 11032.51 ms | 1621.41 ms |
| Expliziter Aufbau der sichtbaren historischen Spuren | 1338.55 ms | 64.73 ms |
| Aktualisierung unveränderter Schneeflächen | 55.595 ms | 0.063 ms |

Der explizite Spuren-Aufbau ist ein absichtlich blockierender Diagnoseaufruf. Die laufende Darstellung berechnet pro automatischem Durchlauf höchstens 48 neue Fahrpunkte. Der historische Darstellungsrahmen beträgt in 0.6 bis zu 4.000 Abschnitte, in der ausgewogenen 0.7-Darstellung bis zu 1.200; **Detailreich** erlaubt 2.000. Die Spurwerte vergleichen daher den jeweiligen Darstellungsrahmen, keine identische Zahl gezeichneter Linien. Gefahrene Strecken, lokale Schneeänderungen und Besucherzahlen werden dadurch nicht verkürzt.

Rohdaten: [0.6 vor dem Umbau](benchmarks/0.7.0-before.json) · [0.7 nach dem Umbau](benchmarks/0.7.0-after.json).

Reproduktion aus dem jeweiligen Projektverzeichnis:

```sh
godot --headless --script /pfad/zum/0.7-Quellcode/tools/performance_benchmark.gd -- --benchmark-json=/tmp/skizones-performance.json
```

Der CPU-Test ist Teil von GitHub Actions. Zeitwerte werden protokolliert und wegen schwankender Runner-Leistung nicht als pauschale FPS-Zusage behandelt.

## Was sich technisch geändert hat

- Schneeflächen werden einmal aus ihrem abgerundeten Umriss erzeugt. Verkehr aktualisiert eine kleine R8-Höhentextur mit maximal ungefähr 1,9 mm Quantisierungsfehler. Pisten und Spuren verwenden dieselben Höhenwerte.
- Persönliche Fahrproben werden zeitlich versetzt vorbereitet und in jedem Bild stetig interpoliert. Ein beobachteter Gast verwendet die exakte Fahrlinie und den Schneekontakt.
- Anlagenzugriffe, persönliche Fahrstile, Liftfahrpläne, Belegungszahlen, Anstellpositionen und Hindernisgrenzen werden wiederverwendet.
- Fahrzeuge sind je Lift exakt dimensioniert. Entfernte Flotten sparen Darstellungsarbeit; die physische Fahrzeug-/Sitzzuordnung und Betriebsuhr laufen weiter.
- Waldstücke sind getrennte Instanzgruppen mit einfacheren Fernmodellen. Bestehende detaillierte Tannen bleiben in der Nähe verfügbar. Wiederverwendete Modelle und einmal berechnete Platz-Eckpunkte beschleunigen auch den Szenenaufbau.
- Automatische Grafik berücksichtigt das gewählte 30/60-Bilder-Ziel und passt Auflösung beziehungsweise entfernte Details an. Manuell sind drei feste Stufen verfügbar. Wetterpartikel und sanfte Verfolgung sind schaltbar.
- Bauvorschau, Katalog, Minikarte und Planungshilfen vermeiden unnötig wiederholte Arbeit. Viele Pointer-Bewegungen desselben Bildes werden zu einer Vorschau zusammengefasst.

## Was zusätzlich geprüft wurde und was offenbleibt

Die Szenentests verwenden echte OpenGL-Compatibility-Ausgabe über Mesa/llvmpipe und prüfen tatsächliche Fahrzeug-/Gasttransformationen, kontinuierliche Bewegung, GPU-Höhendaten, wiederverwendete Schneeflächen, das feste Spur-Arbeitsbudget, Sichtbarkeitswechsel und Grafikoptionen. Die Abbildungen im Repository stammen aus dieser tatsächlichen Ausgabe. Ein Dummy-Renderer ersetzt diese Tests nicht.

Eine Messung auf einem physischen Android-Gerät steht noch aus. Die Softwaregrafik der Testumgebung ist kein Ersatz für einen Smartphone-GPU-Test. Größere Umbauten erzeugen die Szene einmalig neu; dieser Aufbau ist nicht Teil der fortlaufenden Bildbewegung. Die vorhandenen Entwicklungsgrenzen bleiben bei 360 aktiven Gästen, 24 Liften, 80 Pisten und 60 Gebäuden.
