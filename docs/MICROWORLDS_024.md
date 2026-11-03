# SkiZones 0.24 – Expressive Themes & Hotel MicroWorlds (Entwicklung)

Diese Architektur baut auf dem offenen 0.23-Entwicklungszweig auf. **Keine 0.24-APK ist bisher freigegeben.**

## Verbindliche Gestaltung

Das bestehende **Alpin-Haupttheme bleibt unangetastet** (Schnee, Höhenraster, Gelände, Spielphysik, gespeicherte Projekte). Alle vier alternativen Themes sollen deutlich unterschiedlicher wirken. Eine Theme-Umschaltung ist rein visuell und darf weder Spielstände, Kosten, NPC-Routen noch Kollisionen verändern.

| Stil | Formen | Licht/FX | Interface/Erfolge | Hotel und Innenräume |
|---|---|---|---|---|
| **Alpin** | bestehende, vertraute Rundungen | bisheriges Tageslicht | klassisch, besser lesbare Reliefschrift | Holz, warmes Licht |
| **Comic** | kräftige, kantige Silhouetten, plakative Flächen | dynamische Kontraste, sichtbare Partikel | comicartiges Farbspektrum, scharfe Facetten | verspielte, sympathische Figuren |
| **Pastell** | weiche Miniaturen, liebevolle Details | sanfter Lichtschein, reduzierte Effekte | helles Relief, dezente Glitzerpunkte | Bonbonfarbene Zimmer, kleine Requisiten |
| **Filmisch** | kantige Felsgruppen, kräftige Schatten, glaubwürdige Materialien | dramatisches Gegenlicht und volumetrisch wirkende Abstufungen | metallische Tiefe, sparsame Highlights | feinere Holz-, Stoff- und Glaswirkung |
| **Winterklar** | kristalline, scharf geschnittene Geometrie | eisige Highlights, klare starke Kontraste | präzise 3D-Konturen | saubere moderne Gestaltung |

### Achievements

- Keine extreme Halbkreis-Schriftführung mehr; höchstens eine sehr sanfte Biegung.
- Lesbarkeit zuerst: ausreichender Kontrast, Schriftgröße abhängig von Anzeigebreite, schattiertes Relief und kontrollierte Effektzahl.
- Kurze Fade-in-/Fade-out-Animation; Achievement-Overlay bleibt durchlässig für Toucheingaben.
- Stilabhängige Kanten, Lichtreflexe, Farben und Extrusion; keine Änderung der eigentlichen Achievement-IDs und Belohnungen.
- Freigabetest: unterschiedliche Titel-/Untertitellängen, alle fünf Themes, Darstellung auf Android-Geräten mit verschieden großen Displays.

### Landschaft

Die sechs vorhandenen Kleinobjekttypen erhalten für die Alternativstile veränderte Formsprachen. Hinzu kommen zunächst **sechs** weitere Varianten (Eiskristalle, gefrorene Wasserfläche, Wegweiser, Winterpflanzen, Felsplatte, Kristallgrat). Das klassische Alpin-Theme behält zunächst seine ursprünglichen sechs Arten.

- Instancing und LOD statt unkontrolliert vieler Einzel-Nodes.
- Sämtliche Details bleiben aus Pisten, Wegen, Liftachsen und Gebäudeflächen ausgespart.
- Die Dekoration darf keine Kollisionen, NPC-Wege oder Höhenwerte verändern.
- Später: Eisbrüche, Schneebrücken, Felspassagen, seltene Naturereignisse, unterschiedliche Schneekristalle, saisonale regionale Assetsets, größere künstlerische Variation pro Tal und Höhenstufe.

## Hotel MicroWorlds – erster spielbarer Baustein

Vorhanden ist ein **eigenständiger Hotelablauf mit fünf Kapiteln**: Anreise, Zimmerbereitstellung, Frühstück, Servicezwischenfall und Abreise. Der Spielablauf liest Hotelbelegung, Sauberkeit und Frühstücksstatus; damit entstehen aus tatsächlichen Hotelparametern passende Situationen.

- Integriert in **Gebäude betreten → Selber spielen**, für alle Unterkunftsarten.
- Ein zusammenhängender Gästetyp mit eigenen Wünschen über fünf Stationen; grafische Szenen wechseln mit dem Kapitel.
- Begrenzt bezahlte Schichten, danach kostenlose Wiederholung; die simulierte Hotelbelegung bleibt durch Training unverändert.
- Persistente Hotel-Geschichten-Erfahrung, Level 1–20, Bestleistung und abgeschlossene Geschichten, ohne neue Speicherstandstruktur.
- Hotel-UI und die Story-Tableaus übernehmen das gewählte Theme.

### PMDD-Bildsequenzen – Integrationsvertrag

Die erste Umsetzung nutzt **prozedural generierte, scharfe, mehrschichtige Illustrationen** mit kleinen Tiefenversätzen. Das ist PMDD-inspiriert, aber noch **keine sensorgesteuerte Parallaxe** und **noch keine Serie extern generierter fertiger PMDD-Bilddateien**.

Das Storyboard hat die Bildbereiche:

1. `arrival`: verschneite Ankunft und warme Rezeption, einladende Figuren
2. `room`: Zimmerbezug, Fenster mit Bergtiefe, Gepäck und liebevolle Details
3. `breakfast`: Frühstück in Morgenstimmung mit Miniaturbuffet und Gästen
4. `service`: freundlicher Reparatur-/Serviceeinsatz statt abstraktem Quiz
5. `farewell`: gelungene Abreise, zufriedene Familien, Schnee vor dem Hotel

**Drop-in-Dateiformat:** `res://assets/hotel_story/<theme>/<scene>.webp`. Je fünf Szenen und fünf Themes ergeben 25 separate, theme-treue Bilder. Alle werden mit konsistenter Kamerageometrie, klaren Vorder-, Mittel- und Hintergrundebenen, durchgehender Schärfe und konsequentem PMDD-Tiefenaufbau gestaltet. Bis die finalen Bilder vorhanden sind, zeigt die Engine automatisch das prozedurale Tableau. Die finale Bildserie ist ein offener Kunstproduktionsschritt, keine bereits erledigte Umsetzung.

## Ausbau zum vollständigen kleinen Hotel-Tycoon

Der jetzt integrierte Kapitelablauf ist **nur die erste spielbare Etappe**. Die folgende Tiefe ist als explizite Roadmap festzuhalten:

- **Rezeption und Buchung:** dynamische Gästegruppen, Anreisezeiten, Room-Typen, Wunschlisten, Buchungsänderungen, kleine Zwischenfälle.
- **Zimmer und Housekeeping:** echte Zimmerzustände und Raumpläne, Reinigungsrouten, Ausstattung und Abnutzung, Wäsche, Defekte und Reparaturtermine.
- **Personal:** Schichtplanung, Qualifikation, Wege, Pausen, Zufriedenheit, Engpässe und Personaltraining.
- **Gastronomie im Hotel:** eigener Frühstücksraum, Buffetlogistik, Einkaufs-/Bestandsmanagement, Allergiewünsche und Qualitätskontrolle.
- **Gästebeziehungen:** wiederkehrende Personen, individuelle Bewertungen, Freundlichkeit, sichtbare Emotionen, Story-Events und Folgen für Buchungen.
- **Gebäudeentwicklung:** unterschiedliche Hotelklassen, reale Ausbaustufen, SPA-, Familien-, Luxus- und Business-Schwerpunkte, visuelle Innenraum-Upgrades.
- **Kettenmanagement:** gemeinsame Markenstandards, Eigenheiten einzelner Häuser, Konkurrenz, Preisstrategien, Kennzahlen und Reputation.
- **Zwischensequenzen:** kurze, optionale PMDD-Panorama-Szenen mit klarer Skip-Funktion; keine Blockade des Hauptspiels.
- **Wirtschaft:** Preis- und Nachfragekurven, Betriebskosten, Renovierungen, Servicequalität, Tagesreport und nachvollziehbares Balancing.

Ziel: Viele kombinierbare Spielsituationen statt fünf immer gleicher Quizfragen. Die Story wird mit der realen Wirtschaft verknüpft, ohne dass man Minispiele spielen **muss**, um ein funktionierendes Resort zu betreiben.

## Freigaberegeln

1. 0.23 muss seine Lifecycle- und Android-Signaturtests bestehen, bevor dieser Zweig als neue Preview freigegeben wird.
2. Godot-Skriptimport, Hotel-/Landschafts-/Achievement-Tests, gerenderte Vergleichsbilder und Android-Update-Test sind Pflicht.
3. Kein eigenes 0.24-Release erzeugen, solange Visual QA, Speicherrückwärtskompatibilität und Performance nicht bestätigt sind.
