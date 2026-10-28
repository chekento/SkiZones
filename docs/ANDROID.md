# Android: Testversion bauen und installieren

## Grundlage

Das Projekt ist auf **Godot 4.5.2 Standard**, GDScript und den **Compatibility-Renderer** festgelegt. Die Test-APK enthält ausschließlich **arm64-v8a** und hat die Paketkennung `cloud.kosch.skizones`. Die Oberfläche läuft im Querformat.

Der Export verwendet das passende offizielle Godot-Android-Source-Template über Gradle. Die Vorbereitung korrigiert gezielt die Java-Anzeigefläche und die Behandlung von System-Overlays; die offiziellen nativen Bibliotheken bleiben erhalten. Compile-SDK 36, Ziel-SDK 35 und Mindest-SDK 24 sind festgelegt. Der Android-Quellbuild wird automatisch unter `android/build/` vorbereitet.

## GitHub Actions

Der Workflow **Validate and build Android** läuft bei Änderungen an `main`, bei Pull Requests und auf manuellen Start. Er importiert das Projekt, führt Simulations-, Karriere-, Schnee-, Gebiets-, Szenen- und Touch-Tests einschließlich eines Zwei-Winter-Laufs, fester Liftplätze, Stationsplätze, Gebäudebesuche alter Spielstände sowie Bauabbruch, Zwei-Finger-Kamera und Finger-/Stift-Scrollen aus. Die Szenen-, Animations- und Sitzplatzprüfungen verwenden Xvfb mit aktiver Compatibility-Grafikausgabe; echte Gebietswechsel laufen mit isolierten Spielständen. Danach exportiert er die APK und prüft ihre Signatur und ZIP-Struktur. Ein separater x86-64-Testexport läuft zusätzlich in Android-11- und Android-16-Emulatoren. Home-/Rückkehrzyklen, Bildschirm aus/an und Prozessneustart müssen sichtbare Spielbilder sowie erhaltene Gäste und Betriebszeit liefern. Die Veröffentlichung wartet auf beide Emulator-Jobs. Das Ergebnis steht als **SkiZones-Android-debug** im jeweiligen Workflow-Lauf bereit.

Bei einem erfolgreichen Lauf auf `main` veröffentlicht der anschließende Job eine neue Versionsnummer als GitHub-Preview-Release. Die APK heißt `SkiZones-<Version>-android-arm64.apk`. Prüfsumme und `manifest.json` werden beigefügt. Der direkte Download steht oben in der README. Veröffentlichte Versionen werden nicht nachträglich überschrieben. Eine neue Fassung benötigt passende neue Versionsnummern in Projekt und Export-Preset, einen höheren Android-Versionscode und zugehörige Notizen unter `docs/releases/`.

Die CI erstellt einen Debug-Schlüssel und erhält ihn über den Actions-Cache. Solange dieser Cache erhalten bleibt, können CI-Testversionen mit derselben Signatur aktualisiert werden. Der Schlüssel ist ausschließlich für Tests bestimmt. Er wird nicht ins Repository geschrieben. APK-Artefakte bleiben 30 Tage verfügbar und können erneut gebaut werden.

## Lokal unter Linux bauen

Voraussetzungen:

- Godot **4.5.2** und **exakt passende Export-Templates 4.5.2**.
- OpenJDK **17**.
- Android SDK Command-line Tools mit `platform-tools`, `platforms;android-35`, `platforms;android-36`, `build-tools;35.0.0` und `build-tools;35.0.1`.
- Python 3 ohne zusätzliche Pakete.

```bash
export JAVA_HOME=/pfad/zum/jdk-17
export ANDROID_HOME=/pfad/zum/android-sdk
export GODOT_BIN=/pfad/zu/godot
python3 tools/export_android.py
python3 tools/package_android.py
```

Das Skript legt den Debug-Schlüssel und isolierte Godot-Exporteinstellungen unter `build/export-config/` an. Persönliche Editor-Einstellungen werden nicht verändert. `build/` ist von Git ausgeschlossen.

Wer die offiziellen Linux-Binaries automatisch installieren möchte, kann `bash tools/install_godot.sh` verwenden. Das Skript prüft die Downloads gegen das offizielle SHA-512-Manifest. `SKIZONES_TOOLS_DIR` bestimmt das Zielverzeichnis; für die darin installierten Templates muss `XDG_DATA_HOME="$SKIZONES_TOOLS_DIR/share"` gesetzt sein.

Die native Android-Vorbereitung ist für Linux und GitHub Actions vorgesehen. Unter Windows und macOS kann das Spiel im Godot-Editor gespielt werden; für die APK mit denselben nativen Korrekturen den Linux-/CI-Build verwenden.

## Installieren

Die Datei `build/android/SkiZones-debug.apk` auf das Gerät kopieren und öffnen oder mit Android Platform-Tools installieren:

```bash
adb install -r build/android/SkiZones-debug.apk
```

Eine lokal erzeugte APK und eine CI-APK können unterschiedliche Debug-Signaturen haben. Android erlaubt dann kein Update über die bestehende Installation. Vor einer Deinstallation beachten: Die lokalen Spielstände werden dabei normalerweise gelöscht. Den bisherigen Debug-Schlüssel für weitere lokale Builds aufbewahren.

Die App benötigt keinen Account und keine Internet-, Mikrofon-, Kamera- oder allgemeinen Speicherberechtigungen. Spielstände liegen im privaten App-Verzeichnis.

## Noch ausstehende Geräteprüfung

- Installation und Start auf einem physischen ARM64-Gerät.
- Touch-Größen, Aussparungen am Display und System-Zurück-Taste.
- App-Wechsel, Bildschirm ausschalten, Wiederherstellung nach Prozessende.
- Bildrate, thermisches Verhalten und Speicher bei einem großen Resort.
- Regressionen mit mehreren gleichzeitig aufeinanderfolgenden Liftsystemen.

Die automatisierten Eingabetests ersetzen diese Geräteprüfung nicht.

## Vor einer Veröffentlichung

Separaten Release-Keystore verwalten, Versionscodes erhöhen, Gradle/AAB und aktuelle Store-Anforderungen prüfen, Datenschutz- und Store-Angaben erstellen, Lizenzen erfassen und die Geräteprüfung abschließen. Das bestehende Debug-Preset erstellt keine Store-Veröffentlichung.

Offizielle Referenz: [Godot 4.5 – Exporting for Android](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html).

## App-Wechsel seit 0.10

Beim Verlassen sichert das Spiel Resort und Sitzungspunkt. Bei der Rückkehr werden Eingabekontakte gelöst und Kamera, Viewport und laufende Darstellung aktiviert. Bereits vorhandene Planung, Pauseneinstellung und Geschwindigkeit bleiben erhalten. Zeit eines zuvor laufenden Betriebs wird bei der Rückkehr über reale Simulationsschritte nachgeholt; die Arbeit je Bild ist begrenzt. Es wird kein dauerhafter Android-Hintergrunddienst gestartet.

Ein von Android beendeter Prozess kann anhand des zusätzlichen, an den Resort-Spielstand gebundenen Sitzungspunkts direkt zum letzten Resort zurückkehren. Ein ungültiger Sitzungspunkt führt zum regulären Menü; der separat geprüfte Resort-Spielstand bleibt über **Fortsetzen** erreichbar.

Godot 4.5.2 und exakt passende Export-Templates sind gemeinsam gepinnt. Die [offiziellen Wartungsnotizen](https://godotengine.org/article/maintenance-release-godot-4-5-2/) dokumentieren Android-/Rendering-Korrekturen. Geräteabhängige Wiederaufnahmeprobleme lassen sich dadurch nicht pauschal ausschließen. Der konkrete physische Gerätetest bleibt von den Emulatorprüfungen getrennt.

### Bildausgabe in 0.10.0

Die Bildrate wird weiter durch das gewählte 30/60-Ziel begrenzt. Die zusätzliche native Swappy-Warteschlange ist abgeschaltet, um bei zerstörten und neu erstellten Android-Surfaces keine zweite Bildtaktung zu behalten. Die Wiederaufnahme wartet auf den nächsten Spielzyklus und erneuert Kamera, sichtbare Anlagen und HUD; die native Root-Viewport-Aktivierung übernimmt Android. Die Tests warten auf fortschreitende Spielzeit und tatsächlich präsentierte Bilder, nicht nur auf einen bereits erzeugten Spielzustand.

### Native Anzeigefläche

Beide Android-Exporte verwenden den dokumentierten [Java-Lifecycle-Patch](../tools/android/README.md). Er erkennt ausgetauschte native Surfaces anhand ihrer Generation und bindet EGL auf dem Rendering-Thread neu. Verspätete Fehler der alten Fläche blockieren die neue nicht. Die offiziellen nativen Godot-Bibliotheken bleiben bytegleich; die Vorbereitung prüft dies für jedes AAR-Mitglied. Dafür enthält das offizielle Template zusätzlich `android_source.zip`, und der Export verwendet Gradle mit SDK 35 und JDK 17.

Android-16-Systemfarben und Navigationsleisten dürfen die laufende Godot-Activity nicht neu erstellen. Der verwaltete Build ergänzt deshalb die öffentliche Konfiguration `assetsPaths` und verwendet dafür Compile-SDK 36 mit AGP 8.9.1 und Gradle 8.11.1. Mindestversion 24 und Zielversion 35 bleiben erhalten. Ein zusätzlicher nativer Test wechselt eine tatsächliche Systemdarstellung und setzt sie zurück. Die APK komprimiert ihre nativen Bibliotheken für den Download.

Die native Grafikprüfung unterdrückt nur den erstmaligen Android-Vollbild-Lehrhinweis in der Emulator-Einrichtung. Auch nach einem absichtlich neu gestarteten Prozess muss das Spiel mindestens fünf neue Bilder selbst gezeichnet haben, bevor eine Aufnahme als wiederhergestellte Spielszene zählt.
