# 0.38 – echte WC-Besuche und feste Serviceaktionen

Lokale Prüfung am 6. November 2026, offizielles Godot **4.5.2**, SHA512 gegen das offizielle Manifest geprüft. Fortsetzung des Entwurfs aus PR #83, Ausgangsstand `58e25dea12df56a6a8d7e9703449101c175b535c`.

## Behobene Ablauffehler

1. Eine dreiköpfige Familie durfte zuvor eine einzelne Dixi-Kabine nicht auswählen. Nun benutzen Gruppen die vorhandenen Kabinen nacheinander. Aktuelle Besucher belegen echte Kabinen, anreisende Gäste reservieren begrenzte Kapazität. Ein einzelnes Dixi bedient keine zwei Gruppen gleichzeitig.
Auch bei einzeln simulierten Familienmitgliedern fließt der Toilettendrang eines Kindes in die Wegwahl der zuständigen Begleitperson ein; deren eigener Bedarf wird dabei nicht verfälscht.

2. Reservierungen berücksichtigen Tank, Hygiene und höchstens 18 Spielminuten für Warteschlange und Nutzung. Die Reiseplanung beachtet zusätzlich An- und Rückweg. Der tatsächliche Besuch dauert auch bei der 24-Schritte-Uhr drei bzw. vier echte Spielminuten pro Durchgang. Wartende bekommen keine vorzeitigen Serviceeffekte.
3. Der generische Gebäudeausbau verlangte ab Stufe 3 Hotel-Meisterforschung. Öffentliche WC-Anlagen verwenden nun ihre eigene Forschungsfolge. Angezeigte Kabinenzahl und routbare Kapazität stimmen überein; Tank-, Hygiene- und Wartungsverbesserungen wirken tatsächlich.
4. Neue unbenutzte Toiletten erhalten ihren Wartungszustand bereits beim Bauen und altern ohne ersten Gastbesuch. Alte Anlagen ohne Zusatzfelder bleiben lesbar.
5. Reinigen und Entleeren stehen über dem scrollenden Inhalt in einer festen Leiste. Hygiene und Tank erscheinen zuerst. Lange Einführungstexte entfallen im oberen Bereich.

## Lokale Ergebnisse

| Prüfung | Bestanden | Fehlgeschlagen |
| --- | ---: | ---: |
| Öffentliche WC-Grundsimulation | 18 | 0 |
| Tatsächliche WC-Warteschlange, Familien, eigene Forschung und Save/Load | 62 | 0 |
| Hotel-Simulator | 24 | 0 |
| Echte Servicewege und Verfügbarkeit | 40 | 0 |
| Gästeziele und Familienversorgung | 72 | 0 |
| Isoliertes Prüfen, Kopieren, Retten und Archivieren von Spielständen | 15 | 0 |
| Gerenderte Gebäude-, Team-, Karriere- und WC-Oberfläche | 56 | 0 |
| **Gesamt** | **287** | **0** |

Gerenderte WC-/Karriereansichten: **1440×900, 360×740, 420×860 und 740×360**, jeweils Deutsch und Englisch. Die WC-Bedienung wird über ihre tatsächlichen Widgets geprüft, einschließlich fester Position der Serviceaktionen. Beispiele: [Deutsch](../screenshots/public-wc-038-de-420x860.png), [Englisch](../screenshots/public-wc-038-en-360x740.png).

Die Warteschlangenprüfung verwendet tatsächliche gebaute Anlagen, zugelassene Gäste, vollständige validierte Reisepläne und normale Simulationstakte; keine ersetzten Routing-/Savefunktionen. Für den isolierten Warteschlangentest wird die Starterhütte geschlossen, damit Gäste nicht stattdessen deren enthaltene Toilette wählen. Eine aktive Warteschlange wird als JSON gespeichert, wiederhergestellt und ihre Bedienreihenfolge verglichen. Negative Ankunftszeiten werden abgewiesen.

3077 DE-/EN-Nachrichten, Platzhalter und Quellabdeckung geprüft. Beide bearbeiteten Workflow-Dateien sind als YAML lesbar; `git diff --check` ohne Befund. Der gerenderte GUI-Prozess meldet beim Beenden verbliebene Canvas-/Text-/Texture-Ressourcen; die Prüfung enthält keine Scriptfehler. Dies ersetzt keine Android-Lifecycle-Prüfung.

## Freigabe

Diese lokalen Ergebnisse sind keine Android-Freigabe. Alle neuen 0.38-Simulationen, die isolierte Speicherprüfung und die gerenderte Verwaltungsprüfung wurden zusätzlich in die obligatorische Hauptzweig-Pipeline aufgenommen. Die komplette CI einschließlich alter Originalspielstände, APK-Signatur und Android API 30/36 muss auf dem endgültigen Commit bestehen. Die ausstehenden 100 WC-Technologien und gelben Schnee-/Waldspuren werden damit nicht als fertig behauptet.
