# Portable Toilet – eigenständige öffentliche Toilettenentwicklung

Stand: 7. November 2026. Verbindliche Präzisierung des Nutzerauftrags; Umsetzung im Kandidaten **0.39.0**. Die frühere Bezeichnung im Dateinamen bleibt zur Link-Kompatibilität erhalten.

## Ein Kaufobjekt, fünf Ausbaustufen

Im sichtbaren Baukatalog und in der Baupalette wird ausschließlich **Portable Toilet** als kleines Startmodell angeboten. Die vier größeren ehemaligen Einzelkaufobjekte sind keine neuen Kaufmöglichkeiten mehr. Ihre internen IDs bleiben für alte Spielstände erhalten. Vorhandene Gebäude, Personalzuordnungen, Gästeziele und Wartungszustände werden nicht entfernt.

| Stufe | Gestalt | Kabinenplätze | Tankvolumen | Grundbetrieb pro Tag | Ausbaukosten zur nächsten Stufe |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | Kleine blaue Portable Toilet | 1 | 18 Nutzungen | 15 € | 1.750 € |
| 2 | Winterkabinen | 2 | 34 Nutzungen | 28 € | 7.200 € |
| 3 | Sanitärmodul | 4 | 72 Nutzungen | 80 € | 14.700 € |
| 4 | Alpines Sanitärhaus | 8 | 150 Nutzungen | 180 € | 40.500 € |
| 5 | Premium-Sanitärzentrum | 16 | 340 Nutzungen | 420 € | Endstufe |

Startpreis: 850 €. Kosten sind Grundwerte vor Forschung; Personal, Reinigung, Entleerung und die bestehenden allgemeinen Gebäudeanteile werden zusätzlich bilanziert. Ausbau behält die Gebäude-ID und den Zustand. Tatsächliche Meshes, belegte Fläche und Eingangsposition wachsen zusammen. Die vollständige Standort-/Zugangsprüfung findet vor der Bezahlung statt; bei Platzmangel wird nicht ausgebaut und nichts berechnet. Freier Aufbau benötigt keine Forschung und kein begrenztes Budget, berücksichtigt aber weiterhin freie Bauflächen.

Materialien und Silhouetten entwickeln sich von Kunststoff über Metall und Holz bis zum Premiumgebäude mit Vordach und begrüntem Dach. Alle zehn Grafikstile verwenden die jeweilige Ausbaustufe; Monochrom erhält eigene Liniengeometrie mit Türen, Dach und Vordach.

## Eigener Entwicklungsbaum mit 100 wirksamen Projekten

Zehn Zweige mit je zehn Projekten: Ausbau/Architektur, Tankvolumen, Hygieneverbrauch, Wartungslogistik, Haltbarkeit, Besucherfluss, Reinigung, Entsorgung, Betriebsressourcen und Frostschutz. Projekte haben Geld-/Punktekosten, Dauer und echte Voraussetzungen. Die fünf bekannten IDs `wc_logistics`, `sanitation`, `wc_winter`, `wc_hygiene` und `wc_comfort` bleiben gültig. Der öffentliche Zweig benötigt keine Hotel-Meisterklasse.

Die fünf Bauformen werden einzeln ausgebaut; Forschungen verbessern die vorhandenen öffentlichen Anlagen dieses Resorts. Fortschritt und laufendes Projekt werden im bestehenden Karrierezustand gespeichert. Die Effekte verändern tatsächliche Tankkapazität, Hygienealterung, Belegungszeit, Servicekosten, Tagesbetrieb, Frostbelastung/Isolierung oder die geprüften Ausbauangebote. Keine Bonuswirkung wird allein durch den freien Baumodus erfunden.

Bedienung direkt an der Anlage: Reinigung, Entleerung, Ausbau und Entwicklungsbaum stehen oberhalb der scrollenden Seiten. Die kompakte Stufenübersicht zeigt alle fünf Formen. Im Baum lassen sich die zehn Zweige auswählen; Voraussetzungen, Kosten und Status stehen an jedem Projekt. Erfolge überdecken die Verwaltung nicht und werden nach dem Schließen weiter angezeigt.

## Getrennt von Hotels und Restaurants

Hotels und Restaurants benutzen weiterhin ihre integrierten Toiletten. Der öffentliche Manager ist kein Hotelmodul. Die bisherigen realen WC-Besuche, Familiennutzung in Durchgängen, endliche Kabinenkapazität, Ankunftswarteschlangen und Sanitärmitarbeiter samt Abwesenheit bleiben aktiv.

## Prüfstand und verbleibende Aufgaben

Siehe [0.39-Prüfbericht](qa/039-portable-toilet.md). Die Modell-/UI-/Original-Save-Prüfungen werden um Kaufbeschränkung, alle 100 Entwicklungen, echte Ausbauknöpfe, größere Kollisionsflächen, alte Einzelanlagen und sämtliche Stufen-Meshes erweitert. Veröffentlichung setzt vollständige CI und Android API 30/36 voraus.

Weiter offen: sichtbare Notdurft an Wald-/Pistenrändern mit verfallenden gelben Spuren; weitergehende individuelle Servicefahrzeuge und Personalautomatisierung; repräsentatives Mehrwinter-Balancing aller Karten/Startprofile; vollständige manuelle Android-Performance- und Saisonabnahme. Diese Punkte werden nicht durch die Zahl der Forschungsprojekte als erledigt gezählt.
