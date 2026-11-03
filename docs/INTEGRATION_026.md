# SkiZones 0.26 · Zusammengeführter Arbeitsstand

Diese Fassung verbindet die bisher getrennten Entwicklungszweige. Ein Entwicklungszweig und ein erfolgreicher Teiltest sind noch kein veröffentlichter APK-Download. Der öffentliche Download im README wird ausschließlich anhand tatsächlich veröffentlichter Release-Dateien aktualisiert.

## Übernommene Arbeit

| Stand | Inhalt | Herkunft |
|---|---|---|
| 0.23 | Landschaft, Höhenlinien, Pistenmodule, beweglicher Dorfkatalog, Tagesrhythmus | PR #18; Android 30/36 und übrige Freigabetests bestanden |
| 0.24 | Hotel-Mikrowelten, lesbarere Erfolge, deutlichere alternative Grafikstile | PR #19 |
| 0.25 | Lineare Hotelmodule, zusätzliche Gewerbe, jährliche Winterereignisse | PR #22 |
| 0.26 Radio/Crew | Eigene Offline-Loops, ortsabhängige Atmosphäre, Crew, Pistenatlas, weitere Assets | PR #24 |
| 0.26 Tour/Medien | Optionale reale Szenarien, Kameratour, Jahres- und Szenariomedaillen, Dorfzeitung | PR #23 |

Die jüngsten Testkorrekturen aus 0.24 und 0.25 wurden mit dem Radio-Zweig verglichen: Die korrigierten Update- und Tagesrhythmus-Fixtures sind bereits identisch übernommen. Die Versionsnummer der gemeinsamen APK bleibt 0.26.0, Android-Code 33. Die separaten Versionsnotizen bleiben erhalten; nicht veröffentlichte Zwischenstände erhalten keine erfundenen APK-Links.

## Zusätzliche Korrekturen

- Ein gemeinsamer Audioplayer ersetzt die beiden konkurrierenden Prototypen. Eine Jukebox mit sechs Stilen und Musik aus bedient sämtliche Einstiegspunkte.
- Live-Vorschau wird unabhängig von gespeicherten Einstellungen gehalten und nicht beim nächsten Umgebungspoll zurückgesetzt. Abbrechen stellt die gespeicherten Werte wieder her.
- Globale Stummschaltung und Null-Lautstärke ergeben tatsächliche Stille. Beim Appwechsel werden die Kanäle suspendiert; die Rückkehr blendet sie wieder ein. Zwischen Hörbereichen werden Lautstärken weich überführt.
- Synthetische Gesprächsatmosphäre richtet sich nach tatsächlich anwesenden Personen. Schlafende Hotelgäste und leere Plätze erzeugen keine Menschenmenge. Ein stehender Lift erhält keinen laufenden Motor.
- Vorhandene Radioeinstellungen aus dem anderen Prototypen werden auf den gemeinsamen Mixer abgebildet. Ungültige numerische Audiowerte werden verworfen.
- Der Jukebox-Dialog, das Medaillenarchiv und die übrigen Fenster sperren die darunterliegende Baufläche zuverlässig. Escape und Android-Zurück berücksichtigen beide bisher getrennten Erweiterungen.
- Um die Mitarbeiterunterkunft werden Bäume, Landschaftsdetails und Wildtierpfade automatisch ausgespart. Der Eingang liegt außerhalb der Gebäudemitte.
- Neue Rettungseinsätze speichern ihre tatsächliche Reaktionsdauer; die visuelle Fahrt beginnt dadurch am Ausgangspunkt statt schon weit entlang der Strecke.
- Anfänger wählen eine gleichbleibende Umfahrungsseite für Pistenmodule. Ein Wechsel ihrer Schwungkurve versetzt sie nicht plötzlich über die Rampe.
- Kameradrehung bleibt an Übergängen zwischen Tourstationen stetig. Beim Verlassen der Tour werden die vorherigen Kamerawerte wiederhergestellt.
- Der gemeinsame Radiozugang erscheint einmal in der Kameraleiste. Atlasbeschriftung, Comicrahmen und Filmbalken bleiben innerhalb der sichtbaren Karte und überdecken keine Budget- oder Kamerabedienung. Hörbereiche tragen übersetzte Namen; der Tempo-Hinweis beschreibt den kürzeren Skitag.
- Zusätzliche deutsche und englische Texte, insbesondere für Szenarien, Zeitung, Medaillen und Audio, wurden ergänzt. Der Hauptmodus-Test prüft jetzt den Vorrang des Hauptspiels bei optional erreichbaren Szenarien.

## Prüfung

`tests/integration_quality_026.gd` prüft die tatsächliche gemeinsame Oberfläche und Audioinstanzen, Vorschau/Abbruch, Stummschaltung, Migration, freie Unterkunftsflächen, stetige Umfahrungen und Kamera-Rückkehr. Gerenderte Bilder dokumentieren Jukebox, Tour und Medaillen. Die Kernprüfungen für Hotelmodule, Jahresarchiv, Offline-Audio und Szenarien sowie die sechs Bildstile sind Bestandteil der gemeinsamen QA. Die vollständige Android-Pipeline enthält diese Prüfungen zusätzlich zu Migration, Signaturkontinuität und Android 30/36. Der Emulator verwendet weiterhin GLES mit echten sichtbaren Frames; Vulkan wird gemäß der [offiziellen Android-Fehlerhilfe](https://developer.android.com/studio/run/emulator-troubleshooting) explizit deaktiviert, um den nicht unterstützten Vulkan-/Browserpfad auf den CI-Rechnern zu vermeiden. Browserübergabe, Appwechsel, Signatur- und Updateprüfungen bleiben vollständig aktiv.

## Grenzen dieser Fassung

Es gibt noch keine Suno-Songgenerierung oder bestätigte Suno-Partnerschaft. Die sechs kurzen musikalischen Loops sind eigene synthetische Klangskizzen. Die Mitarbeiterunterkunft ist noch kein separater Wohnungs- und Bettenwirtschaftssimulator. Rettungsfahrzeuge werden weiterhin vereinfacht dargestellt; eine vollständig navigierte Fahrzeugsteuerung ist nicht enthalten. Das Szenariomenü allein bestätigt nicht, dass jede importierte Piste vollständig befahrbar ist. Diese Grenzen bleiben in den jeweiligen Versionsplänen dokumentiert.
