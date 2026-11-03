# SkiZones 0.26 Draft – Cinematic Resort, Szenarien, Medaillen und Alpen-ExtraBlatt

**Vorbereitung, nicht freigegeben.** Abhängigkeiten: 0.23 (PR #18), 0.24 (PR #19), 0.25 (PR #22). Diese vorherigen PRs sind noch nicht gemergt. Alte Spielstände sind unverändert zu erhalten.

## Schwerpunkt: Szenarien als freiwilliger Nebenmodus

- Die vier realen Berggebiete Braunlage, Filzmoos, Kitzbühel und Seiser Alm werden **unter** dem Hauptspiel in einem eigenen unteren Hauptmenüblock angeboten. Die acht Fantasiegebiete und die Karriere behalten Vorrang.
- Die vorhandenen, zuvor absichtlich ausgeblendeten Szenariodaten, OSM-IDs, Original-Pistenabschnitte, Liftstationen, Geohöhenraster, Hotels, Skischulen, Straßen-/ÖPNV-Overlay, Betriebsaufgaben und Speicherpfade werden wieder zugänglich.
- Auf jeder Szenariokarte gibt es **Entspannt**, **Normal** und **Experte**, zunächst als unterschiedliche Nachfrage-/Gruppenintensität. Die ursprünglichen Missionsziele bleiben sichtbar; ältere Saves ohne Feld entsprechen Normal.
- Die Karten zeigen die aktuell als befahrbar markierte Zahl importierter OSM-Pistenabschnitte. Das beweist **nicht**, dass jede in der Realität existierende Piste enthalten und erreichbar ist.
- Vor einem echten Release sind **für jedes Gebiet** zu bestätigen: aktive Routen aller Könnensstufen, vollständige Anschlüsse und sichere Rückwege, reale Pisten- und Liftgeometrie, potenzielle Lücken/Teilstücke, Queue-/Engpasssimulation, Absturzfreiheit, Save-/Resume nach 24h-Betrieb, Android-Lifecycle.
- Szenariomedaillen pro fertiggestelltem Gebiet: Bronze/Entspannt, Silber/Normal, Gold/Experte. Höhere Grade ersetzen niedrigere, ohne einen alten Erfolg zu verlieren. Archiv unabhängig vom Karriereslot.

## Präsentation und Kamerafahrt

- Im Kamera-Menü: **Cinematic Resort Tour**, ein separat abschaltbarer Auto-Flug durch Tal- und Bergstationen, Pisten und ausgewählte Dorfgebäude.
- Fließende interpolierte 3D-Orientierung, weicher horizontaler Schwenk, wechselnder Zoom und Fokus auf tatsächlichen Resort-POIs statt frei erfundenen Koordinaten.
- Während der Vorführung ist die große Werkzeug- und Statistikoberfläche ausgeblendet, einzig POI-/Tag-Label und ein Touch-Button **Zurück** bleiben. Vorheriger Kamerazustand wird beim Ende wiederhergestellt.
- **Nicht filmreif fertig:** noch keine individuell inszenierten Kameraspuren entlang von Liftseilen, keine Kamerafahrt durch echten Gebäuderaum, keine Kamera-Kollisionsprüfung an dichten Gebäuden. Künftige Version soll diese Verbesserungen priorisieren.

## Jahresmedaillen (global erhalten)

- Weihnachtsmedaille **pro Kalenderjahr**, wenn mindestens ein Adventstürchen geöffnet wurde.
- Silvestermedaille **pro Jahreswechsel**, wenn die Jahresfeier gestartet wurde.
- Medaillen werden aus dem bestehenden separaten `skizones_annual_festival.cfg` abgeleitet. Ein erneutes Laden eines alten Karriere-Spielstands löscht diese Einträge nicht.
- Separate Szenariomedaillen im `skizones_scenario_medals.cfg`, mit atomaren Schreibvorgängen und Steigerung statt Duplikaten.
- Medaillenschrank als eigenes Spielemenü mit Jahreszahlen und Unterscheidung der Events.

## Dorfpresse – Alpen-ExtraBlatt

- Die **Druckerei & Redaktion** ist ein errichtbarer eigener Ort.
- Erst nach dem Bau werden **Zeitungsstände** verfügbar; sie müssen in den normalen Betrieb mit Personal, Besucherinteraktionen und Einnahmen eingebunden bleiben.
- In der Druckerei ist das ExtraBlatt mit den tatsächlich **letzten fünf** im aktuellen Spielstand freigeschalteten Achievement-IDs sichtbar, wobei die Artikel keine nicht aufgezeichneten historischen Daten behaupten.
- Die Zeitungsverkaufs-Statistik wird aus den realen `visits` und `revenue` der Zeitungskioske summiert – keine erfundenen Auflagen. Die Redaktion hat eigene kleine Druckerei-Aktivitäten.
- Langfristig: Presse als eigenes Redaktions-Minispiel mit Layout, Druckauflage, Papierbedarf, Redaktion und optisch hochwertiger Zeitung pro Grafik-Theme.

## Bildwelt, Mobilgeräte und Sound

- Die **fünf Style-Themes** sind bindend für UI, Textkontur, Material, Gebäudeformen, FX, Szenario-Karten und spätere Hotelinnenräume. Der Alpin-Hauptstil wird nicht unnötig verändert. Lesbarkeit und Touch-Ziele vor dekorativen Verzerrungen.
- Ausgewählte Berg- und Stadtansichten dürfen als Fotoszenen/Filmfahrten innerhalb des Spiels ablaufen; noch keine Behauptung von fotorealistischen Rendern.
- **Audio-Roadmap:** selbst komponierte, lange, nahtlose Piano-/Ambient-Themen pro Radioquelle, dezente Hallräume, sich entwickelnde Mehrlagen-Arrangements statt kurzer Repeats; weiche Crossfades, Stille/Fauna in entlegenen Höhen, ortsabhängiger Sound. Deutlich getrennt davon zukünftige **3D-Sprachkulissen** von NPCs. Radiosender, Stummschaltung und Lautstärke müssen erreichbar und persistent sein.
- Kein urheberrechtlich geschütztes Songmaterial in den Builds. Ohne implementierte Sounddateien und Hörtest werden keine Songs als produziert oder live im Spiel bezeichnet.

## Hard Gates

1. Alle Testskripte Godot 4.5.2 fehlerfrei importierbar, inklusive Feiertags-UI von 0.25.
2. Szenario-Regressionen für alle vier Gebiete, lokale Datenspeicherung und auf alten Saves fehlende Schwierigkeit.
3. Filmkamera überschreibt keine Spielstände und stört keine Touch-Gesten, Grafikthemen oder Android-Rückwärtsnavigation.
4. Zeitungsredaktion verändert alte Achievements nicht; Jahresmedaillen sind unabhängig von Career-Reset und Updates.
5. Visuelle Tests und längere Android-Lifecycle-Tests samt signierter APK vor Release.

