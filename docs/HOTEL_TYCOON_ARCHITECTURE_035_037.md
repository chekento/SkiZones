# SkiZones – Hotel Tycoon II: technischer Architekturentwurf (0.35–0.37+)

> **Status:** Implementierungsdesign, kein fertig integriertes Feature. Die öffentliche APK 0.33.2 ist freigegeben; 0.34 wird separat geprüft. Dieser Entwurf darf weder den v0.34-Release verzögern noch die vorhandenen Hotel-/Karrierespeicherstände ändern. Detaillierte 100 Freischaltungen: [Issue #69](https://github.com/chekento/SkiZones/issues/69).

## 1. Verifizierter Bestand und Integrationsgrenzen

- `src/core/hotel_complex.gd`: bestehende **lineare Kette** bereits gebauter Dorfobjekte; acht Module, 24 m Fassadenabstand, 4.500 € Verbindungskosten. **Nicht ersetzen** oder beim Laden umschreiben.
- `src/core/guest_lodging.gd`: Hotelzimmer bislang rechnerische Kapazität (`rooms × level`) ohne einzelne belegbare Raum-IDs; Gäste besitzen `lodging_id`, `stay` und Hotelrückweg. Die neue Raumverwaltung muss hier mit den existierenden `party_id`-, `group_size`- und Wachlogiken kompatibel werden.
- `src/core/hospitality.gd`: bestehende `hotel`-Settings `price, comfort, breakfast, auto_clean, cleanliness, rating, chain`, tatsächliches Preis-/Kosten-/Buchungs-/Marketingmodell. Keine doppelten Einnahmen durch parallele Simulation.
- `src/core/hotel_microworld.gd`: fünf Storykapitel bleiben als optionale Unterhaltung, nicht als Ersatz einer echten Hotelwirtschaft.
- `src/core/progression.gd`: vorhandene Resort-Forschung `hospitality` separat halten; neuer Hotel-Tree **H001–H100** erhält eigenen ID-Namensraum, Toilet-Tree getrennt (`#67`).
- `src/core/save_store.gd`: strikt prüfsummenbasierte Altspielstand-Wiederherstellung; bestehende Karrieren 1–4, freie Plätze 1–4 und Szenarios nicht durch neue Hotels überschreiben.

## 2. Neue Architektur – additive, validierbare Subsysteme

| Eigenes Modul (geplant) | Zuständigkeit | Integriert mit |
|---|---|---|
| `src/core/hotel_layout.gd` | Grundrisse, Modul-Raster, Stockwerke, Portale/Flure und begehbare Graphverbindungen | `HotelComplex`, `FootNetwork`, `Terrain` |
| `src/core/hotel_rooms.gd` | Dauerhafte Einzelzimmer-IDs, Belegungszustände, Zimmerklassen, Kapazitäten, Reservierungen | `GuestLodging`, `Hospitality` |
| `src/core/hotel_staff.gd` | Rezeption, Housekeeping, Wäsche, Frühstück, Technik, Dienstwege/-zeiten | `Operations`, `Recruitment` |
| `src/core/hotel_economy.gd` | Kosten, Erlöse, Warteschlangen, Auslastung, ADR/RevPAR, Risiken und Überschüsse | `Hospitality`, `Operations` |
| `src/core/hotel_research.gd` | 100 Freischaltungen, Kanten, Kosten und mechanische Effekte, nie reine Dummy-Knoten | `Progression`, `SaveStore` |
| `src/ui/hotel_planner.gd` | Touch-Editor, Gebäudestufen, Ghost-Module, Undo/Redo, Etagenwechsel | `BuildingBrowser`, `FloatingWindow` |
| `src/ui/hotel_dashboard.gd` | Buchungslage, Betrieb, Personal, Belegung, Heatmaps, Modulverwaltung | `OperatingPages`, `Management` |
| `src/ui/hotel_tech_tree.gd` | Verzweigter, pan-/zoomfähiger Forschungsbaum mit realen Effekten | `HotelResearch`, `VisualStyles` |
| `src/world/hotel_asset_variants.gd` | Instanzierbare Außen-/Innenraumklassen, Theme- und Saisonlayer, LOD | `VisualStyles`, `AnnualFestival` |

### Datenmodell: additive Felder statt schädlicher Formatübernahme

Bestehende `building.hotel`-Konfiguration bleibt erhalten. Erweiterungen ausschließlich als optionale, typgeprüfte Unterstruktur des **eigenen Hotelgebäudes**; keine Felder auf Nicht-Hotels.

Beispiel eines vorgeschlagenen Schemas (Konzept, **kein vorhandenes Save-Format**):

```gdscript
building["hotel_sim"] = {
  "schema": 1,
  "layout": [
    {"module_id": "m:1", "kind": "lobby", "floor": 0, "grid": [0, 0], "rotation": 0},
    {"module_id": "m:2", "kind": "room_wing", "floor": 1, "grid": [1, 0], "rotation": 0}
  ],
  "rooms": [
    {"room_id": "room:m:2:01", "class": "double", "beds": 2,
     "status": "vacant_clean", "party_id": 0, "quality": 100}
  ],
  "service_queue": [],
  "last_tick": 0
}
# Research as independent resort progression; never reuse the WC unlock IDs.
model.campaign["hotel_research"] = ["H001", "H011"]
```

**Keine implizite Migration durch bloßes Laden:** Legacy-Bauten müssen zunächst mit alten Kapazitäts-/Hotel-Routinen spielbar bleiben. Erst ein gültiger neuer Plan kann separat gespeichert werden; alle neuen Daten erhalten strenge Werte-/Größenlimits und validierte historische Checksum-Backups.

## 3. Zimmerzustandsmaschine

```text
frei & sauber → reserviert → belegt → ausgecheckt/schmutzig
                                      ↘ Reinigung zugeteilt
                                        → Reinigung läuft → frei & sauber
             Defekt → gesperrt → Reparatur → Reinigung/Qualitätscheck
```

- **Zimmer-IDs sind stabil**, selbst beim Theme- oder Jahreszeitenwechsel; Bauänderungen dürfen nur leere, unreservierte Module entfernen oder brauchen ausdrückliche Umbuchung.
- Rezeption bucht `party_id`/Zimmer, Housekeeping gibt nach echter Zeit und Ressourcen frei; keine doppelte Zuteilung und keine Instant-Reinigung bei 0 Mitarbeitern.
- Familienzimmer teilen keine Doppelbuchungen. `rooms_used` zählt alte Hotelaufenthalte korrekt, auch während schrittweiser Migration.
- Hotel-Nacht-/Tageswechsel werden idempotent verarbeitet: `last_tick` und Buchungs-ID prüfen, damit Absturz/Resume nicht doppelt kassiert.

## 4. Bauplaner: Geometrie und Gästewege

1. Im Hotel-Inspector **„Hotel erweitern“** wählen, lokales andockendes Grundrissraster erscheint.
2. Modulklasse wählen, drehen, Ebene wählen, anschließen; Ghost-Modell zeigt **echten Grundriss** und Außenfassade im gewählten Theme.
3. Vor Kauf validieren: Terrain, Baufeld, Gebäude-/Pisten-/Liftkollision, durchgehender Flur-/Tür-Graph, Barrierefreiheit und mindestens ein sicherer Ausgang; Etagenwechsel über Treppen-/Aufzugskern.
4. Vorschau von Umbaukosten, Betten/Fläche, Personalbedarf, Wasser-/Energie-/Wäschelast, prognostizierten Zimmer-Einnahmen und Wegzeiten.
5. **Atomic Commit**: erst nach vollständiger Geometrie-, Anschluss- und Kassenprüfung umbauen, dann einmal zahlen und `model._invalidate()`; Undo/Redo im Entwurfszustand ohne neue Buchung.
6. Eigentümer von bestehenden Dorfgebäuden aus `HotelComplex` nicht ändern: bestehende 8er-Kette als externe Betriebe/Connectoren erhalten, nicht heimlich in zusätzliche Innenraum-Meshes konvertieren.
7. Gleiche Weltkoordinaten vor und nach Bauabschluss. Kamera-Werkzeuge und User-Touch auf dem Overlay dürfen nie einen Welt-Baupunkt auslösen.

### Entwurf zu 20 neuen Modulen
Lobby, Standardzimmer, Familienzimmer, Premiumsuite, Treppe/Aufzug, Ski-Trockenraum, Frühstück, Hotelrestaurant, Après-Lounge, Fitness, Sauna, Spa, Pool, Kinderclub, Spielelounge, Hotelshop, Wäscherei, Personaltrakt, Energie-/Heizungsanlage, Panoramawintergarten/Skybar. Sie dürfen bereits vorhandene `pool/spa/fitness/restaurant/...`-Dorfgebäude **nicht duplizieren**: ein integriertes Modul kann entweder ein neuer Innenraum sein oder ein Anschluss zu einem bereits vorhandenen autonomen Betrieb.

## 5. Eigenständiger Hotel-Tech-Tree

- **100 inhaltlich verschiedene** Freischaltungen `H001`–`H100`; zehn Teilbäume zu Architektur, Zimmern, Rezeption, Reinigung, Gastro, Wellness, Personal, Technik, Wirtschaft und Digitalisierung. Der vollständige Knoten-Katalog liegt in [#69](https://github.com/chekento/SkiZones/issues/69).
- Datengetriebene Knotenbeispiele:
  - `H001`: Bau-Tool für echte Hotelmodule freigeben.
  - `H011`: zusätzliche Zimmerklasse zulassen.
  - `H031`: Zimmerstatus frei/belegt/schmutzig sichtbar und in der Belegungslogik wirksam.
  - `H041`: Frühstücksraum mit tatsächlicher Kapazität und Warteschlangenwirkung.
  - `H077`: Energiezähler je Modul aus tatsächlicher Last und Betriebszeit berechnen.
  - `H100`: Luxus-Resort-Komplettausbau mit sichtbaren Modul-/Theme-Klassen.
- Jede Freischaltung hat `requires`, `money`, `research_points`, `days`, `effect_id` und optional `asset_variant`; **keinen Knoten ohne implementierten Effekt als spielbar anbieten**.
- Topologische Prüfung: 100 einzigartige IDs, nur gültige Vorgänger, keine Zyklen, jedes H001–H100 prinzipiell erreichbar; getrennte Savebereiche für Freischaltungen und per-Hotel ausgebaute Module.
- Forschungsbaum modern, auf Smartphones zoombar und scrollbar, Knotenstatus und Abhängigkeiten gut lesbar. DE/EN, alle Themes, keine Pflicht zur Teilnahme an Hotelminispielen.

## 6. Assetproduktion: 750 sichtbare Kombinationen

Basis: **fünf Hauptgebäude-Stufen + 20 Hotel-Modulklassen = 25**, mit **zehn** Spielthemes und **drei** Saisonlooks (Standard, Weihnachten, Silvester). **25 × 10 × 3 = 750** zu prüfende Darstellungskombinationen.

- **Nicht** 750 unabhängige Modelle erzwingen: shared Mesh-Geometrie + deutlich andere Theme-Silhouette/Fassade/Materialien + separater saisonaler Dekorationslayer.
- Standard-Theme: gemütliche Berghütte, Holz, Naturstein, warme Fenster; Monochrom: reduzierte Outline-Modelle; Bauhaus: plakative klare Baukörper; Neon: Glaskonturen/Licht; Filmisch: glaubwürdiges Material/Beleuchtung; weitere Theme-Sprachen mindestens gleich gut unterscheidbar.
- Weihnachten: Kränze, Girlanden, Innen-/Außen-Lichtketten, bespielbare Lobbydeko und Kalender-Plakate auf *allen sichtbaren Hotelmodulen*. Silvester: dezente Festbeleuchtung, Countdown-Displays und Partydekoration.
- Keine neue Kollisionsgeometrie durch reine Saisonlayer; alte Assets/SaveIDs bleiben gleich. Wo bauliche Innenvarianten existieren, Türen und Gästerouten ebenfalls erhalten.
- LOD- und Batch-Grenzen, Instancing, 3D-Look vs. Smartphone-Lesbarkeit, transparente Glasscheiben ohne den Android-GLES3-Pfad unnötig zu überlasten.

## 7. Direkte Verzahnung mit Toilet Tycoon 0.36

Hotels und Restaurants bringen automatisch **integrierte Sanitärkapazitäten** mit, die als öffentliche Erreichbarkeit nur entsprechend Zugänglichkeit und Öffnungszeiten zählen. Externe Mobiltoiletten (#67) werden eigenständig betrieben und nicht als individuell putzbare Hoteltoiletten angezeigt. Ein neues Wellness- oder Zimmermodul erhöht die Gäste-Nachfrage und ggf. intern die WC-Anzahl; der Resort-Sanitärmanager erhält einen aggregierten, deterministischen Kapazitäts-/Bedarfswert. **Keine doppelte Reinigungsrechnung** zwischen Hotel und Toiletten-Manager.

## 8. Fertigstellungs- und Versionsgates

| Schritt | Wirklich funktionierender Umfang | Mindesttest |
|---|---|---|
| **0.35 A** | Hotelplaner (Lobby, Zimmerflügel, Servicekern), erste Zimmer-IDs, Live-Rezeption/Housekeeping, funktionierender Dashboard-Kern, H001–H020 | Grundriss-Kollision, 360×740/420×860, Belegung, Alte-Hotels-Open/Save |
| **0.35 B** | Raum-/Personal-/Kostenwiedergabe vertiefen; erste Build-/Assetstufen je Theme | Touch-/DE-EN-/Theme- und Save-Regressionen |
| **0.36** | Sanitär-Integration mit #67, Erweiterung Forschung und modulare Assetvarianten | interne WC-Kapazität vs. Gäste-Nachfrage, keine doppelte Wartung |
| **0.37+** | 100 funktionale Forschungsnodes, alle 20 Module, vollständige Hauswirtschaft/Technik, 750 Assetdarstellungen | vollständige Techgraph-, Route-, Balance- und Android-Performance-Tests |

### QA-Liste
- [ ] 4 alte Karriereplätze, 4 Freies-Bauen-Plätze, Szenario-Saves 0.19/0.27/0.33.2/0.34 laden ohne Löschzugriff; mit Änderungen neu speichern, zurückladen, und Originaldatei aufbewahren.
- [ ] 1/8/30/100 Zimmer, null Reinigungskräfte vs. ausreichend, schmutzig/belegt/gesperrt, längere Familienurlaube, falsche Reservierungen, Check-in/out und Crash/Resume.
- [ ] Wirtschaftserfassung: Budget nach Um-/Anbau, Zimmerumsatz exakt einmal, keine Doppelzählung integrierter Gastro/Verbundbetriebe, Insolvenz durch Fehlplanung möglich.
- [ ] Hoteltech 100 Knoten statisch und dynamisch auf Reichweite, Effekt und Savevalidierung testen; Forschung darf keine alte Resortforschung überschreiben.
- [ ] Sichtbare Hotel-Theme-/Asset-Matrix per Rendering erfassen, Android API 30/36, GLES/Memory/FPS und Hotspot in dicht bebauten Karten.
- [ ] **Erst nach bestandenen Tests und veröffentlichten APK-Dateien** als implementiert kommunizieren.

Die Produktionsplanung für alle Hotelmodule und den 100er-Tree ist in #69, die Theme-/Saisonasset-Matrix in #68 dokumentiert.
