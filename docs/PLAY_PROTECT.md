# Google Play Protect und SkiZones

Am 31.10.2026 wurde für die GitHub-APK von **SkiZones 0.17.0** die Meldung **„Schädliche App blockiert“** gemeldet. Das ist eine konkrete Play-Protect-Warnung. Der Screenshot nennt keine technische Ursache oder Schadsoftware-Kategorie. Wir können daraus weder einen bestätigten Befall noch eine bestätigte Fehlklassifizierung ableiten.

## Was wir ändern

Die Version 0.18 befindet sich in Prüfung. Der direkte APK-Downloader und Installer aus 0.17 werden entfernt. SkiZones prüft weiterhin GitHub-Veröffentlichungen und deren Manifest. Vor dem Öffnen der offiziellen GitHub-Seite wird das aktuelle Resort gespeichert. Download und Installation übernimmt anschließend der vom Spieler gewählte Browser zusammen mit Android.

Die neue APK soll **ohne `REQUEST_INSTALL_PACKAGES`**, ohne eigenen APK-FileProvider und ohne den bisherigen Installations-Bridgecode veröffentlicht werden. Der öffentliche Download wird als **Release-Build ohne Debuggerfreigabe** erstellt. Paketkennung und bisherige Signatur werden für Aktualisierungen mit erhaltenen Spielständen beibehalten.

Die Buildprüfung kontrolliert die tatsächlich exportierte APK: deklarierte Berechtigungen, Debuggerkennzeichen, Archivstruktur, entfernte Installerklassen und Übereinstimmung mit der bisherigen Signatur. Diese technische Prüfung ersetzt keine Einstufung durch Google Play Protect.

## Was die Internetverbindung macht

Der neue Updater ruft ausschließlich öffentliche Versions- und Manifestinformationen des SkiZones-Projekts auf GitHub ab. Dabei wird die App-Version als User-Agent verwendet. Karrieren, Gästedaten und Einstellungen werden nicht für die Updateprüfung hochgeladen. Das Spiel bleibt offline spielbar.

## Was weiterhin offen ist

Es liegt **keine unabhängige Bestätigung vor, dass Google die Einstufung aufgehoben hat**. Eine reduzierte Berechtigungsliste garantiert keine Änderung der Bewertung. Falls die Warnung auch bei einer neuen Version erscheint, gehört die konkrete APK mit Versionsnummer, Prüfsumme und Signatur in eine Überprüfung durch Google. Eine pauschale Aussage „harmlos“ wäre dafür kein Ersatz.

Google empfiehlt, Berechtigungen auf den erforderlichen Umfang zu begrenzen, den Code und verwendete Bibliotheken zu prüfen und bei einer vermuteten Fehlklassifizierung den offiziellen Einspruchsweg zu nutzen:

- [Google: Hinweise für Entwickler zu Play-Protect-Warnungen](https://developers.google.com/android/play-protect/warning-dev-guidance?hl=de)
- [Google: App-Überprüfung und Einspruch](https://support.google.com/googleplay/android-developer/answer/2992033?hl=de)
- [Google: Verwendung von REQUEST_INSTALL_PACKAGES](https://support.google.com/googleplay/android-developer/answer/12085295?hl=en)

Für vorhandene Spielstände gilt: Die neue APK wird über die bestehende Installation installiert. Eine Deinstallation oder das Löschen der App-Daten entfernt lokale Spielstände und gehört nicht zum Updateablauf.
