# Goldjunge Casino-Modus – Arbeitsprotokoll (Stand: 2025-10-28)

## 1. Ausgangslage
- Goldjunge v6.0 liefert im Stable-Modus hohe Trefferquoten, bricht aber seit den Chaos-Märkten (Q4 2025) weg.
- Ziel: zuschaltbarer "Casino-Modus" für Extremphasen (hohe Intraday-Volatilität, whipsaw-Märkte).
- Stable-Training (`Train-KI-Bot.py`) wurde angepasst:
  - Long/Short-Ziele getrennt → dreiklassige Modelle (0 flat, 1 buy, 2 sell).
  - Risk-Simulation spiegelt jetzt EA-Logik (Loss-Cap, BreakEven, Trailing, Mindestabstände).
  - Qualitätsfilter gelockert: `min_trades=40`, `min_winrate=0.45` (vorher 150 / 0.7).

## 2. Neues Werkzeug
- `train-casino.py` – Mini-Backtester für den Casino-Modus (liegt im Projekt-Root).
  - Datengrundlage: lokale CSVs (`*_H1.csv`, `*_M15.csv`, `*_M1.csv`).
  - Chaos-Trigger: H1-ATR ≥ 1.6 × Median der letzten 96 H1-Bars.
  - Entry-Bedingung: M15 und M1 zeigen denselben Impuls (letzte zwei Closes).
  - Trade-Setup: TP = 0.35 ATR, SL = 0.55 ATR, max. 8 H1-Bars Haltedauer.
  - Output: `reports/casino_summary.md` + `reports/casino_rules/casino_<Symbol>.txt`.
  - Schnelltest (EURUSD, USDJPY, AUDJPY) → ~200 Trades, Winrate ~63 %, Profit > 0 (noch ohne Währungsumrechnung/Slippage).

## 3. Nächste Schritte / TODO
1. Parameter feintunen (ATR-Ratio, Lookback, TP/SL).
2. Spread/Slippage & Zeitfenster ergänzen.
3. Gemeinsame QA (Weekly vs. Gesamt) definieren.
4. Casino-Modus in `Train-KI-Bot.py` integrieren (Config-Toggle).
5. Regime-Manager (Calm/Volatile/Chaos) für Stable & Casino aufsetzen.

## 4. Offene Fragen
- Balance Stable vs. Casino? (Risk Allocation)
- News-Filter nur live oder später Backtest-fähig?
- Profit-Recycling (Lot-Anpassungen) im EA?

## 5. Quick Runbook
1. Casino-Test: `python train-casino.py --symbols EURUSD USDJPY`
2. Ergebnis prüfen: `reports/casino_summary.md` & `reports/casino_rules/`
3. Stable-Training (bei Bedarf): `./RUN-train.sh`
4. Wöchentliche Analyse: `reports/training_summary.md`

Kurzfassung: Stable-Modus läuft wieder, Casino-Prototyp steht. Nächstes Ziel: Parameter-Feinschliff, Stresstest, Integration in Hauptpipeline.
