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

## 2025-10-04 — Parameter Cleanup & Trailing Refresh
- Eingangsparameter logisch gruppiert (Historie, Risiko, Signal, Schutz etc.) und Beschreibungen geschärft (`Goldjunge.mq5:131` ff.).
- Signal-Enum auf Varianten A–E umgestellt; `DescribeSignalMode`, `GetFinalSignal` und Missing-Reason-Logik entsprechend aktualisiert (`Goldjunge.mq5:101`, `Goldjunge.mq5:1958`, `Goldjunge.mq5:2248`).
- TP-Swing inklusive GlobalVariables entfernt, stattdessen neuer pip-basierter Trailing-Stopp (`TrailingStopEnabled`/`TrailingStepPips`) in `HandleTrailingStop()` eingeführt (`Goldjunge.mq5:402`).
- Order-Handling bereinigt: TP wird wieder direkt gesetzt, Break-even + neuer Trailing laufen sequenziell, Slippage-Puffer bleibt über `OrderDeviationPoints` steuerbar (`Goldjunge.mq5:3382`, `Goldjunge.mq5:2598`).

## TODO (Optionale Ideen)
- Slippage-Puffer (`OrderDeviationPoints`) langfristig symbol-/rulesabhängig machen für broker-spezifische Toleranzen.
- Trailing-Step (`TrailingStepPips`) bei Bedarf aus Rules oder Train-KI-Bot liefern, um pro Asset feinere Schritte zu erlauben.

## 2025-10-29 — Casino Dynamic Thresholds & BE Analysis
- Casino-Mode refactored: ATR-Trigger und M1/M15-Momentum nutzen jetzt dynamische Schwellen (95%-Quantil + Puffer) und Churn-Check (Baseline vs. aktuelle Nervosität).
- Neue Runtime-Struktur `CasinoDynamicStats` berechnet ratio/churn Trigger, state logging zeigt `CASINO_ON/OFF` mit aktuellen Schwellen.
- Break-even/Trailing-Lücke sichtbar: Netting-Account verschiebt Average Price → 0.5 ATR reicht nicht, obwohl einzelne Legs +5–20 € im Plus waren.
- Empfohlene next steps: Break-even pro Deal, dynamische Trigger <0.5 ATR, Close-Logging ergänzen.

## 2025-10-30 — Break-even Anchor & Triggers
- Break-even Inputs erweitert: `BreakEvenTriggerPips` (default 3.0) und `BreakEvenTriggerMoney` (default 0.30 €) sichern Trades ohne ATR-Abhängigkeit.
- EA speichert ersten bzw. günstigsten Einstieg pro Symbol (`UpdateBreakEvenAnchor`) und nutzt ihn für SL-Neuberechnung trotz Netting-Requotes.
- Kombination der Trigger (`ATR` | `PIPS` | `MONEY`) löst Break-Even aus, Logging zeigt verwendete Schwelle (`trigger=ATR+PIPS` etc.).
- OnInit/OnTick/Order-Erfolg synchronisieren Anker automatisch; SL-Fails loggen jetzt vollständigen Kontext inkl. Auslöser & Diff in Pips.

## 2025-12-02 — SL Cap Broker-Min Fix
- `Goldjunge.mq5` akzeptiert jetzt das vom Broker geforderte Mindest-SL (`ValidateStops`) statt auf den ursprünglichen weiten Stop zurückzuspringen.
- Bei erzwungenem Mindestabstand wird `SL_CAP_MIN limit=… loss_after=…` geloggt; Debug meldet den neuen Pip-Abstand & Verlust.
- Keine `SL_CAP_FALLBACK`-Flut mehr → Verlust pro Trade entspricht dem kleinsten Broker-Limit (~10 € bei 0.1 Lot CADJPY) statt 20 €+.
- Neues Daily-Drawdown-System (`DailyDrawdownEnabled`/`DailyDrawdownPercent`) speichert Tagesstart-Balance, überwacht das Tagesminus und blockt neue Trades nach Limitüberschreitung (`DRAWDOWN_STOP`).
- Reset erfolgt bei Server-00:00, Debug-Logs dokumentieren Reset, Drawdown und Stop; laufende Positionen werden weiterverwaltet, nur Entries stoppen.

## 2025-12-06 — Stoch Reason Fix & Rules Quality Link
- `BuildMissingConditions` nutzt jetzt `g_last_breakrevert_signal` als Fallback, damit Stoch-Blocker immer im "Fehlt"-Log landen; sobald der Logic-Filter genannt ist, werden die einzelnen ADX/Stoch/Vol-Werte nicht doppelt aufgelistet.
- `GetFinalSignal` verlangt in allen reinen Rules-Modi (B/C) zusätzlich, dass News zustimmen **und** die aktuellen Quality-Filter erfüllt sind (`CheckQualityFiltersForDirection`). Blocker werden als "Quality Filter blockieren Rules (…)" im Debug geloggt.
- Neues Helper `CheckQualityFiltersForDirection` wird auch im Missing-Reason-Block genutzt, wodurch Goldjunge exakt die Richtung prüft, die Rules oder Logic zuletzt geliefert haben.
- `Train-KI-Bot.py` unterstützt Targets, Signale, Kalibrierung und Tradesimulation jetzt symmetrisch für BUY/SELL: Decision Tree liefert ±1, Quality-Schwellen und BreakRevert-Quantile berücksichtigen Short-Daten, `simulate_trades` sowie Rule-Export speichern die Richtung.

## 2025-12-16 — Decision-Tree SELL Fix
- Rules-Parser erkennt nun `class: -1` (und `class: 2`) als SELL und schreibt `node.signal = -1` statt 0 – dadurch bleiben die 21 SELL-Blätter aus `rules_*.txt` erhalten.
- Fallback-BreakRevert-Logik gibt konsequent `-1` für SELL zurück, keine Phantom-"2"-Signale mehr.
- `GetRulesSignal` mappt Tree-Resultate direkt (`1→BUY`, `-1→SELL`), sodass das finale 3-Regel-System wieder echte SELL-Signale bekommt (Signal-Mode C in Prod identisch aktualisiert).

## 2025-12-17 — Trend-Strong Thresholds
- `TKB-config.json` enthält jetzt einen eigenen Block `trend_strong` (Quantile + Faktoren für ADX/Vol/ATR) damit ML-Schwellen anpassbar bleiben.
- `_compute_trend_strength_thresholds` liest die Config, clampte Quantile (0–1) und nutzt die Faktoren für Fallbacks & Quantile; fehlende Spalten werden sauber ignoriert.
- `compute_intelligent_parameters` übergibt die Config an den Helper, wodurch `rules_*.txt` numerische Trend-Schwellen direkt aus den Einstellungen erhalten.

## 2025-12-17 — TrendStrong Filter (EA)
- `Goldjunge.mq5` liest nun `Trend_ADX_Strong`, `Trend_Volume_Strong`, `Trend_ATR_Strong` aus den Rules (Fallbacks auf Inputs) und loggt die Werte im Optimizer-Report.
- Neuer Helper `IsTrendTooStrong` prüft ADX/Vol/ATR gegen diese Schwellen und setzt `g_trend_block_reason`, damit “Fehlt”-Logs und Debug exakt anzeigen, warum Trendbrand blockiert.
- OnTick setzt nach der finalen Signalfindung (Rules/Logic/News) den Trendfilter ein: Überhitzung → `TREND_STRONG_BLOCK` + final_signal→0, ansonsten läuft die Pipeline unverändert weiter.
