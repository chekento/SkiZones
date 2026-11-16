# Dauerhafte frühe Wirtschaftsziele

Der erste und der dritte profitable Betriebstag wurden bisher aus dem rollierenden Finanzverlauf berechnet. Nach 28 weiteren Tagesberichten verschwanden die alten Belege; noch nicht eingelöste Ziele konnten dadurch wieder unerfüllt erscheinen. Weit auseinanderliegende profitable Tage wurden ebenfalls nicht dauerhaft zusammengezählt.

Beim regulären Tagesabschluss wird der Fortschritt nun zusätzlich im optionalen Kampagnenfeld `long_goal_profit_days` gesichert. Es enthält nur eine ganze Zahl von 0 bis 3. Bereits vorhandene Berichte liefern beim ersten Abschluss die belegbare Ausgangsbasis; jeder neue, einmalig abgeschlossene profitable Tag erhöht sie bis zur größten Zielschwelle. Ein Tag ohne tatsächliche Gäste zählt weiterhin nicht. Saisonprämien, Sponsorzahlungen und andere Belohnungen machen einen Betriebsverlust weiterhin nicht zu einem profitablen Tag.

Alte Spielstände benötigen das Feld nicht und erhalten es beim Laden nicht ungefragt ergänzt. Ihr nächster normaler Tagesabschluss übernimmt nur noch vorhandene Belege. Bereits verlorene historische Daten werden nicht erfunden. Ungültige, gebrochene oder nicht endliche Werte werden beim Laden ohne Änderung des aktiven Resorts zurückgewiesen.

Die Belohnungen bleiben unverändert: 1.000 € für den ersten und weitere 1.500 € für den dritten profitablen Tag. Alle bisherigen Einlöse- und Sandbox-Regeln gelten weiter. Der reguläre Finanzverlauf bleibt auf 28 Einträge beschränkt.

23 neue Regressionen prüfen unter anderem 94 abgeschlossene Tagesberichte mit weit getrennten profitablen Tagen, auslaufende Historie, verzögertes Einlösen, JSON-Rundlauf, alte Spielstände, ungültige Werte, wiederholten Tagesabschluss und das feste Bonusbudget. Sie laufen außerdem in der gezielten Ziele-/NPC-Prüfung und in der vollständigen Android-Freigabepipeline.
