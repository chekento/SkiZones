# SkiZones Radio 0.29 — Hotel-, Ska- und Atmospherics-Iteration

Stand: 2026-11-04. Projektzweig: `feature/029-hotel-ska-atmospherics-responsive`.

## Programmlogik

- **Hotel Lobby FM**: exklusiv an `BuildingExperience.open()` für Hotel-/Unterkunftstypen gebunden. Ein 16-Titel-CC0-Programmkatalog; beim Verlassen wird der vorherige Radiozustand wiederhergestellt. Stummschaltung und Spielereinstellungen bleiben autoritativ. Klangziel: sanfte Pianomusik, Lounge-Jazz, entspannte Hotellobby-Atmosphäre.
- **Deep Atmospherics**: 15 eigens für atmosphärische Stimmung ausgewählte CC0-Katalogpositionen, ohne neue unlizenzierte Audiofiles. Angestrebte Dauer **mindestens 3:00, bevorzugt 5:00–7:00 Minuten je Song**. Die tatsächlichen Laufzeiten und die Hörprüfung sind noch nicht endgültig bestätigt; deshalb steht die technische Laufzeitinventur in `tests/radio_duration_inventory_029.gd` zur Verfügung. Erst nach Prüfung dürfen die Titel als lange Songs ausgeliefert und beworben werden.
- **Mountain Sunrise**: zwölf bergnahe ruhige Titel, Quelle durchweg vorhandene dokumentierte CC0-Dateien.
- **Lodge Lo-Fi**: zwölf warme, entspannte Lo-Fi-Tracks für Kamin- und Après-Ruhepausen.
- **KoSch Milton — Ska'radise Lost**: separater Künstlerkanal für das vom Rechteinhaber genannte Album, nur mit bewusster externen SoundCloud-Aktion. Originalalbum: https://soundcloud.com/koljawschumann/sets/kosch-milton-skaradise-lost. Playlist-ID `1796940615`; HTML-Beispiel `docs/embed/skaradise_lost.html`. Keine CC0-Kennzeichnung und kein Audio-Bundle ohne Masters.

## Lizenz- und Längeprüfung

Der tatsächliche Dateibestand enthält zunächst weiter 72 einzigartige CC0-Audioaufnahmen. Senderprogramme dürfen bereits geprüfte Aufnahmen mehrfach verwenden; das erhöht die Programmplätze, nicht den Umfang der einzigartigen Songs. Für echte lange Musikwerke sind zusätzliche Aufnahmen erforderlich, deren Quelle, Lizenz, Artist, Laufzeit und komprimierte Ogg-Datei geprüft und mit Prüfsumme archiviert werden müssen.

Offene Kandidaten für spätere Prüfung: [Jazz (Spring Spring, CC0, ausdrücklich kurz)](https://opengameart.org/content/jazz-1), [Look Up (Alex McCulloch / Pro Sensory, CC0)](https://opengameart.org/content/look-up) und [Barriers (Zane Little Music, CC0)](https://opengameart.org/content/barriers). Die Aufnahme in diese Recherche bedeutet **nicht**, dass der Song schon Bestandteil des Builds ist oder die 3-Minuten-Hürde erfüllt.

## Tests

- `tests/radio_duration_inventory_029.gd` – misst Sekunden anhand tatsächlich importierter Godot-Audiostreams und zählt ≥180/≥300 Sekunden je Sender.
- `tests/radio_context_029.gd` – Kontext-Radio, Datenschutz-Opt-in, 15 Audio-Katalogpositionen sowie responsive Achievement-Anzeige.
- Regressionsprüfungen des vorhandenen Audio- und Hotelbetriebs bleiben aktiviert.
