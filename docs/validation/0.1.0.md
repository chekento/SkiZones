# Prüfung des ersten spielbaren Stands

Stand: 27.10.2026 · SkiZones 0.1.0 · Godot 4.5.1 (`f62fdbde1`).

| Prüfung | Ergebnis |
|---|---|
| Simulations- und Speicherstandtests | 52 bestanden |
| Integration, Oberfläche und Touch-Eingaben | 20 bestanden |
| Projektimport und Szenen-Starttest | Bestanden; 129 aktive Gäste im Starttest |
| Darstellung | Hauptmenü und Resort unter OpenGL/Compatibility gerendert und visuell geprüft |
| Android-Export | Debug-APK erfolgreich erstellt |
| Signatur | APK Signature Scheme v2 und v3 bestätigt |
| ZIP und Asset-Auswahl | Geprüft; Build-Konfiguration, Tests und Werkzeuge ausgeschlossen |
| Architektur | arm64-v8a |
| Paketkennung | cloud.kosch.skizones |
| SDK | Mindestversion 24, Zielversion 35 |
| Besondere Android-Berechtigungen | Keine angefordert |
| Physischen Android-Test | Noch nicht durchgeführt |

APK-Größe: 27,739,874 Bytes.

SHA-256 der lokal erstellten Test-APK:

```text
c3672c87bf791eb7532a83363d36e266d461e0133c8ec53fbadaf06d7cc2a99c
```

Die Screenshots zeigen den tatsächlichen laufenden Prototyp, keine Konzeptbilder. Der verwendete virtuelle Grafiktreiber unterstützt keine V-Sync-Umschaltung; daraus lässt sich keine Geräte-Bildrate ableiten. Ein separat erzeugter CI-Build kann wegen Signatur, Zeitstempeln und Verpackung eine andere Prüfsumme haben.
