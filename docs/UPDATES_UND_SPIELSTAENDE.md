# Spielstände behalten und SkiZones aktualisieren

## Vier eigene Karrieren

Öffne im Hauptmenü **Karriere · vier Spielstände**. Jeder Platz enthält seine eigenen Resorts, Finanzen, Gäste und Freischaltungen. **Diese Karriere fortsetzen** lädt den gewählten Platz. Ein leerer Platz startet eine neue Karriere mit dem ersten Resort.

Ein Neustart eines belegten Platzes fragt vorher nach und archiviert die bisherigen Dateien. Die anderen drei Plätze bleiben erhalten. Freier Aufbau und Szenarien haben zusätzliche, getrennte Speicherstände. Beim Gebietswechsel und beim Verlassen der App wird gespeichert.

Beim ersten Start mit Version 0.17 werden die bisherigen Spielstände kopiert: die bisherige Karriere auf Platz 1, freie Resorts in den freien Aufbau und reale Szenarien in die Szenariospeicher. Die alten Dateien bleiben als zusätzliche Sicherung erhalten. Bestehende Spielstände werden bei erneutem Start nicht noch einmal überschrieben.

## Updates aus dem Spiel

Ab Version 0.17 prüft SkiZones beim App-Start nach neuen GitHub-Veröffentlichungen, frühestens sechs Stunden nach der letzten automatischen Prüfung. **Updates · Spielstände behalten** im Hauptmenü öffnet die manuelle Prüfung. Ein verfügbares Angebot wird direkt am Menüknopf angezeigt. Ohne Internet kannst du normal weiterspielen und später erneut prüfen.

1. **Update herunterladen** lädt die passende Android-ARM64-Datei direkt aus dem SkiZones-GitHub-Release.
2. SkiZones prüft Version, Paket, Dateigröße, Prüfsumme und die Android-Signatur der vorhandenen Installation.
3. **Installieren** speichert das aktuelle Resort. Falls Android danach fragt, erlaube einmalig Installationen aus SkiZones und kehre zur App zurück.
4. Bestätige **Aktualisieren** im Android-Installationsfenster. Das Update ersetzt die vorhandene App und behält deren Daten.

**Die vorhandene App installiert lassen.** Für den ersten Wechsel von 0.16 auf 0.17 die neue APK herunterladen und über die vorhandene App installieren. Die integrierte Prüfung steht danach für folgende Versionen bereit. „Deinstallieren“ oder „App-Daten löschen“ entfernt die lokal gespeicherten Karrieren und gehört nicht zum Updateablauf.

Android verlangt eine passende Signatur. Eine separat selbst erstellte oder anders signierte APK wird deshalb abgewiesen; SkiZones löscht dafür keine Spielstände. Zusätzlich vergleicht der Veröffentlichungsbuild seine Signatur mit der vorherigen öffentlichen APK und hält bei einer abweichenden Identität an.

Die Veröffentlichung enthält eine SHA-256-Datei und `manifest.json` mit Größe, Versionscode und Quellcodekennung. Auf dem PC öffnet die Updateansicht den passenden GitHub-Release; der integrierte APK-Installer ist für Android vorgesehen.

## Zeit und Nachtbetrieb

Bei **1×** bewegen sich Gäste und Lifte so schnell wie vorher bei **4×**. Der Kalender läuft dabei sechsmal langsamer als vorher: Eine Spielstunde dauert ungefähr zwölf echte Minuten. **4×** beschleunigt Bewegung und Kalender weiterhin gemeinsam.

Wenn nachts wirklich kein Gast mehr im Resort ist, läuft die Zeit automatisch schneller bis 08:00. Bei der ersten neuen Ankunft endet dieser automatische Zeitraffer. Ein tagsüber leeres Resort behält das gewählte Tempo, damit du in Ruhe bauen kannst. Tagesabrechnungen, Schichten und Wetterwechsel werden beim Vorspulen normal ausgeführt.

Besetzte und besetzbare Clubs können bis 06:00 geöffnet bleiben; Schwimmbäder und Spas haben ebenfalls längere Nachtzeiten. Für den vollen Betrieb braucht es passende Abend- und Nachtkräfte. Gäste bleiben für längere echte Besuche, können weitere Angebote nutzen und brechen um den Morgen herum nach Hause auf.
