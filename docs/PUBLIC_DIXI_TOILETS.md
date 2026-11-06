# SkiZones – Eigenständiger öffentlicher Toilettenmanager (Dixi-Mod)

Stand: 6. November 2026 · Korrektur der ursprünglichen Abstimmung vom 5. November 2026

## Verbindliche Anforderungen aus der bisherigen Projektbesprechung

**Kein Hotelmodul.** Hotels und Restaurants haben bereits eingebaute, regulär genutzte Toiletten. Diese sind im Besuch/Komfort enthalten. Die neue WC-Verwaltung gilt **ausschließlich für öffentliche Sanitäranlagen**. Historische `sanitation`-Keys aus Vorabständen bleiben für die Datenmigration lesbar, werden aber nicht länger durch den Hotel-Simulator aktiviert oder verwaltet.

- Start mit einer günstigen, blauen, einzeln platzierbaren Dixi-Kabine und anderen mobilen WCs.
- Stufenweise vom Dixi-WC zu Container, alpinem WC-Haus und Luxus-Sanitärzentrum. Mindestens **fünf unverwechselbare, echte Assets** (nicht einfach ein Gebäudesymbol mit anderer Farbe) – auch in sämtlichen Theme-Varianten und mit saisonaler Winter-/Weihnachts-/Silvesteroptik.
- Eigenständige öffentliche WC-Anlagen mit tatsächlichen Servicebesuchen, Belegung/Kapazität, Tankfüllstand, Entleerung, Hygiene, Reinigung, Frost-/Winterisolierung und Unterhaltungskosten.
- Gäste haben wesentlich häufigeren **Harndrang** als **Stuhlgang**. Getränke steigern den Harndrang; Restaurants und Hotels stellen ihre bereits vorhandenen Toiletten bereit.
- Bei Unterversorgung suchen Gäste gegebenenfalls Wald/Pistenrand auf. Dabei entstehen **sichtbare, zeitlich verfallende gelbe Spuren im Schnee**. Dies muss als echte Szene und Animation implementiert und getestet werden – nicht nur eine textliche Statistik.
- Eigenständiger Technologie-/Forschungszweig mit **Zielumfang 100 echten Freischaltungen**. Jede Freischaltung benötigt wirtschaftliche oder spielerische Wirkung, nicht bloß eine dekorative Karte. Forschung, Baustufen, Servicequalität, Winterfestigkeit und Kosten müssen ausgewogen bleiben.
- Preis-, Material-, Personalkosten, Versorgungshäufigkeit, Hygiene, Auslastung und Upgrade-Folgekosten in die bestehende Betriebsrechnung integrieren. Mobile Toiletten dürfen günstig sein, jedoch nicht langfristig durch ein einzelnes kostenloses WC den gesamten Berg versorgen.

## Implementierungsstand in PR #83

**Grundsystem 0.38 in Bearbeitung (nicht freigegeben):** fünf öffentliche Bauobjekte (`wc_dixi`, `wc_cabin`, `wc_module`, `wc_house`, `wc_luxury`); eigenes `src/core/public_wc.gd` mit Hygiene, Tank, Reinigung, Entleerung, täglicher Alterung, Frostschutz; eigenständiges WC-Betriebsfenster, WC-Servicepersonal als Option, zusätzliche Forschungsprojekte und WC-Gästebedürfnisse. Bestehende Hotel- und Restaurant-WCs bleiben enthalten, keine neue `wc_public`-Eigenschaft an den Gebäuden. Die neuen Dateien erhalten eigenständige Simulationstests.

**Noch nicht vollständig verwirklicht und nicht behaupten:** alle 100 Technik-Freischaltungen; umfassende Balancing-/KI-Personalautomatisierung; sichtbare Wald-/Pistenrand-Notdurft mit gelben Spuren und deren zuverlässiges Verblassen; umfassende manuelle Android-Interaktions-, Performance- und saisonale Asset-Prüfung über alle Themes. Diese Punkte sind keine Freigabebehauptungen und bleiben konkret überprüfbare Features.

**Spielstandschutz:** Vorhandene Originale nicht überschreiben. Pflichtprüfungen: 0.19 und 0.27 Altsaves, 0.36/0.37 Hotelzustände, freie Spielstände, Sanitärzustände, vollständige Korruptionsprüfung und Android-Upgrade ohne Datenverlust.

## Freigabekriterien

1. Öffentliche WCs lassen sich real bauen, korrekt an Wege anbinden und werden von Gästen gezielt aufgesucht; Hotels/Restaurants benutzen weiter ihre internen Toiletten.
2. Aktionen ändern tatsächliches Budget, Tank, Hygiene und Verfügbarkeit; ungültige Forschungs- und Serviceaktionen werden zuverlässig verhindert.
3. Unterschiedliche WC-Größen und Grafikstile sind sichtbar, ohne Baugeometrie oder alte Speicherstände zu beschädigen.
4. Gästezustände überleben Save/Load; ältere Spielstände können ohne WC-Felder geladen werden.
5. Kein Android-Release vor erfolgreich abgeschlossenen QA-/Build-Checks; erst danach Version und Download-Banner aktualisieren.
