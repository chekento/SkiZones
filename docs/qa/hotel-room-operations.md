# Einzelzimmer und Etagenplan – implementierter Entwicklungsstand

Die Hotelverwaltung verwendet echte, feste Zimmerreservierungen für tatsächliche Resortgäste. Bestehende Häuser und Spielstände ändern sich erst, wenn der Spieler die Einzelzimmerverwaltung ausdrücklich aktiviert.

- Einzelpersonen und Familien buchen reale Zimmer; Familien behalten ihre Reservierung auch beim Aufteilen in einzelne sichtbare NPCs.
- Nach Abreise werden ihre Zimmer schmutzig und sind erst nach Reinigung wieder verfügbar. Gesperrte Zimmer können nicht neu gebucht werden. Belegte Zimmer können weder gesperrt noch versetzt werden.
- Manuelle Reinigung kostet genau 8 € pro tatsächlich schmutzigem Zimmer. Die vorhandene Sammelreinigung berechnet nur erforderliche Zimmer und verändert keine belegten Zimmer. Wiederholte Aktionen buchen keine doppelten Kosten.
- Automatische Reinigung arbeitet alle 15 Spielminuten mit der tatsächlichen Kapazität des anwesenden Hotelteams. Unbesetzte Häuser reinigen nicht. Der bestehende Reinigungsvertrag deckt den Aufwand; keine doppelte Gebühr. Selbstbediente Unterkünfte nutzen den bestehenden externen Reinigungsvertrag.
- Der interne Plan bietet bis zu 20 Etagen und 36 Positionen je Etage. Eine freie Zimmerposition kann für 250 € verändert werden. Neue Betten entstehen ausschließlich durch einen echten Gebäudeausbau, nicht durch Verschieben.
- Reservierungen, Schmutz, Sperrungen, Positionen und Dienstzeit überstehen Speichern/Laden; doppelte Koordinaten, ungültige Reservierungen und zukünftige Reinigungszeiten werden atomar abgewiesen.
- Die Raumübersicht passt ihre Spaltenzahl an die tatsächliche Seitenbreite an. Beschriftungen haben Tooltips; Reinigungs-, Freigabe- und Umbauaktionen sind direkt zugänglich. Alle neuen Texte sind deutsch/englisch vorhanden.

Die vollständige externe 3D-Flügelarchitektur, freie Außenanbauten und 100 Hotelforschungen sind damit noch nicht fertiggestellt. Dieser Stand ergänzt die bestehende reale Hotelwirtschaft um Zimmerbetrieb und einen internen Etagenplan.

## Prüfung

28 lokale Modellprüfungen bestanden. 39 gerenderte Touch- und Layoutprüfungen für Deutsch/Englisch bei 360×740, 420×860 und 740×360 bestanden. 8 zusätzliche Kompilierungsprüfungen bestanden. Bildschirmaufnahmen liegen unter `build/qa/hotel-rooms-*.png` und werden im CI als Artefakte archiviert. Eigenständiger Workflow prüft Buchungen, Kosten, Alt-Hotels, Familien, vollständige Übersetzung und tatsächliche Telefonbedienung.
