# SkiZones 0.25 – lineare Hotelmodule und jährlicher Winterzauber

**Entwicklungsentwurf. Keine freigegebene 0.25-APK.** Der Zweig folgt auf die noch offenen PRs 0.23 (#18) und 0.24 (#19).

## Lineare Hotelkomplexe

Ein Hotel dient als Ausgangspunkt einer **linearen Kette**. Bereits errichtete, benachbarte Dorfgebäude können am **letzten Modul** für 4.500 € Verbindungskosten angedockt werden. Maximal acht Module, eine Verbindung nur bei höchstens 24 m Fassadenabstand. Eine frühere Stelle kann nur nach dem rückwärts gerichteten Lösen aller späteren Module entfernt werden.

Die Grundauswahl umfasst **Pool, Wellness/Spa, neues Fitnessstudio, Restaurant, Pizzeria, Kakao, Bar, Souvenirshop, Uhrmacher und Handwerksstube**. Diese Gebäude bleiben eigene echte Betriebe mit Personal, Besuchern, Einnahmen und Betriebskosten; sie erhalten eine begrenzte Hotel-Attraktivitätswirkung. Eine schematische Darstellung in der Hotelverwaltung und einfache verglaste, nicht-kollidierende 3D-Verbindungsstücke machen die lineare Kette verständlich.

**Nicht enthalten:** echte begehbare Innenverbindung, Gäste-Routing durch die Verbindung, frei editierbare Hotelgrundrisse, gemeinsame Personal-Förderanlage oder dedizierte 3D-Hotelsteuerung. Diese sind auf Issue #21.

## Neue alpine Kleingeschäfte

- **Souvenirshop:** geschnitzte Souvenirs, Kuhglocken, Postkarten, Schneekugeln
- **Uhrmacher:** traditionelle Uhren und Reparaturen; auffälliges Zifferblatt am 3D-Gebäude
- **Handwerksstube:** Holzfiguren, Werkzeug und regionale Handarbeit
- **Fitnessstudio:** Sport- und Trainingsbereich als Hotelmodul oder selbstständiger Ort

Alle vier erscheinen im überarbeiteten Dorfkatalog, besitzen eigene kleine Building-Previews, Gebäude-3D-Details, NPC-Serviceparameter und eine freiwillige Aktivität. Weiterführende eigene Mikrosimulatoren sind weiterhin späterer Entwicklungsumfang.

## Realer Jahreskalender (wiederholt sich unabhängig vom Spieljahr)

- Ab **1. Dezember**: Adventskalender mit 24 Türchen; jeweils am entsprechenden Kalendertag geöffnet.
- Türen der vergangenen Tage bleiben **bis einschließlich 31. Dezember** einlösbar.
- **6. Dezember**: Nikolaus-Sondergeschenk. **24. Dezember**: großes Weihnachtsgeschenk.
- Gutschrift in begrenzten **Wintertalern** statt unbegrenzter Echtgeld- oder Resort-Prämien.
- Einmal pro Tür **und pro tatsächlichem Kalenderjahr**. Ein neues Jahr öffnet neue Türchen; ältere Karrieren oder freier Spielmodus können keine doppelten alten Belohnungen erzeugen.
- **25.–30. Dezember:** feierliche Winterszenerie, auch nachdem alle Türchen geöffnet wurden.
- **31. Dezember:** Silvester mit Uhr-Countdown; **1. Januar, 00:00–01:00:** einmaliges jährliches Neujahrsereignis.
- **Ab 2. Januar:** Rückkehr zum normalen Theme, auch nach weiter laufenden Spielständen.
- Der Kalender wird **durch die lokale Gerätezeit** bestimmt, nicht durch Tageswechsel oder Zeitraffer der Skigebietssimulation.
- Der Kalenderstand liegt unabhängig von der Karriere in `user://skizones_annual_festival.cfg` und wird atomar geschrieben. Keine Serverzeit: Gerätezeitänderungen und Mehrgeräte-Exploits sind ohne externen Synchronisierungsdienst nicht vollständig auszuschließen.

### Standort / Privatsphäre

**Keine Standortberechtigung wird angefordert.** Die lokale Geräte-Zeitzone reicht für einen lokalen Silvester-Countdown; der Spieler muss bei Reisen die Geräte-Zeitzone korrekt eingestellt haben. **Standortbasierte Zeitzonen-Synchronisierung mit ausdrücklicher Android-Einwilligung, standardmäßig OFF, ist noch nicht implementiert.** Ein tatsächlicher Standortzugriff wird erst nach Integration und Test einer geeigneten Android-Location-Bridge angeboten. Diese Anforderung steht in Issue #21.

## Weihnachtliche 3D-Assets

Erste originale, prozedurale und nicht-kollidierende Modellfamilien: geschmückter Baum, Schneemann, Geschenkestapel, Laternen, Holzstern, Girlande, Weihnachtsmarktstand, Uhrschild, Glocke und einfache Silvester-FX. Farben und Akzente folgen den fünf Stilrichtungen, das klassische Alpin-Theme bleibt im Grundspiel unverändert. Die Dekorationen werden saisonal an geeigneten freien Orten und Dorfplätzen automatisch dargestellt. Zusätzlich gekaufte Dekorationen erscheinen an weiteren Stellen. Bei Jahreswechsel werden sie automatisch ein- bzw. ausgeblendet.

**Grenzen:** Es sind erste reduzierte Assetformen, noch keine umfangreiche handgebaute Weihnachtswelt. Frei wählbare Positionen, Wintermarkt-Verkaufslogik, NPC-Geschenkübergabe, Familienfeiern am Baum, echte Mitternachts-Partygruppen und deutlich komplexere Silvester-FX folgen. Keine Darstellung soll als fertig beworben werden, bevor sie im Android-Renderer tatsächlich geprüft wurde.

## Abnahme

1. Alle vorhandenen 0.19–0.24-Karrierestände und Android-Identitäten erhalten.
2. Hotelverbund darf nie eine unendliche Kette, doppelte Buchung, unechtes Zimmer oder nicht erreichbares Gebäudemodul erzeugen.
3. Keine neuen Kollisionen oder Teleport-Routen durch rein visuelle Tunnel.
4. Advent, Nikolaus, Heiligabend, Silvester, Neujahr und 2. Januar einschließlich Schaltjahren mit simulierten lokalen Datumssätzen testen.
5. Prüfung sämtlicher fünf Grafikstile und Story-/Menu-Screens im Android-Kompatibilitätsrenderer.
6. Vollständige CI, Lifecycle 30/36, alte Spielstände und Signaturkontinuität **vor** APK-Veröffentlichung.
