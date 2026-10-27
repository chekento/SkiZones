# Android: Testversion bauen und installieren

## Grundlage

Das Projekt ist auf **Godot 4.5.1 Standard**, GDScript und den **Compatibility-Renderer** festgelegt. Die Test-APK enthält ausschließlich **arm64-v8a** und hat die Paketkennung `cloud.kosch.skizones`. Die Oberfläche läuft im Querformat.

Der Export verwendet die offiziellen, vorkompilierten Android-Templates ohne Gradle. Mindest- und Ziel-SDK stammen deshalb aus dem passenden Godot-Template. Für eine spätere Store-Version mit abweichendem Ziel-SDK und AAB wird ein eigener Gradle-Export benötigt.

## GitHub Actions

Der Workflow **Validate and build Android** läuft bei Änderungen an `main`, bei Pull Requests und auf manuellen Start. Er importiert das Projekt, führt Simulations-, Szenen- und Touch-Tests aus, exportiert die APK und prüft ihre Signatur und ZIP-Struktur. Das Ergebnis steht als **SkiZones-Android-debug** im jeweiligen Workflow-Lauf bereit.

Bei einem erfolgreichen Lauf auf `main` veröffentlicht der anschließende Job eine neue Versionsnummer als GitHub-Preview-Release. Die APK heißt `SkiZones-<Version>-android-arm64.apk`. Prüfsumme und `manifest.json` werden beigefügt. Der direkte Download steht oben in der README. Veröffentlichte Versionen werden nicht nachträglich überschrieben. Eine neue Fassung benötigt passende neue Versionsnummern in Projekt und Export-Preset, einen höheren Android-Versionscode und zugehörige Notizen unter `docs/releases/`.

Die CI erstellt einen Debug-Schlüssel und erhält ihn über den Actions-Cache. Solange dieser Cache erhalten bleibt, können CI-Testversionen mit derselben Signatur aktualisiert werden. Der Schlüssel ist ausschließlich für Tests bestimmt. Er wird nicht ins Repository geschrieben. APK-Artefakte bleiben 30 Tage verfügbar und können erneut gebaut werden.

## Lokal unter Linux bauen

Voraussetzungen:

- Godot **4.5.1** und **exakt passende Export-Templates 4.5.1**.
- OpenJDK **17**.
- Android SDK Command-line Tools mit `platform-tools`, `platforms;android-35` und `build-tools;35.0.0`.
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

Auf Windows und macOS lassen sich SDK, JDK und Debug-Schlüssel in Godots Editor-Einstellungen unter **Export → Android** konfigurieren. Anschließend das Preset **Android** als Debug-APK exportieren. Das mitgelieferte Python-Skript ist für Linux/CI vorgesehen.

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
