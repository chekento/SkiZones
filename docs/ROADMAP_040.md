# SkiZones 0.40 – Alpine Renaissance

> **Entwicklungsplan ab 8. November 2026.** Dieser Entwicklungszweig ist kein veröffentlichter APK-Release. **v0.39.1** hat Vorrang bis GitHub den validierten ARM64-Download freigibt. Keine 0.40-Arbeit darf den laufenden main-Release-Workflow abbrechen.

## Leitidee

0.40 soll sich sichtbar wie der nächste große SkiZones-Abschnitt anfühlen: ein erwachsener, stimmungsvoller, inhaltlich dichter und mobil intuitiver Skiresort-Tycoon. Keine bloßen Schaltflächen oder Attrappen – Anzeigen basieren auf echten Spielwerten, jede Aktion ist anklickbar, alte Karrieren bleiben erhalten.

## Erste konkret implementierte Bausteine (Entwicklungszweig)

1. **Bergleitstand:** neuer Ressort-Büro-Reiter mit Live-Gästezahlen, Liftauslastung, tatsächlich registrierten Reparaturen/Personallücken, vier Gästebedürfnissen und nach Dringlichkeit geordneten Handlungsoptionen. Kein fiktiver KI-Score oder neue Speicherdatei.
2. **Interaktive Betriebskarte:** reale Liftstationskoordinaten, relative Warteschlangengröße, Personaldefizite und Defekte als anklickbare farbige Markierungen; antippen öffnet das vorhandene Anlagenmanagement.
3. **Gebäudekatalog 2.0:** eine einzelne Spalte auf schmalen Handys, Touch-geeigneter Filterbereich, vier Sortierarten, baubare Elemente und getrennte Standortaktion. Eine Portable Toilet als Kaufoption; alte Toilettenmodelle bleiben für Save-Kompatibilität.
4. **Zweisprachigkeit und QA:** DE/EN-Texte, unitäre Diagnosetests, gerenderte Handy-/Desktop-Prüfung mit eigenen GitHub-Actions und Screenshots.

## Große 0.40-Ausbaustufen – geplant, nicht als umgesetzt behauptet

### A · Premium Alpine World
- Natürliche Schneedecken, differenzierte Wege/Pistenübergänge, glaubwürdige Relief- und Beleuchtungsstufen, animierte Dorfdetails und harmonisierte Gebäudestile.
- Zustand und saisonaler Anlass sollen auf Assets erkennbar sein; keine Bildschirmpartien ohne nützlichen Inhalt.
- Qualitätsprofile per Gerät und messbarer Android-Budgetrahmen.

### B · Gäste und Resort-Geschichten
- Familien-/Freundesgruppen mit nachvollziehbaren Entscheidungen, Hotel- und Restaurantbesuchen, Wärme-, Essens- und Toilettenbedürfnissen.
- Tages-/Nachtübergänge mit nachvollziehbarer Besucherreise, keine Zwangs-Teleportation oder unendliche Warteschlange.
- Heatmap- und Leistandsmeldungen aus aktuellen statt geschätzten Zuständen.

### C · Management und Wirtschaft
- Nachvollziehbarer Betrieb mit Hotel, Gastronomie, Nachtleben, Sanitär, Rettung, Personal, Transport und Instandhaltung.
- Konkrete Kostenursachen, echte Szenariokennzahlen, Bauempfehlungen mit offengelegter Berechnung und nicht nur behauptetem ROI.
- Direkter Zugang zu Funktionen, keine zentrale Aktion am Ende eines endlosen Textmenüs.

### D · Gestalten, Events und Spieltiefe
- Visuell einheitliche Hotel-/Gebäude-Upgradetrees und klare Vorschau von tatsächlichen Asset-Stufen.
- Weihnachts-/Silvesterplakate und passende wechselnde Kampagnen; echte interaktive Veranstaltungen und freiwillige Minispiele.
- Mehr Kamera- und Photo-Tour-Optionen ohne Performance-Spitzen.

### E · Qualitätssicherung / Release Gate
- Historische Spielstände (ab den ersten Releases), freie und Karriere-Slots, Szenarien, kaputte Primärdateien und Backups.
- Android ARM64, updatefähige Signatur, Android 11/16-Lifecycle, keine Datenlöschung, Grenzen der Speicherdatei dokumentiert.
- Deutsche und englische UI auf 360–420 px, Tablets und Desktop; Screenshots, Benchmark und alle Geschäftsregeln automatisiert geprüft.

## Nicht verhandelbare Architekturregeln

- **Kein Spielstand-Bruch:** neue reine Analyse-/UI-Module benötigen keine geänderte Save-Version. Änderungen am Format nur mit expliziter Migration.
- **Keine erfundenen Erfolgsmeldungen:** Entwicklungsbranch, bestandener Test, APK-Artefakt und veröffentlichtes GitHub-Release sind vier unterschiedliche Zustände.
- **0.39.1 bleibt stabil:** 0.40-Commits erfolgen ausschließlich auf dem Feature-Branch, nicht auf main.
