# SkiZones 0.20: kompakte, belebte Skiorte statt vollständiger Städte

**Klarstellung des Auftrags vom 1. November 2026.** Dies ist der verbindliche Umfang für die Real-Szenarien Braunlage, Filzmoos, Kitzbühel und Seiser Alm. Das Spiel ist ein **Skiresort-Tycoon**, kein Städtebau-Simulator.

## Prioritäten

1. **Kompakte Ortskulisse**: ein erkennbarer Kern um Hotelstandorte und Talstationen. Wenige, gut differenzierte 3D-Modelle für Hotels, Restaurants, Cafés/Snackstände, Après-Ski/Nachtleben und Skischule. Ergänzende Fassaden können gestalterisch fiktiv sein; ein als OSM-basiert ausgewiesenes Objekt muss einen tatsächlichen POI besitzen.
2. **Wirklich nützliche Skibusse**: zunächst Verbindung zwischen Unterkunft und großen Gondel-Talstationen auf belegten, für Busse geeigneten Straßen. Geeignete Haltepositionen aus der Karte ableiten, keine Fantasie-Abkürzungen oder Buslinien als reale Betreiberfahrpläne bezeichnen. Passagierkapazität, Warteschlangen und Gastankünfte erst als implementiert kennzeichnen, sobald sie **im Modell** wirken, nicht nur als fahrendes Mesh.
3. **Mehrtagestourismus**: Hotelkapazitäten, tatsächliche Zimmerzuweisung und bestehende Gäste über Mitternacht erhalten. Tagsüber Ski fahren, abends Gastronomie/Nachtleben und nachts zurück zum Hotel; nur neue Reisegruppen zählen als Neuankünfte. Hotelgäste bleiben über mehrere Spieltage in der Simulation und im Savegame erhalten.
4. **Pistennahe Angebote**: Gastronomie, Hütten und Unterkunftsstandorte entlang oder neben tatsächlichen Pisten/Liften des **gesamten** Skigebietes bevorzugen. Standortkoordinaten werden aus OSM-POIs genommen, aber **ohne Originalnamen** in Spielgrafik und Geschäftsbenennung verwendet. Wo Daten fehlen, keine realen Koordinaten vortäuschen; ggf. klar als Spielplatzierung kennzeichnen.
5. **Straßen als Miniaturkulisse**: nur das für Ortscharakter, Hotel-/Gondel-Verkehr und ÖPNV benötigte Netz prominent rendern; nicht ganze Stadtviertel nachzeichnen. Originaler Straßenverlauf dient zur Orientierung, **nicht** zur Verpflichtung, die komplette Kommune nachzubauen.

## Abnahmekriterien
- Alle vier Real-Szenarien beginnen mit sichtbaren Hotels, Gastronomie, Snackstand, Skischule und Abendangebot. Gemappte OSM-Angebote haben nachvollziehbare Quell-IDs; erfundene Ergänzungen tragen eindeutig eine Spielwelt-Kennzeichnung.
- Relevante Hotel-/Gondel-Strecken sind via Graph nachweisbar und nicht bloß durch zufällige Stops verbunden. Nicht routbare Verbindungen werden nicht erfunden.
- Unterkunftszuweisung und mehrtägige Gäste sind funktional nachgewiesen: kein tägliches Zurücksetzen der Bewohner, kein Überschreiten der Hotelkapazität, Save/Load unverändert.
- Pistennahe Hütten/Restaurants sitzen an belegten Standortkoordinaten, ohne kopierte Markennamen oder Logos.
- Kompakte 3D-Geometrie, begrenzte Sichtweite/LOD, Performance bei 1× und 4× sowie Android-Lifecycle-Tests bestehen.
- Das 0.19-Release bleibt unverändert; 0.20 wird erst nach abgeschlossenen CI- und Android-Tests veröffentlicht.

**Stand:** Aufgabenrahmen beschlossen. Teilfunktionen – OSM-Import, Straßen-/Haltestellengraph, einfache POI-Marker, fiktiver Spielbus, alte Hotel-Buchungsmechanik – existieren bereits, aber diese Kriterien sind ausdrücklich noch **nicht vollständig erfüllt**.
