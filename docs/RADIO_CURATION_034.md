# SkiZones Alpine Radio 0.34 – Offline-Sender mit eigenem Soundprofil

**Stand: 4. November 2026 · Entwicklungszweig** `feature/034-radio-genre-offline-cc0`. Diese Datei beschreibt geplante, bereits im Zweig eingecheckte Änderungen. **Noch nicht als APK veröffentlicht.** Letzter bestätigter öffentlicher Build bleibt v0.33.0, bis vollständige Godot-/Android-30/36-CI, Hörprobe und Signatur-/Update-Prüfung bestanden sind.

## Senderliste und Genre-Auswahl

| Sender | Programmidentität | Titel |
| --- | --- | ---: |
| AlpenWelle FM | Bergfolk, Hüttengitarren, akustische Melodien; keine fälschlich behaupteten traditionellen Aufnahmen | 15 |
| HüttenFolk | gemütliche akustische Hüttenstimmung, Gitarren | 12 |
| Nordic Frost | kühle, akustisch-ruhige Winterstimmung statt ungeprüfter traditioneller schwedischer Volksmusik | 10 |
| Summit Sunrise | warme Gitarren, Piano und langsam erwachender Berg | 15 |
| Freeride Pulse | boardtaugliche Synthwave-/Dance-Beats, keine zufällige ruhige Gitarrenmusik | 14 |
| PistenRock | Gitarren-Rock, Breakbeats und Punk-nahes Tempo; **keine Behauptung eines durchgehend echten Punkrepertoires** | 15 |
| Powder Flow | instrumentaler Hip-Hop und Lo-Fi, keine Techno-/Chiptune-Dauerrotation | 10 |
| SnowBeat Radio | Techno, House, elektronische Gipfelparty | 18 |
| Alpenglühen FM | Après-Ski, House, Funk, Disco-Feeling für Erwachsene | 10 |
| Alpine Classic | Piano, orchestrale Instrumentalstücke | 16 |
| Mountain Chill | ruhiges Ambient und meditative Klangflächen | 16 |
| Lodge Lo-Fi | weiche Beats für Hotel, Kamin und Abendpause | 15 |
| Glacier Dreams | eisig, weit, träumerisch, mit wenigen treibenden Beats | 12 |
| Cosmic Drift | Space-Ambient und Synthwave für Bergnächte | 16 |
| Deep Atmospherics | Drones und langsam entwickelte Soundscapes | 15 |
| Hotel Lobby FM | **nur Hotel-/Unterkunftskontext**, Piano und Jazz-Lounge | 20 |

`off` ist ein eigener, sofort stummschaltender Wert und **kein Sender**. Tatsächlich: **15 frei wählbare Offline-Programme plus ein automatisch kontextabhängiges Hotelradio**.

## SoundCloud-Entfernung und Kompatibilität

Die zwei früher auswählbaren, aber nicht im Spiel abspielbaren KoSch-SoundCloud-Playlists **ERG0SPHERE Journey** und **Ska’r adise Lost** werden aus Senderliste, Browserlink-Buttons, externen Embed-/Hinweisdateien und aktueller Offline-Bibliothek entfernt. **Es werden keine SoundCloud-Masters kopiert oder ohne separat verfügbare Audio-Masters eingebunden**. Historische Git-Tags bleiben unverändert. Nur die Audioeinstellung wird kompatibel umgestellt: `erg0sphere → space`, `ska_album → apres`; alle Karriere-/Resort-Saves und sämtliche Lautstärkewerte bleiben bestehen.

## Elf neue tatsächlich importierte CC0-Stücke

Die unten genannten Aufnahmen wurden anhand der Originalseiten als CC0 recherchiert, anhand des **festen Git-Source-Commits** `euuuuuuan/todak-public@f298bf5d4fa9a0f1552ce8ca437ea1d940b42d4f` und exakt erwarteter Bytes/Blob-SHA1 über den Import-Workflow in den Branch geholt. Godot hat die OGG-Dauerwerte gemessen.

| Song | Passender Einsatz |
| --- | --- |
| Apple Cider | HüttenFolk, AlpenWelle und Bergmorgen |
| Etirwer | warme Akustik bei Hütten und im Morgenprogramm |
| Funked Up | après-ski Funk, Gitarren-Rock |
| DJ Synth Wave / Funk | SnowBeat/Alpenglühen/Freeride |
| Liquid Flame | Techno/House, Sport, Après-Ski |
| Lost in the Snow Wave | Synthwave für Freeride und Winter-Space |
| Coffee House Bump | Hotel-Café- und Lobby-Jazz |
| Jazz (Spring Spring) | klassische Hotelbar |
| Moon Unit | Powder Flow/Lodge Lo-Fi |
| Going Home | Lo-Fi für Kamin und Nachmittag |
| One Night in France | spätes Lo-Fi-Lounge-Programm |

Die genauen Autorennamen, Lizenzseiten, Originaldatei-Hashes, Dateigrößen und gemessenen Sekunden stehen unter [CC0 Music Rights](../assets/music/cc0/RIGHTS.md). **87 verschiedene OGG-Dateien**, ihre nachweisbar importierten und getimten Inhalte sowie die aktuelle Senderbelegung werden mit `tests/radio_genres_034.gd` geprüft. Wiederholte Programmslots sind keine neuen individuellen Aufnahmen. Die finale Hörprüfung jeder Musikproduktion auf Genre-Eignung und Lautheitsübergänge bleibt eine eigene Abnahme.

## UX und technische Freigabe

- Radiosender wechseln ohne „Übernehmen“-Knopf; die Einstellung wird direkt gesichert. Ausschalten stoppt das Musiksignal sofort.
- Jede Station besitzt eine virtuelle, synchron laufende Zeitlinie; beim Wechsel wird nicht auf Titel 1 zurückgesetzt.
- Nur lokal in der APK gebündelte OGGs. Kein Download/Tracking/Browser auf Senderwahl, keine API-Credentials.
- Die separaten Regelsysteme für Hotel-Lobby-Kontext, Tagesbetrieb, Radio-Wiedereinstieg nach Appwechsel und alte Spielstände bleiben unverändert.
- Freigabe-Gates: 15/15 Repository-Workflows einschließlich Android 30/36, lokaler Save-Recovery, tatsächlichem Audio-Decoder und visueller DE-/EN-Radiooberfläche; technische Hash-Prüfung ist **kein** Ersatz für eine menschliche Hörprobe.
