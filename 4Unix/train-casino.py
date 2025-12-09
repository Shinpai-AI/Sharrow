#!/usr/bin/env python3
"""Sharrow Casino-mode backtesting aligned with Train-KI-Bot pipeline.

The script reuses the EA simulation utilities from Train-KI-Bot so that
risk handling, TP/SL computation, and trade evaluation stay identical.
Only the entry condition (chaos trigger + lower TF momentum) differs.
"""

from __future__ import annotations

import argparse
import importlib.util
import logging
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent
TRAIN_MODULE_NAME = "train_ki_bot_module"
TRAIN_SCRIPT_PATH = ROOT / "Train-KI-Bot.py"
CONFIG_DEFAULT = ROOT / "TKB-config.json"
REPORT_PATH = ROOT / "reports" / "casino_summary.md"
RESULT_RULES_DIR = ROOT / "reports" / "casino_rules"

VOL_TRIGGER_RATIO = 1.6  # ATR vs median threshold for chaos detection
VOL_LOOKBACK = 96        # H1 bars (~4 days) for ATR median baseline
ATR_PERIOD = 14
MIN_BARS_FOR_SIGNAL = max(VOL_LOOKBACK, ATR_PERIOD) + 1

CSV_COLS = ["Time", "Open", "High", "Low", "Close", "Volume"]


@dataclass
class CasinoMetrics:
    symbol: str
    total_trades: int
    total_wins: int
    total_winrate: float
    total_profit: float
    window_trades: int
    window_wins: int
    window_winrate: float
    window_profit: float
    tp: float
    sl: str
    lot_size: float
    trade_active: bool


_TRAIN_MODULE = None


def get_training_module():
    """Load Train-KI-Bot.py as a module once and reuse it."""
    global _TRAIN_MODULE
    if _TRAIN_MODULE is None:
        if not TRAIN_SCRIPT_PATH.exists():
            raise FileNotFoundError(f"Train-KI-Bot script missing: {TRAIN_SCRIPT_PATH}")
        spec = importlib.util.spec_from_file_location(TRAIN_MODULE_NAME, TRAIN_SCRIPT_PATH)
        module = importlib.util.module_from_spec(spec)
        sys.modules[TRAIN_MODULE_NAME] = module
        if spec.loader is None:
            raise ImportError("Failed to create loader for Train-KI-Bot module")
        spec.loader.exec_module(module)
        _TRAIN_MODULE = module
    return _TRAIN_MODULE


def load_csv(symbol: str, timeframe: str, root: Path) -> pd.DataFrame:
    path = root / f"{symbol}_{timeframe}.csv"
    if not path.exists():
        raise FileNotFoundError(f"CSV not found: {path}")
    df = pd.read_csv(path, sep=';', names=CSV_COLS, header=0, encoding='utf-8')
    df["Time"] = pd.to_datetime(df["Time"], errors='coerce')
    df.dropna(subset=["Time"], inplace=True)
    df.sort_values("Time", inplace=True)
    df.set_index("Time", inplace=True)
    for col in ["Open", "High", "Low", "Close", "Volume"]:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    df.dropna(inplace=True)
    return df


def regime_trigger(atr_series: pd.Series) -> pd.Series:
    median = atr_series.rolling(window=VOL_LOOKBACK, min_periods=1).median()
    ratio = atr_series / median.replace(0, np.nan)
    trigger = ratio >= VOL_TRIGGER_RATIO
    return trigger.fillna(False)


def direction_from_lower_tf(df: pd.DataFrame, ts: pd.Timestamp) -> Optional[int]:
    """Return +1/-1 if last two closes show momentum, otherwise None."""
    subset = df[df.index <= ts].tail(2)
    if len(subset) < 2:
        return None
    prev_close, last_close = subset["Close"].iloc[-2], subset["Close"].iloc[-1]
    if last_close > prev_close:
        return 1
    if last_close < prev_close:
        return -1
    return None


def build_signal_frame(symbol: str, data_root: Path, train_module) -> pd.DataFrame:
    h1 = load_csv(symbol, "H1", data_root)
    m15 = load_csv(symbol, "M15", data_root)
    m1 = load_csv(symbol, "M1", data_root)

    atr_series = train_module._compute_atr(h1).replace([np.inf, -np.inf], np.nan)
    atr_series = atr_series.ffill().bfill().fillna(0.0)
    trigger = regime_trigger(atr_series)

    signals = np.zeros(len(h1), dtype=int)
    for idx in range(MIN_BARS_FOR_SIGNAL, len(h1)):
        if not trigger.iat[idx]:
            continue
        ts = h1.index[idx]
        m15_dir = direction_from_lower_tf(m15, ts)
        m1_dir = direction_from_lower_tf(m1, ts)
        if m15_dir is None or m1_dir is None:
            continue
        if m15_dir != m1_dir:
            continue
        signals[idx] = m1_dir

    signal_df = h1.copy()
    signal_df["atr"] = atr_series
    signal_df["signal"] = signals
    return signal_df


def build_signal_examples(trades_df: Optional[pd.DataFrame], limit: int = 5) -> List[Tuple[pd.Timestamp, int, float]]:
    if trades_df is None or trades_df.empty:
        return []
    samples: List[Tuple[pd.Timestamp, int, float]] = []
    for _, row in trades_df.head(limit).iterrows():
        ts = pd.to_datetime(row.get("entry_time"))
        direction = int(row.get("direction", 0))
        samples.append((ts, direction, 1.0))
    return samples


def process_symbol(
    symbol: str,
    data_root: Path,
    config: Dict,
    period_days: Optional[int],
    min_winrate: float,
    ea_params,
) -> CasinoMetrics:
    train_module = get_training_module()

    df = build_signal_frame(symbol, data_root, train_module)
    lot_size = train_module.calculate_lot_size(symbol, config)

    tp_candidates, sl_variants = train_module.get_rule_parameter_options(config)
    rules_cfg = config.get("rules", {})
    min_trades = int(rules_cfg.get("min_trades", 50))

    best_rules = train_module.find_best_rule_parameters(
        df,
        symbol,
        config,
        lot_size,
        min_trades,
        min_winrate,
        period_days,
        tp_candidates,
        sl_variants,
        ea_params,
    )

    if not best_rules:
        tree_lines = ["// Casino mode – keine gültigen Chaossignale"]
        rule_info = {
            "tp": 0.0,
            "sl": "n/a",
            "trades": 0,
            "wins": 0,
            "profit_window": 0.0,
            "profit_total": 0.0,
            "winrate": 0.0,
            "winrate_total": 0.0,
            "trade_active": False,
            "lot_size": lot_size,
            "intelligent_params": {},
        }
        train_module.export_rules(symbol, RESULT_RULES_DIR, rule_info, tree_lines, [])
        return CasinoMetrics(
            symbol=symbol,
            total_trades=0,
            total_wins=0,
            total_winrate=0.0,
            total_profit=0.0,
            window_trades=0,
            window_wins=0,
            window_winrate=0.0,
            window_profit=0.0,
            tp=0.0,
            sl="n/a",
            lot_size=lot_size,
            trade_active=False,
        )

    trades_df = best_rules.get("trades_df")
    window_stats = train_module.compute_window_summary(trades_df, period_days)
    trade_active = window_stats["profit"] > 0 and window_stats["winrate"] >= min_winrate

    rule_info = {
        "tp": best_rules["tp"],
        "sl": best_rules["sl"],
        "trades": window_stats["trades"],
        "wins": window_stats["wins"],
        "profit_window": window_stats["profit"],
        "profit_total": best_rules["profit"],
        "winrate": window_stats["winrate"],
        "winrate_total": best_rules["winrate"],
        "trade_active": trade_active,
        "lot_size": lot_size,
        "intelligent_params": {},
    }
    tree_lines = ["// Casino mode – Entry: H1 Chaos Trigger + M15/M1 Momentum"]
    examples = build_signal_examples(trades_df)
    train_module.export_rules(symbol, RESULT_RULES_DIR, rule_info, tree_lines, examples)

    return CasinoMetrics(
        symbol=symbol,
        total_trades=int(best_rules["trades"]),
        total_wins=int(best_rules["wins"]),
        total_winrate=float(best_rules["winrate"]),
        total_profit=float(best_rules["profit"]),
        window_trades=int(window_stats["trades"]),
        window_wins=int(window_stats["wins"]),
        window_winrate=float(window_stats["winrate"]),
        window_profit=float(window_stats["profit"]),
        tp=float(best_rules["tp"]),
        sl=str(best_rules["sl"]),
        lot_size=float(lot_size),
        trade_active=trade_active,
    )


def write_summary(results: List[CasinoMetrics], period_label: str) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with REPORT_PATH.open("w", encoding="utf-8") as handle:
        handle.write("# Sharrow Casino-Backtest\n\n")
        handle.write(f"Ansicht: {period_label}\n\n")
        handle.write(
            "| Symbol | Trades (gesamt) | Winrate (gesamt) | Profit (gesamt) | "
            f"Trades ({period_label}) | Winrate ({period_label}) | Profit ({period_label}) | TP | SL | Lot | Aktiv |\n"
        )
        handle.write("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |\n")
        for res in results:
            handle.write(
                f"| {res.symbol} | {res.total_trades} | {res.total_winrate * 100:.1f}% | "
                f"{res.total_profit:.2f} | {res.window_trades} | {res.window_winrate * 100:.1f}% | "
                f"{res.window_profit:.2f} | {res.tp:.2f} | {res.sl} | {res.lot_size:.2f} | "
                f"{'yes' if res.trade_active else 'no'} |\n"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sharrow casino backtest")
    parser.add_argument("--config", type=Path, default=CONFIG_DEFAULT)
    parser.add_argument("--symbols", nargs="*", help="Optional symbol list override")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

    train_module = get_training_module()
    config = train_module.load_config(args.config)

    symbols = args.symbols or train_module.list_config_symbols(config)
    if not symbols:
        logging.warning("Keine Symbole für Casino-Backtest gefunden")
        return

    period_label, period_days = train_module.get_reporting_period(config)
    ea_params = train_module.get_ea_parameters(config)
    rules_cfg = config.get("rules", {})
    min_winrate = float(rules_cfg.get("min_winrate", 0.6))

    results: List[CasinoMetrics] = []
    for symbol in symbols:
        try:
            metrics = process_symbol(symbol, ROOT, config, period_days, min_winrate, ea_params)
            results.append(metrics)
            logging.info(
                "%s: trades=%d winrate=%.1f%% profit=%.2f",
                symbol,
                metrics.total_trades,
                metrics.total_winrate * 100,
                metrics.total_profit,
            )
        except FileNotFoundError as exc:
            logging.error("%s: Datei fehlt (%s)", symbol, exc)
        except Exception as exc:  # pragma: no cover
            logging.exception("%s: Casino-Backtest fehlgeschlagen", symbol)

    write_summary(results, period_label)
    logging.info("Casino summary written to %s", REPORT_PATH)


if __name__ == "__main__":
    main()
