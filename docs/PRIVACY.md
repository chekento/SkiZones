# SkiZones — Datenschutz und externe Medien

Stand: 2026-11-04 · Hinweis für die Veröffentlichung; finale rechtliche Prüfung ausstehend.

## Offline-Wiedergabe

Die in `assets/music/cc0/library.json` beschriebenen und bereits eingebundenen Musikdateien sind lokal im Spiel gebündelt. Ihre Wiedergabe baut keine Verbindung zu SoundCloud oder anderen Musikdiensten auf. Die Ausstrahlung erfolgt nicht über ein externes Radio.

## ERG0SPHERE — SoundCloud als freiwilliger Drittanbieter

Rechteinhaber/Künstler: **KoSch / Kolja W. Schumann**. Album: [erg0sphere - journey discontinued](https://soundcloud.com/koljawschumann/sets/erg0sphere-journey). In der Android-App wird die Webseite von SoundCloud ausschließlich durch einen ausdrücklich betätigten Button geöffnet. Die vorhandene HTML-Variante des Embedded Players bleibt bis zur manuellen Zustimmung blockiert (Zwei-Klick-Prinzip, `docs/embed/erg0sphere.html`). Ein Embed im Browser kann bereits beim Laden eine Verbindung zu SoundCloud herstellen. Die App setzt SoundCloud-Playlists nicht stillschweigend als Hintergrundstream ein.

**Verantwortlicher Drittanbieter:** SoundCloud. Beim Aufruf können unter anderem die IP-Adresse, Informationen zu Browser und Gerät, besuchte Seite, ggf. Nutzungs- und Cookie-Daten verarbeitet und, wenn die Person angemeldet ist, ihrem SoundCloud-Konto zugeordnet werden. Die konkrete Verarbeitung liegt bei SoundCloud und richtet sich nach seinen Richtlinien. Der in Spiel/HTML genutzte externe Zugang ist freiwillig; ohne Klick findet keine durch SkiZones initiierte SoundCloud-Verbindung statt. Für den optionalen HTML-Embed ist eine aktive Zustimmung vor dem Laden vorgesehen. Der eingebettete Player verwendet `auto_play=false`; es gibt keinen automatisch gestarteten Ton.

Informationen des Anbieters:
- [SoundCloud-Datenschutzerklärung](https://soundcloud.com/pages/privacy)
- [SoundCloud-Cookie-Richtlinie](https://soundcloud.com/pages/cookies)

Die Einwilligung für den Embed gilt nur für den aktuellen Seitenaufruf. Verlassen/Neuladen der Seite verhindert eine automatische spätere Ladung. Bereits im Browser gesetzte Cookies können über Browser- bzw. SoundCloud-Einstellungen verwaltet werden. Die App selbst speichert keine SoundCloud-Zugangsdaten.

## Medienrechte und regionale Playlists

Die vom Nutzer bestätigten Rechte an ERG0SPHERE berechtigen zur vorgesehenen eigenen Albumpräsentation, sind aber keine allgemeine Open-Content-Lizenz. Für eine tatsächlich offline mit der APK ausgelieferte Version müssen die Quelldateien und die Distributionsberechtigung dokumentiert sein. Die Folk-Programme enthalten derzeit ausdrücklich als provisorisch deklarierte CC0-Lokaltitel; der Ausbau zu authentischer schwedischer Folklore und alpenländischer Blasmusik erfordert zusätzliche Originalaufnahmen mit dokumentierter Lizenz.

## Rechtlicher Status

Dies ist eine projektbezogene technische Dokumentation und keine vollständig individualisierte Datenschutzerklärung. Vor Veröffentlichung mit tatsächlich eingebautem iFrame oder einem WebView sind Consent-Mechanik, Anbieterangaben, Tracking, Hosting, Verarbeitungsdetails und Impressum juristisch zu prüfen. **Ein SoundCloud-Embed ohne vorherige Zustimmung ist nicht implementiert.**
