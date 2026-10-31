# Spielstände behalten und SkiZones aktualisieren

## Vier eigene Karrieren

Öffne im Hauptmenü **Karriere · vier Spielstände**. Jeder Platz enthält seine eigenen Resorts, Finanzen, Gäste und Freischaltungen. **Diese Karriere fortsetzen** lädt den gewählten Platz. Ein leerer Platz startet eine neue Karriere mit dem ersten Resort.

Ein Neustart eines belegten Platzes fragt vorher nach und archiviert die bisherigen Dateien. Die anderen drei Plätze bleiben erhalten. Freier Aufbau und Szenarien haben zusätzliche, getrennte Speicherstände. Beim Gebietswechsel und beim Verlassen der App wird gespeichert.

Beim ersten Start mit Version 0.17 werden die bisherigen Spielstände kopiert: die bisherige Karriere auf Platz 1, freie Resorts in den freien Aufbau und reale Szenarien in die Szenariospeicher. Die alten Dateien bleiben als zusätzliche Sicherung erhalten. Bestehende Spielstände werden bei erneutem Start nicht noch einmal überschrieben.

## Updates aus dem Spiel

Ab Version 0.17 prüft SkiZones beim App-Start nach neuen GitHub-Veröffentlichungen, frühestens sechs Stunden nach der letzten automatischen Prüfung. **Updates · Spielstände behalten** im Hauptmenü öffnet die manuelle Prüfung. Ein verfügbares Angebot wird direkt am Menüknopf angezeigt. Ohne Internet kannst du normal weiterspielen und später erneut prüfen.

1. SkiZones prüft öffentliche GitHub-Veröffentlichungen und das zugehörige Manifest auf Version, Paket, ARM64-Architektur und gültige Größen-/Prüfsummenangaben.
2. **GitHub-Download im Browser öffnen** speichert das aktuelle Resort und den Sitzungspunkt, bevor die offizielle Veröffentlichung geöffnet wird.
3. Lade dort die APK herunter. Browser und Android übernehmen Download und Installationsbestätigung. SkiZones benötigt dafür keine eigene Installationsberechtigung mehr.
4. Installiere die APK **über die vorhandene App**. Android prüft die passende Signatur und den höheren Versionscode und behält bei einer Aktualisierung die privaten App-Dateien.
5. Starte danach über das App-Symbol weiter. Das zuletzt aktive Resort wird wiederhergestellt.

**Die vorhandene App installiert lassen.** „Deinstallieren“ oder „App-Daten löschen“ entfernt normalerweise die lokal gespeicherten Karrieren und gehört nicht zum Updateablauf. Auch der Wechsel von 0.17 auf 0.18 kann direkt mit der GitHub-APK erfolgen.

Ab 0.18 enthält SkiZones keinen APK-Downloader, keinen eigenen Installer und keinen APK-FileProvider. Alte Update-Zwischendateien werden bereinigt; Karrieren und Einstellungen bleiben erhalten. Eine Installationsfreigabe für SkiZones selbst ist nicht erforderlich. Die Updateprüfung funktioniert weiterhin automatisch alle sechs Stunden und manuell im Menü. Ohne Internet kannst du normal weiterspielen.

Eine separat selbst erstellte oder anders signierte APK kann die vorhandene Installation nicht aktualisieren. Der Veröffentlichungsbuild vergleicht seine Signatur deshalb zusätzlich mit der vorherigen öffentlichen APK und hält bei einer abweichenden Identität an. SHA-256-Datei und `manifest.json` dokumentieren Größe, Versionscode, Quellcodekennung und Berechtigungsprüfung des Downloads.

Für 0.17 wurde eine konkrete Play-Protect-Warnung gemeldet. Die Ursache und eine Aufhebung der Einstufung sind nicht bestätigt: [Stand der Prüfung](PLAY_PROTECT.md).

## Zeit und Nachtbetrieb

Bei **1×** bewegen sich Gäste und Lifte so schnell wie vorher bei **4×**. Der Kalender läuft dabei sechsmal langsamer als vorher: Eine Spielstunde dauert ungefähr zwölf echte Minuten. **4×** beschleunigt Bewegung und Kalender weiterhin gemeinsam.

Wenn nachts wirklich kein Gast mehr im Resort ist, läuft die Zeit automatisch schneller bis 08:00. Bei der ersten neuen Ankunft endet dieser automatische Zeitraffer. Ein tagsüber leeres Resort behält das gewählte Tempo, damit du in Ruhe bauen kannst. Tagesabrechnungen, Schichten und Wetterwechsel werden beim Vorspulen normal ausgeführt.

Besetzte und besetzbare Clubs können bis 06:00 geöffnet bleiben; Schwimmbäder und Spas haben ebenfalls längere Nachtzeiten. Für den vollen Betrieb braucht es passende Abend- und Nachtkräfte. Gäste bleiben für längere echte Besuche, können weitere Angebote nutzen und brechen um den Morgen herum nach Hause auf.
