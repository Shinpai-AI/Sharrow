# Goldjunge Patch History (Temp Session Log)

> Kurzprotokoll der aktuellen Tests. Nach Abschluss wieder entfernen!

## 2025-09-30 — Late Night Prime Trial
- Eingeführt `TestModeNewsObjectionOnly` (Goldjunge.mq5:141) → News blocken Trades nur bei Gegensignal. Standard `false`.
- `BreakEven` erweitert um Profit-Trigger (`BreakEvenProfitThreshold`) und Fehler-Logging (Goldjunge.mq5:1466 ff.).
- `Goldjunge-state.log` auf Append umgestellt (`FILE_READ | FILE_WRITE`).
- StateLog ergänzt um `BREAK_EVEN_FAIL` Einträge (inkl. Details & Error-Code).
- Neue Debug-Prints für Break-even Fehler in MT5-Terminal.

**Reminder:** Nach erfolgreichem Testphase die Test-Inputs und Debug-Logs wieder entfernen/neutralisieren!

## 2025-10-02 — TP Swing Mode
- Neuer Input `TpSwingMode` (default `false`) aktiviert ein stufenweises TP-Trailing.
- Swing-Logik speichert TP-Abstand aus Rules/Defaults, hält Ziele nur intern und zieht bei jedem Treffer den SL auf das erreichte Level.
- Nächte Ziele werden durch Add/Sub des ursprünglichen TP-Abstands gebildet; State persistiert via `GlobalVariable` pro Symbol.
- OnTick überprüft Hits, schützt gegen Stop-Level-Fehler und loggt Schritte über `TP_SWING_*` Events.
- Market-Orders setzen im Swing-Mode keinen physischen TP mehr, initialisieren jedoch den Swing-State mit dem berechneten Ziel.

## 2025-10-02 — Night-Break (Serverzeit)
- Input `NightStopEnabled` (`false` default) blockiert neue Trades zwischen 22:00–06:00 Serverzeit.
- `IsNightStopActive()` prüft die Sperre via `TimeTradeServer()` und deckt das Mitternachtsfenster korrekt ab.
- Trade-Pipeline stoppt Entries bei aktiver Sperre, protokolliert `StateLog("NIGHT_STOP", …)` + Debug-Hinweis.
- Bestehende Positionen, Break-even und TP-Swing laufen unverändert weiter.

## 2025-10-02 — Quality Threshold Calibrator
- `Train-KI-Bot.py` erstellt symbol-spezifische Baselines aus realen Signalverteilungen (Median/Q60/Q30).
- Kleine ±5/10/15%-Schritte testen Profit & Winrate direkt über `simulate_trades`; Default-Grenzen dienen nur als Clamp.
- Keine Trades-Merges mehr nötig, `stoch_sell_min` bleibt global; Logging zeigt Profit/Winrate/Trades an.
- Export bleibt kompatibel, Goldjunge zieht Werte über `LoadOptimizedParameters` automatisch.
- `Goldjunge.mq5` liest Rules jetzt mit `FILE_ANSI`, damit MT5 die neuen Schwellen zuverlässig übernimmt.
