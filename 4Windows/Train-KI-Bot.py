#!/usr/bin/env python3
"""Train-KI-Bot.py
Goldjunge ML-Pipeline (Refactor 2025-09)
"""

import argparse
import json
import logging
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import requests  # Telegram Versand
except Exception:  # pragma: no cover
    requests = None

import numpy as np
import pandas as pd
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier, export_text
from scipy.stats import weibull_min, poisson
import joblib


def iter_symbol_configs(symbols_block):
    for symbol, data in (symbols_block or {}).items():
        if str(symbol).lower() == "symbols_description":
            continue
        yield symbol, data


def list_config_symbols(config):
    block = config.get("symbols", {}) if isinstance(config, dict) else {}
    return [symbol for symbol, _ in iter_symbol_configs(block)]

# ===== Pfad-Defaults =====
ROOT = Path(__file__).resolve().parent
CONFIG_DEFAULT = ROOT / "TKB-config.json"
DATA_DEFAULT = ROOT
RULES_DEFAULT = ROOT
MODELS_DEFAULT = ROOT / "models"
REPORTS_DEFAULT = ROOT / "reports"
LOG_PATH = ROOT / "TKB.log"
WELLDONE_PATH = ROOT / "welldone.txt"

FEATURE_COLUMNS = [
    "stochastic",
    "adx",
    "atr",
    "weibull_prob",
    "poisson_prob",
    "Volume",
]


class IdentityTransformer:
    def fit(self, X: pd.DataFrame):
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        return X


def _ensure_str_list(raw_value, fallback: List[str]) -> List[str]:
    if raw_value is None:
        return fallback
    if isinstance(raw_value, list):
        try:
            return [str(v).strip() for v in raw_value if str(v).strip()]
        except Exception:
            return fallback
    if isinstance(raw_value, str):
        items = [item.strip() for item in raw_value.split(",") if item.strip()]
        return items or fallback
    return fallback


def get_sl_variants(config: Dict) -> List[str]:
    rules_cfg = config.get("rules", {})
    return _ensure_str_list(rules_cfg.get("sl_variants"), ["atr1.5", "atr2.0", "extrem14+0.5atr", "extrem14+1.0atr"])


def build_basic_rule_info(
    lot_size: float,
    sl_variants: List[str],
    tp_value: float,
    intelligent_params: Optional[Dict[str, float]] = None,
    trade_active: bool = False,
    override_reason: Optional[str] = None,
) -> Dict[str, object]:
    default_sl = sl_variants[0] if sl_variants else "atr1.0"
    rule_info: Dict[str, object] = {
        "tp": tp_value,
        "sl": default_sl,
        "trades": 0,
        "wins": 0,
        "profit_window": 0.0,
        "profit_total": 0.0,
        "winrate": 0.0,
        "winrate_total": 0.0,
        "trade_active": trade_active,
        "lot_size": lot_size,
        "intelligent_params": intelligent_params or {},
        "tp_mode": "atr",
    }
    if override_reason:
        rule_info["override_reason"] = override_reason
    return rule_info


def get_symbol_tp_settings(config: Dict, symbol: str) -> Dict[str, object]:
    symbols_block = config.get("symbols", {}) if isinstance(config, dict) else {}
    entry = symbols_block.get(symbol) or symbols_block.get(symbol.upper())
    if not isinstance(entry, dict):
        return {}
    tp_cfg = entry.get("tp_settings")
    if not isinstance(tp_cfg, dict):
        return {}
    atr_multiplier = float(tp_cfg.get("atr_multiplier", 0.0) or 0.0)
    swing = bool(tp_cfg.get("swing", False))
    return {"atr_multiplier": atr_multiplier, "swing": swing}


def apply_symbol_tp_settings(rule_info: Dict[str, object], config: Dict, symbol: str) -> None:
    tp_config = get_symbol_tp_settings(config, symbol)
    if not tp_config:
        rule_info.setdefault("tp_mode", "atr")
        return
    swing = bool(tp_config.get("swing", False))
    atr_multiplier = float(tp_config.get("atr_multiplier", 0.0) or 0.0)
    if swing:
        rule_info["tp_mode"] = "swing"
        rule_info["tp"] = 0.0
    elif atr_multiplier > 0.0:
        rule_info["tp_mode"] = "atr"
        rule_info["tp"] = atr_multiplier
    else:
        rule_info.setdefault("tp_mode", "atr")


def get_symbol_tp_multiplier(config: Dict, symbol: Optional[str], default: float = 1.0) -> float:
    if not symbol:
        return default
    tp_config = get_symbol_tp_settings(config, symbol)
    if not tp_config:
        return default
    atr_multiplier = float(tp_config.get("atr_multiplier", default) or default)
    if atr_multiplier <= 0:
        return default
    return atr_multiplier


def get_rule_parameter_options(config: Dict, symbol: Optional[str] = None) -> Tuple[List[float], List[str]]:
    """Legacy helper for callers that still expect TP+SL options."""
    sl_variants = get_sl_variants(config)
    tp_value = get_symbol_tp_multiplier(config, symbol)
    return [tp_value], sl_variants


def get_quality_defaults(config: Dict) -> Dict[str, float]:
    quality_cfg = config.get("quality_defaults") or config.get("quality") or {}
    return {
        "adx_min": float(quality_cfg.get("adx_min", 25.0)),
        "stoch_buy_max": float(quality_cfg.get("stoch_buy_max", 30.0)),
        "stoch_sell_min": float(quality_cfg.get("stoch_sell_min", 70.0)),
        "volume_min": float(quality_cfg.get("volume_min", 1000.0)),
    }

# ===== Logging =====
def setup_logging() -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(LOG_PATH, mode="w", encoding="utf-8"),
            logging.StreamHandler()
        ]
    )


# ===== Konfigurationsobjekte =====
@dataclass
class TrainingSettings:
    hold_bars: int = 5
    min_return: float = 0.0005
    test_size: float = 0.2
    random_state: int = 42
    min_positive: int = 20
    volume_window: int = 20
    volume_spike: float = 1.8
    rule_threshold: float = 0.55


def load_config(path: Path) -> Dict:
    if not path.exists():
        raise FileNotFoundError(f"Config nicht gefunden: {path}")
    with path.open("r", encoding="utf-8") as f:
        config = json.load(f)
    paths = config.get("paths", {})
    required = ["mt5_path", "mt5_files_subpath", "mt5_logs_subpath", "python_bin"]
    missing = [key for key in required if key not in paths]
    if missing:
        raise KeyError(f"Folgende keys fehlen im paths-Block: {missing}")
    return config


def extract_training_settings(config: Dict) -> TrainingSettings:
    training_cfg = config.get("training", {})
    volume_cfg = config.get("volume", {})
    return TrainingSettings(
        hold_bars=int(training_cfg.get("hold_bars", 5)),
        min_return=float(training_cfg.get("min_return", 0.0005)),
        test_size=float(training_cfg.get("test_size", 0.2)),
        random_state=int(training_cfg.get("random_state", 42)),
        min_positive=int(training_cfg.get("min_positive", 20)),
        volume_window=int(volume_cfg.get("window", 20)),
        volume_spike=float(volume_cfg.get("spike_threshold", 1.8)),
        rule_threshold=float(training_cfg.get("rule_threshold", 0.55)),
    )


# ===== Daten laden =====
def load_symbol_csv(symbol: str, timeframe: str, root: Path) -> pd.DataFrame:
    file_path = root / f"{symbol}_{timeframe}.csv"
    if not file_path.exists():
        logging.warning("%s fehlt, überspringe", file_path.name)
        return pd.DataFrame()
    try:
        df = pd.read_csv(file_path, sep=';', encoding='utf-8')
    except UnicodeDecodeError:
        df = pd.read_csv(file_path, sep=';', encoding='latin1')
    required_cols = {"Time", "Open", "High", "Low", "Close", "Volume"}
    if not required_cols.issubset(df.columns):
        logging.error("%s hat ungültige Spalten", file_path.name)
        return pd.DataFrame()
    df["Time"] = pd.to_datetime(df["Time"], errors='coerce')
    df.dropna(subset=["Time"], inplace=True)
    df.sort_values("Time", inplace=True)
    df.set_index("Time", inplace=True)
    return df


def add_volume_features(df: pd.DataFrame, settings: TrainingSettings) -> pd.DataFrame:
    if df.empty:
        return df
    window = settings.volume_window
    ratio_threshold = settings.volume_spike
    volume = df["Volume"].astype(float)
    sma = volume.rolling(window=window, min_periods=1).mean()
    df["volume_ratio"] = (volume / sma.replace(0, np.nan)).fillna(1.0)
    df["volume_spike"] = (df["volume_ratio"] >= ratio_threshold).astype(int)
    df["volume_delta"] = volume.diff().fillna(0)
    return df


def _true_range(df: pd.DataFrame) -> pd.Series:
    high = df["High"]
    low = df["Low"]
    close = df["Close"]
    prev_close = close.shift(1)
    tr_components = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs(),
    ], axis=1)
    return tr_components.max(axis=1)


def _compute_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    tr = _true_range(df)
    return tr.ewm(alpha=1 / period, adjust=False).mean()


def add_price_features(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    df["return_1"] = df["Close"].pct_change().fillna(0)
    df["return_5"] = df["Close"].pct_change(5).fillna(0)
    df["atr"] = _compute_atr(df).fillna(0)
    return df


def add_indicator_features(df: pd.DataFrame, k_period: int = 14, d_period: int = 3, slowing: int = 3, adx_period: int = 14) -> pd.DataFrame:
    if df.empty:
        return df

    lowest_low = df["Low"].rolling(window=k_period, min_periods=1).min()
    highest_high = df["High"].rolling(window=k_period, min_periods=1).max()
    denominator = (highest_high - lowest_low).replace(0, np.nan)
    stoch_k = ((df["Close"] - lowest_low) / denominator) * 100.0
    stoch_k = stoch_k.clip(lower=0, upper=100).bfill().fillna(50.0)
    stoch_d = stoch_k.rolling(window=d_period, min_periods=1).mean()
    stoch_slow = stoch_d.rolling(window=slowing, min_periods=1).mean()

    df["stochastic_k"] = stoch_k
    df["stochastic_d"] = stoch_d
    df["stochastic"] = stoch_slow

    # ADX calculation
    up_move = df["High"].diff().clip(lower=0)
    down_move = (-df["Low"].diff()).clip(lower=0)
    up_move = up_move.where(up_move > down_move, 0.0)
    down_move = down_move.where(down_move >= up_move, 0.0)

    tr = _true_range(df)
    atr = df["atr"]
    atr.replace(0, np.nan, inplace=True)

    plus_di = 100 * (up_move.ewm(alpha=1 / adx_period, adjust=False).mean() / atr)
    minus_di = 100 * (down_move.ewm(alpha=1 / adx_period, adjust=False).mean() / atr)
    dx = (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan) * 100
    adx = dx.ewm(alpha=1 / adx_period, adjust=False).mean()

    df["plus_di"] = plus_di.fillna(0)
    df["minus_di"] = minus_di.fillna(0)
    df["adx"] = adx.fillna(0)

    df.fillna(0, inplace=True)
    return df


def _prepare_series(series: pd.Series) -> pd.Series:
    return series.replace([np.inf, -np.inf], np.nan).dropna()


def _clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _calibrate_thresholds(
    df_signals: pd.DataFrame,
    defaults: Dict[str, float],
    config: Dict,
    symbol: str,
) -> Dict[str, float]:
    result = {
        "method": "baseline",
        "data_points": int(len(df_signals)),
        "adx_min": defaults["adx_min"],
        "stoch_buy_max": defaults["stoch_buy_max"],
        "stoch_sell_min": defaults["stoch_sell_min"],
        "volume_min": defaults["volume_min"],
    }

    if df_signals.empty:
        return result

    signal_hits_buy = df_signals[df_signals["signal"] == 1].copy()
    signal_hits_sell = df_signals[df_signals["signal"] == -1].copy()
    if signal_hits_buy.empty and signal_hits_sell.empty:
        return result

    def _baseline() -> Dict[str, float]:
        combined = pd.concat([signal_hits_buy, signal_hits_sell]) if not signal_hits_sell.empty else signal_hits_buy
        adx_med = float(combined["adx"].median()) if not combined.empty else defaults["adx_min"]
        stoch_buy = float(signal_hits_buy["stochastic"].quantile(0.30)) if not signal_hits_buy.empty else defaults["stoch_buy_max"]
        stoch_sell = float(signal_hits_sell["stochastic"].quantile(0.70)) if not signal_hits_sell.empty else defaults["stoch_sell_min"]
        vol_q60 = float(combined["Volume"].quantile(0.60)) if not combined.empty else defaults["volume_min"]
        return {
            "adx_min": max(adx_med, defaults["adx_min"] * 0.5),
            "stoch_buy_max": min(stoch_buy, defaults["stoch_buy_max"] + 30.0),
            "stoch_sell_min": max(stoch_sell, defaults["stoch_sell_min"] - 10.0),
            "volume_min": max(vol_q60, defaults["volume_min"] * 0.4),
        }

    lot_size = calculate_lot_size(symbol, config)
    min_trades = int(config.get("quality", {}).get("min_calibration_trades", 120))
    min_winrate = float(config.get("quality", {}).get("min_calibration_winrate", 0.55))

    def _evaluate(combo: Dict[str, float]) -> Tuple[float, float, int, float]:
        gated = df_signals.copy()
        buy_mask = gated["signal"] == 1
        buy_mask &= gated["adx"] >= combo["adx_min"]
        buy_mask &= gated["stochastic"] <= combo["stoch_buy_max"]
        buy_mask &= gated["Volume"] >= combo["volume_min"]

        sell_mask = gated["signal"] == -1
        sell_mask &= gated["adx"] >= combo["adx_min"]
        sell_mask &= gated["stochastic"] >= combo["stoch_sell_min"]
        sell_mask &= gated["Volume"] >= combo["volume_min"]

        gated.loc[~(buy_mask | sell_mask), "signal"] = 0

        sl_variants = get_sl_variants(config)
        tp_val = get_symbol_tp_multiplier(config, symbol)
        sl_val = sl_variants[0] if sl_variants else "atr2.0"

        total, wins, profit, _ = simulate_trades(
            gated, symbol, config, lot_size, tp_val, sl_val
        )
        if total == 0:
            return 0.0, 0.0, 0, profit
        winrate = wins / total if total else 0.0
        if total < min_trades or winrate < min_winrate:
            return 0.0, winrate, total, profit
        return profit, winrate, total, profit

    baseline = _baseline()

    adx_floor = float(config.get("quality", {}).get("adx_floor", defaults["adx_min"] * 0.5))
    adx_cap = float(config.get("quality", {}).get("adx_cap", defaults["adx_min"] + 25))
    stoch_floor = float(config.get("quality", {}).get("stoch_buy_floor", max(5.0, defaults["stoch_buy_max"] - 40)))
    stoch_cap = float(config.get("quality", {}).get("stoch_buy_cap", min(90.0, defaults["stoch_buy_max"] + 40)))
    stoch_sell_floor = float(config.get("quality", {}).get("stoch_sell_floor", max(50.0, defaults["stoch_sell_min"] - 30.0)))
    stoch_sell_cap = float(config.get("quality", {}).get("stoch_sell_cap", min(99.0, defaults["stoch_sell_min"] + 20.0)))
    vol_floor = float(config.get("quality", {}).get("volume_floor", defaults["volume_min"] * 0.3))
    vol_cap = float(config.get("quality", {}).get("volume_cap", defaults["volume_min"] * 8))

    search_steps = [0.0, 0.05, -0.05, 0.10, -0.10, 0.15, -0.15]
    best_combo = baseline.copy()
    best_profit = -np.inf
    best_winrate = 0.0
    best_total = 0

    base_profit, base_winrate, base_total, _ = _evaluate(baseline)
    if base_total >= min_trades and base_winrate >= min_winrate:
        best_profit, best_winrate, best_total = base_profit, base_winrate, base_total

    for adx_step in search_steps:
        adx_value = _clamp(baseline["adx_min"] * (1 + adx_step), adx_floor, adx_cap)
        for stoch_step in search_steps:
            stoch_value = _clamp(baseline["stoch_buy_max"] * (1 + stoch_step), stoch_floor, stoch_cap)
            for vol_step in search_steps:
                volume_value = _clamp(baseline["volume_min"] * (1 + vol_step), vol_floor, vol_cap)

                combo = {
                    "adx_min": adx_value,
                    "stoch_buy_max": stoch_value,
                    "stoch_sell_min": _clamp(baseline["stoch_sell_min"], stoch_sell_floor, stoch_sell_cap),
                    "volume_min": volume_value,
                }

                profit, winrate, total, _ = _evaluate(combo)
                if total < min_trades or winrate < min_winrate:
                    continue
                if profit > best_profit or (
                    np.isclose(profit, best_profit) and winrate > best_winrate
                ):
                    best_profit = profit
                    best_winrate = winrate
                    best_total = total
                    best_combo = combo.copy()

    best_combo["adx_min"] = _clamp(best_combo["adx_min"], adx_floor, adx_cap)
    best_combo["stoch_buy_max"] = _clamp(best_combo["stoch_buy_max"], stoch_floor, stoch_cap)
    best_combo["volume_min"] = _clamp(best_combo["volume_min"], vol_floor, vol_cap)

    result.update(best_combo)
    result["stoch_sell_min"] = best_combo.get(
        "stoch_sell_min",
        _clamp(baseline["stoch_sell_min"], stoch_sell_floor, stoch_sell_cap),
    )

    if best_profit > -np.inf and best_total >= min_trades:
        result["method"] = "calibrated"
        result["score"] = float(best_profit)
        logging.info(
            "%s: Calibrated thresholds -> ADX>=%.1f, StochBuy<=%.1f, StochSell>=%.1f, Vol>=%.0f | trades=%d winrate=%.2f%% profit=%.2f",
            symbol,
            result["adx_min"],
            result["stoch_buy_max"],
            result["stoch_sell_min"],
            result["volume_min"],
            best_total,
            best_winrate * 100,
            best_profit,
        )
    else:
        logging.info("%s: Baseline thresholds unverändert", symbol)
    return result


def compute_intelligent_parameters(
    df_signals: pd.DataFrame,
    config: Dict,
    symbol: str,
) -> Dict[str, float]:
    defaults = get_quality_defaults(config)
    try:
        calibrated = _calibrate_thresholds(df_signals, defaults, config, symbol)
    except Exception as exc:
        logging.warning("%s: Calibration failed (%s), using defaults", symbol, exc)
        calibrated = {
            "method": "fallback",
            "data_points": int(len(df_signals)) if df_signals is not None else 0,
            "adx_min": defaults["adx_min"],
            "stoch_buy_max": defaults["stoch_buy_max"],
            "stoch_sell_min": defaults["stoch_sell_min"],
            "volume_min": defaults["volume_min"],
        }
    break_cfg = _calculate_breakrevert_thresholds(df_signals, config)
    calibrated["breakout_threshold"] = break_cfg["breakout_threshold"]
    calibrated["mean_reversion_threshold"] = break_cfg["mean_reversion_threshold"]
    return calibrated


def _calculate_breakrevert_thresholds(df_signals: pd.DataFrame, config: Dict) -> Dict[str, float]:
    break_cfg = config.get("breakrevert", {})
    result = {
        "breakout_threshold": float(break_cfg.get("breakout_threshold", 0.4)),
        "mean_reversion_threshold": float(break_cfg.get("mean_reversion_threshold", 0.4)),
    }

    if df_signals is None or df_signals.empty:
        return result
    if "weibull_prob" not in df_signals.columns:
        return result

    valid = df_signals.dropna(subset=["signal", "weibull_prob"])
    if valid.empty:
        return result

    buys = valid[valid["signal"] == 1]
    sells = valid[valid["signal"] == -1]
    min_samples = int(break_cfg.get("min_samples", 40))
    buy_q = float(break_cfg.get("buy_quantile", 0.65))
    sell_q = float(break_cfg.get("sell_quantile", 0.35))

    if len(buys) >= max(5, min_samples // 2):
        result["breakout_threshold"] = float(buys["weibull_prob"].quantile(buy_q))
    if len(sells) >= max(5, min_samples // 2):
        result["mean_reversion_threshold"] = float(sells["weibull_prob"].quantile(sell_q))

    result["breakout_threshold"] = _clamp(result["breakout_threshold"], 0.05, 0.98)
    result["mean_reversion_threshold"] = _clamp(
        result["mean_reversion_threshold"], 0.01, result["breakout_threshold"] - 0.01
    )
    return result


def add_breakrevert_features(df: pd.DataFrame, lookback: int = 24) -> pd.DataFrame:
    if df.empty:
        return df

    close = df["Close"].astype(float)
    mean_price = close.rolling(window=lookback, min_periods=1).mean().replace(0, np.nan)
    normalized_price = (close / mean_price).clip(lower=0.01)
    df["weibull_prob"] = weibull_min.cdf(normalized_price.fillna(1.0), 1.5, scale=1.0)

    returns = close.pct_change().fillna(0)
    volatility = returns.rolling(window=lookback, min_periods=1).std().replace(0, np.nan).bfill().fillna(0.0001)
    significant_moves = (returns.abs() / volatility).clip(lower=0)
    lambda_param = significant_moves.rolling(window=lookback, min_periods=1).mean().clip(lower=0.1)
    df["poisson_prob"] = poisson.cdf(significant_moves, lambda_param)

    df["weibull_prob"] = df["weibull_prob"].fillna(0.5)
    df["poisson_prob"] = df["poisson_prob"].fillna(0.5)
    return df


def normalize_features(features: pd.DataFrame, symbol: str = None, config: Dict = None) -> pd.DataFrame:
    normalized = features.copy()
    normalized["stochastic"] = (normalized["stochastic"] - 50.0) / 30.0
    normalized["adx"] = (normalized["adx"] - 30.0) / 20.0

    # SYMBOL-SPECIFIC ATR NORMALIZATION
    if symbol and config:
        symbols_cfg = config.get("symbols", {})
        symbol_cfg = symbols_cfg.get(symbol, {})
        pip_size = float(symbol_cfg.get("pip_size", 0.0001))  # Default für EUR/USD style

        # ATR normalization based on pip_size
        # JPY pairs: pip_size=0.01, EUR/USD: pip_size=0.0001
        atr_scale = pip_size * 5000  # Adaptive scaling factor
        normalized["atr"] = (normalized["atr"] - pip_size) / atr_scale
    else:
        # FALLBACK: old hardcoded (for backward compatibility)
        normalized["atr"] = (normalized["atr"] - 0.001) / 0.002

    normalized["weibull_prob"] = (normalized["weibull_prob"] - 0.5) / 0.3
    normalized["poisson_prob"] = (normalized["poisson_prob"] - 0.5) / 0.3
    normalized.replace([np.inf, -np.inf], 0.0, inplace=True)
    normalized.fillna(0.0, inplace=True)
    return normalized




def build_targets(df: pd.DataFrame, settings: TrainingSettings) -> pd.DataFrame:
    if df.empty:
        return df
    future_close = df["Close"].shift(-settings.hold_bars)
    df["future_return"] = (future_close - df["Close"]) / df["Close"]
    df["target"] = 0
    df.loc[df["future_return"] >= settings.min_return, "target"] = 1
    df.loc[df["future_return"] <= -settings.min_return, "target"] = -1
    df.dropna(inplace=True)
    df = df[df["target"] != 0]
    return df


def prepare_dataset(symbol: str, data_root: Path, settings: TrainingSettings) -> pd.DataFrame:
    data = load_symbol_csv(symbol, "H1", data_root)
    if data.empty:
        return pd.DataFrame()
    data = add_volume_features(data, settings)
    data = add_price_features(data)
    data = add_indicator_features(data)
    data = add_breakrevert_features(data)
    data = build_targets(data, settings)
    if data.empty:
        return data
    data.replace([np.inf, -np.inf], np.nan, inplace=True)
    data.dropna(inplace=True)
    return data


def split_features_target(df: pd.DataFrame, symbol: str = None, config: Dict = None) -> Tuple[pd.DataFrame, pd.Series]:
    missing = [col for col in FEATURE_COLUMNS if col not in df.columns]
    if missing:
        raise KeyError(f"Fehlende Features: {missing}")
    features = df[FEATURE_COLUMNS].copy()
    features = normalize_features(features, symbol, config)
    target = df["target"].copy()
    features.replace([np.inf, -np.inf], 0.0, inplace=True)
    features.fillna(0.0, inplace=True)
    return features, target


def train_model(X_train: pd.DataFrame, y_train: pd.Series) -> Tuple[DecisionTreeClassifier, IdentityTransformer]:
    scaler = IdentityTransformer().fit(X_train)
    X_scaled = scaler.transform(X_train)
    model = DecisionTreeClassifier(max_depth=6, min_samples_leaf=50, class_weight="balanced", random_state=42)
    model.fit(X_scaled, y_train)
    return model, scaler


def evaluate_model(model, scaler, X_test, y_test, symbol: str, reports_dir: Path) -> Dict[str, float]:
    X_scaled = scaler.transform(X_test)
    preds = model.predict(X_scaled)
    report = classification_report(y_test, preds, digits=3)
    reports_dir.mkdir(parents=True, exist_ok=True)
    report_path = reports_dir / f"training_report_{symbol}.txt"
    report_path.write_text(report, encoding='utf-8')
    logging.info("Report für %s gespeichert: %s", symbol, report_path.name)
    return {
        "accuracy": float((preds == y_test).mean()),
        "positives_test": int((y_test != 0).sum()),
        "samples_test": int(len(y_test)),
    }


def build_model_signals(df: pd.DataFrame, model, scaler, threshold: float, symbol: str = None, config: Dict = None) -> pd.DataFrame:
    if df.empty:
        return df
    features = normalize_features(df[FEATURE_COLUMNS], symbol, config)
    probs = model.predict_proba(scaler.transform(features))
    classes = list(getattr(model, "classes_", []))
    prob_buy = probs[:, classes.index(1)] if 1 in classes else np.zeros(len(df))
    prob_sell = probs[:, classes.index(-1)] if -1 in classes else np.zeros(len(df))
    df = df.copy()
    df["model_prob_buy"] = prob_buy
    df["model_prob_sell"] = prob_sell
    buy_mask = prob_buy >= threshold
    sell_mask = (prob_sell >= threshold) & (prob_sell > prob_buy)
    buy_mask = buy_mask & (prob_buy >= prob_sell)
    signals = np.zeros(len(df), dtype=int)
    signals[buy_mask] = 1
    signals[sell_mask] = -1
    df["signal"] = signals
    df["model_prob"] = 0.0
    df.loc[buy_mask, "model_prob"] = prob_buy[buy_mask]
    df.loc[sell_mask, "model_prob"] = prob_sell[sell_mask]
    return df


def _resolve_sl_variant(sl_variant: str) -> Tuple[str, float]:
    if sl_variant.startswith("atr"):
        value = float(sl_variant.replace("atr", ""))
        return "atr", value
    if sl_variant.startswith("extrem"):
        parts = sl_variant.replace("extrem", "").split("+")
        period = int(parts[0]) if parts[0] else 14
        atr_mult = 0.0
        if len(parts) > 1 and parts[1].endswith("atr"):
            atr_mult = float(parts[1].replace("atr", ""))
        return f"extrem{period}", atr_mult
    return "atr", 2.0


def _calculate_tp_sl_prices(row, direction: int, tp_multiplier: float, sl_variant: str) -> Tuple[float, float]:
    atr_value = max(row["atr"], 1e-6)
    entry_price = row["Close"]
    tp_price = entry_price + direction * tp_multiplier * atr_value

    variant, value = _resolve_sl_variant(sl_variant)
    if variant.startswith("extrem"):
        period = int(variant.replace("extrem", ""))
        lowest_low = row.get(f"lowest_low_{period}")
        highest_high = row.get(f"highest_high_{period}")
        if lowest_low is None or highest_high is None:
            return tp_price, entry_price - direction * value * atr_value
        if direction > 0:
            sl_price = lowest_low - value * atr_value
        else:
            sl_price = highest_high + value * atr_value
        return tp_price, sl_price
    # ATR variant
    sl_distance = value * atr_value
    sl_price = entry_price - direction * sl_distance
    return tp_price, sl_price


def _prepare_extreme_levels(df: pd.DataFrame, periods: List[int]) -> pd.DataFrame:
    for period in periods:
        df[f"lowest_low_{period}"] = df["Low"].rolling(window=period, min_periods=1).min()
        df[f"highest_high_{period}"] = df["High"].rolling(window=period, min_periods=1).max()
    return df


def simulate_trades(
    df: pd.DataFrame,
    symbol: str,
    config: Dict,
    lot_size: float,
    tp_multiplier: float,
    sl_variant: str,
) -> Tuple[int, int, float, pd.DataFrame]:
    symbol_cfg = (config.get("symbols") or {}).get(symbol, {})
    if not symbol_cfg:
        logging.warning("Symbol %s nicht in Config, verwende Defaults", symbol)
    contract_size = float(symbol_cfg.get("contract_size", 100000.0))
    quote_currency = symbol_cfg.get("quote_currency", config.get("account", {}).get("currency", "EUR"))
    account_currency = config.get("account", {}).get("currency", "EUR")
    exchange_rates = config.get("exchange_rates", {})

    df = df.copy()
    df = _prepare_extreme_levels(df, [14])

    trades = []
    signals_idx = df.index[df["signal"] != 0]
    if len(signals_idx) == 0:
        return 0, 0, 0.0, pd.DataFrame()

    for idx in signals_idx:
        entry_row = df.loc[idx]
        entry_price = entry_row["Close"]
        direction = int(np.sign(entry_row["signal"])) or 0
        if direction == 0:
            continue
        tp_price, sl_price = _calculate_tp_sl_prices(entry_row, direction, tp_multiplier, sl_variant)

        subsequent = df.loc[idx:]
        exit_price = entry_price
        result = 0
        for _, row in subsequent.iterrows():
            high = row["High"]
            low = row["Low"]
            if direction > 0:
                if high >= tp_price:
                    exit_price = tp_price
                    result = 1
                    break
                if low <= sl_price:
                    exit_price = sl_price
                    result = -1
                    break
            else:
                if low <= tp_price:
                    exit_price = tp_price
                    result = 1
                    break
                if high >= sl_price:
                    exit_price = sl_price
                    result = -1
                    break
        if result == 0:
            exit_price = subsequent.iloc[-1]["Close"]

        profit_quote = (exit_price - entry_price) * contract_size * lot_size * direction
        profit_account = convert_currency(profit_quote, quote_currency, account_currency, exchange_rates)
        trades.append({
            "entry_time": idx,
            "entry_price": entry_price,
            "exit_price": exit_price,
            "direction": direction,
            "result": result,
            "profit": profit_account,
        })

    trades_df = pd.DataFrame(trades)
    if trades_df.empty:
        return 0, 0, 0.0, trades_df

    wins = int((trades_df["result"] == 1).sum())
    total = len(trades_df)
    total_profit = float(trades_df["profit"].sum())
    return total, wins, total_profit, trades_df


def find_best_rule_parameters(
    df: pd.DataFrame,
    symbol: str,
    config: Dict,
    lot_size: float,
    min_trades: int,
    min_winrate: float,
    period_days: Optional[int],
    tp_multiplier: float,
    sl_variants: List[str],
) -> Optional[Dict[str, object]]:
    best = None
    for sl in sl_variants:
        total, wins, profit, trades = simulate_trades(df, symbol, config, lot_size, tp_multiplier, sl)
        if total == 0:
            continue
        winrate = wins / total
        if total < min_trades or winrate < min_winrate:
            continue
        score = profit
        if best is None or score > best["score"]:
            best = {
                "tp": tp_multiplier,
                "sl": sl,
                "trades": total,
                "wins": wins,
                "profit": profit,
                "winrate": winrate,
                "trades_df": trades,
                "score": score,
            }
    if best:
        return best
    return None


def compute_window_summary(trades: pd.DataFrame, period_days: Optional[int]) -> Dict[str, float]:
    if trades is None or trades.empty:
        return {"trades": 0, "wins": 0, "profit": 0.0, "winrate": 0.0}
    window_df = trades.copy()
    window_df["entry_time"] = pd.to_datetime(window_df["entry_time"])
    if period_days is not None and period_days > 0:
        cutoff = window_df["entry_time"].max() - pd.Timedelta(days=period_days)
        window_df = window_df.loc[window_df["entry_time"] >= cutoff]
    if window_df.empty:
        return {"trades": 0, "wins": 0, "profit": 0.0, "winrate": 0.0}
    trades_count = len(window_df)
    wins = int((window_df["result"] == 1).sum())
    profit = float(window_df["profit"].sum())
    winrate = wins / trades_count if trades_count else 0.0
    return {"trades": trades_count, "wins": wins, "profit": profit, "winrate": winrate}


def export_decision_tree_lines(model) -> List[str]:
    try:
        tree_text = export_text(model, feature_names=FEATURE_COLUMNS, decimals=6)
        lines = [line for line in tree_text.splitlines() if line.strip()]
        if not lines:
            return ["// Decision Tree leer"]
        return lines
    except Exception as exc:
        logging.warning("Decision Tree Export fehlgeschlagen: %s", exc)
        return ["// Decision Tree Export fehlgeschlagen"]


def export_rules(
    symbol: str,
    rules_dir: Path,
    rule_info: Dict[str, object],
    tree_lines: List[str],
    signal_examples: List[Tuple[pd.Timestamp, float]],
) -> int:
    rules_dir.mkdir(parents=True, exist_ok=True)
    out_path = rules_dir / f"rules_{symbol}.txt"
    with out_path.open("w", encoding="utf-8") as handle:
        handle.write(f"Symbol: {symbol}\n")
        handle.write(f"LotSize: {rule_info['lot_size']:.4f}\n")
        handle.write(f"TP: {rule_info['tp']:.2f}\n")
        handle.write(f"TP_Mode: {rule_info.get('tp_mode', 'atr')}\n")
        handle.write(f"SL: {rule_info['sl']}\n")
        handle.write(f"WinRate: {rule_info['winrate'] * 100:.1f}\n")
        handle.write(f"TradeActive: {str(rule_info['trade_active']).lower()}\n")
        handle.write(f"Signals: {rule_info['trades']}\n")
        handle.write(f"TotalProfit: {rule_info['profit_total']:.2f}\n")
        handle.write(f"WindowProfit: {rule_info['profit_window']:.2f}\n")
        override_reason = rule_info.get("override_reason")
        if override_reason:
            handle.write(f"// {override_reason}\n")
        intelligent = rule_info.get("intelligent_params") or {}
        if intelligent:
            handle.write(f"ADX_Min: {float(intelligent.get('adx_min', 0.0)):.1f}\n")
            handle.write(f"Stoch_Buy_Max: {float(intelligent.get('stoch_buy_max', 0.0)):.1f}\n")
            handle.write(f"Stoch_Sell_Min: {float(intelligent.get('stoch_sell_min', 0.0)):.1f}\n")
            handle.write(f"Volume_Min: {float(intelligent.get('volume_min', 0.0)):.0f}\n")
        handle.write(f"LastUpdate: {pd.Timestamp.utcnow().isoformat()}\n")
        handle.write("\n// === DECISION TREE RULES ===\n")
        for line in tree_lines:
            handle.write(f"{line}\n")
        if signal_examples:
            handle.write("\n// === SIGNAL SNAPSHOT ===\n")
            for ts, prob in signal_examples:
                handle.write(f"// {ts.isoformat()} -> prob={prob:.3f}\n")
    logging.info("%s: Rules gespeichert (%s)", symbol, out_path.name)
    return int(rule_info.get("trades", 0))


def save_model(symbol: str, model, scaler, models_dir: Path) -> None:
    models_dir.mkdir(parents=True, exist_ok=True)
    artifact = {
        "model": model,
        "scaler": scaler,
    }
    joblib.dump(artifact, models_dir / f"{symbol}_model.pkl")
    logging.info("Modelldatei gespeichert: %s_model.pkl", symbol)


@dataclass
class SymbolResult:
    symbol: str
    samples: int
    positives: int
    rules: int
    accuracy: float
    trades_total: int
    trades_won: int
    profit_account: float
    lot_size: float
    winrate: float


def get_reporting_period(config: Dict) -> Tuple[str, Optional[int]]:
    period_raw = (config.get("reporting") or {}).get("period", "weekly").lower()
    label_map = {
        "daily": "Tagesansicht",
        "weekly": "Wochenansicht",
        "monthly": "Monatsansicht",
        "yearly": "Jahresansicht",
    }
    days_map = {
        "daily": 1,
        "weekly": 7,
        "monthly": 31,
        "yearly": None,
    }
    label = label_map.get(period_raw, "Gesamtansicht")
    days = days_map.get(period_raw, None)
    return label, days


def convert_currency(amount: float, from_currency: str, to_currency: str, rates: Dict[str, float]) -> float:
    if amount == 0 or not from_currency or not to_currency or from_currency == to_currency:
        return float(amount)
    direct = rates.get(f"{from_currency}/{to_currency}")
    if direct:
        return float(amount) * float(direct)
    reverse = rates.get(f"{to_currency}/{from_currency}")
    if reverse:
        try:
            return float(amount) / float(reverse)
        except ZeroDivisionError:
            return float(amount)
    return float(amount)


def calculate_lot_size(symbol: str, config: Dict) -> float:
    symbols_cfg = config.get("symbols", {})
    account_cfg = config.get("account", {})
    symbol_cfg = symbols_cfg.get(symbol, {})

    account_currency = account_cfg.get("currency", "EUR")
    exchange_rates = config.get("exchange_rates", {})

    balance = float(account_cfg.get("starting_balance", 10000.0))
    risk_percent = float(account_cfg.get("risk_percent", 1.0))
    risk_amount_account = balance * risk_percent / 100.0
    if risk_amount_account <= 0:
        return float(symbol_cfg.get("min_lot", 0.01))

    contract_size = float(symbol_cfg.get("contract_size", 100000.0)) or 100000.0
    leverage_raw = symbol_cfg.get("leverage", 30.0)
    if isinstance(leverage_raw, str) and ":" in leverage_raw:
        try:
            leverage = float(leverage_raw.split(":")[1])
        except ValueError:
            leverage = 30.0
    else:
        leverage = float(leverage_raw) if leverage_raw else 30.0
    if leverage <= 0:
        leverage = 30.0

    margin_currency = symbol_cfg.get("margin_currency")
    if not margin_currency and len(symbol) >= 3:
        margin_currency = symbol[:3].upper()
    if not margin_currency:
        margin_currency = account_currency

    margin_required_margin = contract_size / leverage
    margin_required_account = convert_currency(
        margin_required_margin, margin_currency, account_currency, exchange_rates
    )

    if margin_required_account <= 0:
        return float(symbol_cfg.get("min_lot", 0.01))

    lot = risk_amount_account / margin_required_account

    min_lot = float(symbol_cfg.get("min_lot", 0.01))
    max_lot = float(symbol_cfg.get("max_lot", 50.0))
    volume_step = float(symbol_cfg.get("volume_step", 0.01)) or 0.01

    if volume_step > 0:
        lot = round(lot / volume_step) * volume_step
    lot = max(min_lot, min(max_lot, lot))
    return max(lot, min_lot)


def compute_trade_statistics(
    symbol: str,
    df: pd.DataFrame,
    model,
    scaler,
    threshold: float,
    config: Dict,
    period_days: Optional[int],
    lot_size: float,
) -> Tuple[int, int, float, float]:
    if df.empty or model is None:
        return 0, 0, 0.0, 0.0

    features, _ = split_features_target(df)
    if features.empty:
        return 0, 0, 0.0, 0.0

    probs = model.predict_proba(scaler.transform(features))[:, 1]
    signals = probs >= threshold
    if signals.sum() == 0:
        return 0, 0, 0.0, 0.0

    trades = df.loc[signals].copy()
    trades["prob"] = probs[signals]

    if trades.empty:
        return 0, 0, 0.0, 0.0

    if period_days is not None and not trades.empty:
        cutoff = trades.index.max() - pd.Timedelta(days=period_days)
        trades = trades.loc[trades.index >= cutoff]
        if trades.empty:
            return 0, 0, 0.0, 0.0

    symbol_cfg = (config.get("symbols") or {}).get(symbol, {})
    contract_size = float(symbol_cfg.get("contract_size", 100000.0)) or 100000.0
    quote_currency = symbol_cfg.get("quote_currency", config.get("account", {}).get("currency", "EUR"))
    account_currency = config.get("account", {}).get("currency", "EUR")
    exchange_rates = config.get("exchange_rates", {})

    profits_quote = trades["future_return"] * trades["Close"] * contract_size * lot_size
    profits_account = profits_quote.apply(lambda x: convert_currency(x, quote_currency, account_currency, exchange_rates))

    trades_total = len(profits_account)
    if trades_total == 0:
        return 0, 0, 0.0, 0.0

    trades_won = int((profits_account > 0).sum())
    profit_total = float(profits_account.sum())
    winrate = trades_won / trades_total if trades_total else 0.0
    return trades_total, trades_won, profit_total, winrate


def process_symbol(
    symbol: str,
    data_root: Path,
    rules_root: Path,
    models_dir: Path,
    reports_dir: Path,
    settings: TrainingSettings,
    config: Dict,
    period_days: Optional[int],
    trading_enabled: bool,
) -> Optional[SymbolResult]:
    logging.info("=== Starte Training für %s ===", symbol)
    lot_size = calculate_lot_size(symbol, config)
    sl_variants = get_sl_variants(config)
    tp_value = get_symbol_tp_multiplier(config, symbol)

    if not trading_enabled:
        logging.info("%s: TradeActive per Config = FALSE → ML übersprungen", symbol)
        rule_info = build_basic_rule_info(
            lot_size=lot_size,
            sl_variants=sl_variants,
            tp_value=tp_value,
            intelligent_params={},
            trade_active=False,
            override_reason="TradeActive=false (config override)",
        )
        apply_symbol_tp_settings(rule_info, config, symbol)
        tree_lines = ["// TradeActive=false (config override) – ML deaktiviert"]
        signal_examples: List[Tuple[pd.Timestamp, float]] = []
        rules_count = export_rules(
            symbol,
            rules_dir=rules_root,
            rule_info=rule_info,
            tree_lines=tree_lines,
            signal_examples=signal_examples,
        )
        return SymbolResult(
            symbol=symbol,
            samples=0,
            positives=0,
            rules=rules_count,
            accuracy=0.0,
            trades_total=0,
            trades_won=0,
            profit_account=0.0,
            lot_size=lot_size,
            winrate=0.0,
        )

    df = prepare_dataset(symbol, data_root, settings)
    if df.empty:
        logging.warning("%s: Keine Daten nach Vorbereitung", symbol)
        return None
    directional = int((df["target"] != 0).sum())
    if directional < settings.min_positive:
        logging.warning("%s: zu wenige verwertbare Beispiele (%d < %d)", symbol, directional, settings.min_positive)
        return None
    X, y = split_features_target(df, symbol, config)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y,
        test_size=settings.test_size,
        random_state=settings.random_state,
        stratify=y if y.nunique() > 1 else None,
    )
    model, scaler = train_model(X_train, y_train)
    metrics = evaluate_model(model, scaler, X_test, y_test, symbol, reports_dir)
    df_signals = build_model_signals(df, model, scaler, settings.rule_threshold, symbol, config)

    rules_cfg = config.get("rules", {})
    min_trades = int(rules_cfg.get("min_trades", 50))
    min_winrate = float(rules_cfg.get("min_winrate", 0.6))

    best_rules = find_best_rule_parameters(
        df_signals,
        symbol,
        config,
        lot_size,
        min_trades,
        min_winrate,
        period_days,
        tp_value,
        sl_variants,
    )
    intelligent_params = compute_intelligent_parameters(df_signals, config, symbol)
    if best_rules:
        total_trades = best_rules["trades"]
        total_wins = best_rules["wins"]
        total_profit = best_rules["profit"]
        total_winrate = best_rules["winrate"]
        window_stats = compute_window_summary(best_rules.get("trades_df"), period_days)
        trade_active = window_stats["profit"] > 0 and window_stats["winrate"] >= min_winrate
        rule_info = {
            "tp": best_rules["tp"],
            "sl": best_rules["sl"],
            "trades": window_stats["trades"],
            "wins": window_stats["wins"],
            "profit_window": window_stats["profit"],
            "profit_total": total_profit,
            "winrate": window_stats["winrate"],
            "winrate_total": total_winrate,
            "trade_active": trade_active,
            "lot_size": lot_size,
            "intelligent_params": intelligent_params,
            "tp_mode": "atr",
        }
    else:
        rule_info = build_basic_rule_info(
            lot_size=lot_size,
            sl_variants=sl_variants,
            tp_value=tp_value,
            intelligent_params=intelligent_params,
            trade_active=False,
            override_reason=None,
        )

    apply_symbol_tp_settings(rule_info, config, symbol)

    tree_lines = export_decision_tree_lines(model)
    signal_examples = []
    if "model_prob" in df_signals.columns:
        top = df_signals[df_signals["signal"] != 0].nlargest(5, "model_prob")
        signal_examples = [(idx, float(row["model_prob"])) for idx, row in top.iterrows()]

    rules_count = export_rules(symbol, rules_dir=rules_root, rule_info=rule_info, tree_lines=tree_lines, signal_examples=signal_examples)
    save_model(symbol, model, scaler, models_dir)

    trades_total = rule_info["trades"]
    trades_won = rule_info["wins"]
    profit_total = rule_info["profit_window"]
    winrate = rule_info["winrate"]
    return SymbolResult(
        symbol=symbol,
        samples=int(len(df)),
        positives=directional,
        rules=rules_count,
        accuracy=metrics.get("accuracy", 0.0),
        trades_total=trades_total,
        trades_won=trades_won,
        profit_account=profit_total,
        lot_size=lot_size,
        winrate=winrate,
    )


def write_summary(results: List[SymbolResult], reports_dir: Path, trading_enabled: bool) -> None:
    reports_dir.mkdir(parents=True, exist_ok=True)
    summary_path = reports_dir / "training_summary.md"
    with summary_path.open("w", encoding='utf-8') as handle:
        handle.write("# Goldjunge Trainingsübersicht\n\n")
        if not trading_enabled:
            handle.write("_TradeActive=false – ML deaktiviert, nur Standby-Rules erstellt._\n\n")
        if not results:
            handle.write("Keine Symbole erfolgreich trainiert.\n")
            return
        handle.write("| Symbol | Samples | Positive | Rules | Accuracy | Trades | Winrate | Profit |\n")
        handle.write("|--------|---------|----------|-------|----------|--------|---------|--------|\n")
        for res in results:
            handle.write(
                f"| {res.symbol} | {res.samples} | {res.positives} | {res.rules} | {res.accuracy:.3f} | {res.trades_total} | {res.winrate:.2f} | {res.profit_account:.2f} |\n"
            )
    logging.info("Zusammenfassung gespeichert: %s", summary_path)


def format_currency(value: float, currency: str) -> str:
    symbol_map = {"EUR": "€", "USD": "$", "CHF": "CHF", "JPY": "¥", "GBP": "£"}
    symbol = symbol_map.get(currency.upper(), currency)
    rounded = int(round(value))
    abs_str = f"{abs(rounded):,}".replace(",", "")
    sign = "-" if rounded < 0 else ""
    if symbol in {"€", "$", "¥", "£"}:
        return f"{sign}{abs_str}{symbol}"
    return f"{sign}{abs_str} {symbol}"


def build_telegram_message(
    config: Dict,
    results: List[SymbolResult],
    failed_symbols: List[str],
    duration_minutes: float,
    period_label: str,
) -> str:
    trade_active_flag = bool(config.get("trade_active", True))
    account_cfg = config.get("account", {})
    account_currency = account_cfg.get("currency", "EUR")
    balance = float(account_cfg.get("starting_balance", 0.0))
    risk_percent = float(account_cfg.get("risk_percent", 0.0))
    risk_amount = balance * risk_percent / 100.0
    profit_target = account_cfg.get("profit_target")
    profit_target_text = (
        format_currency(float(profit_target), account_currency)
        if profit_target else "Keins"
    )

    total_profit = sum(res.profit_account for res in results)
    successful = [res for res in results if res.profit_account > 0]

    lines: List[str] = []
    if not trade_active_flag:
        lines.extend([
            "⚠️ TradeActive=false → Bot im Standby (nur statische Rules erstellt)",
            ""
        ])
    lines.extend([
        "🤖 Goldjunge Standard",
        "",
        f"🏦 Konto: {format_currency(balance, account_currency)}",
        f"💰 Einsatz: {format_currency(risk_amount, account_currency)}",
        f"🎯 Gewinnziel: {profit_target_text}",
        f"⏱️ Reporterstelldauer: {duration_minutes:.1f} min",
        f"📅 Zeitrahmen: {period_label}",
        f"✅ Erfolgreich: {len(successful)}",
        f"❌ Misserfolge: {len(failed_symbols)}",
        "",
        f"💰 Gesamtgewinn: {format_currency(total_profit, account_currency)}",
        "",
        "💰 PROFITABLE TRADES:",
    ])

    if successful:
        for res in sorted(successful, key=lambda r: r.profit_account, reverse=True):
            lines.append(
                f"{res.symbol} P:{format_currency(res.profit_account, account_currency)} "
                f"WR:{int(round(res.winrate * 100))}% Lot:{res.lot_size:.2f}"
            )
    else:
        lines.append("Keine profitablen Symbole gefunden.")

    return "\n".join(lines)


def send_telegram_summary(
    config: Dict,
    results: List[SymbolResult],
    failed_symbols: List[str],
    duration_minutes: float,
    period_label: str,
) -> None:
    telegram_cfg = config.get("telegram", {})
    if not telegram_cfg or not telegram_cfg.get("enabled", False):
        logging.info("Telegram deaktiviert oder nicht konfiguriert – überspringe Versand")
        return
    if not telegram_cfg.get("send_summary", True):
        logging.info("Telegram send_summary=False – überspringe Versand")
        return
    bot_token = telegram_cfg.get("bot_token")
    chat_ids = telegram_cfg.get("chat_ids") or []
    single_chat = telegram_cfg.get("chat_id")
    if single_chat and single_chat not in chat_ids:
        chat_ids.append(single_chat)
    if not bot_token or not chat_ids:
        logging.warning("Telegram-Konfiguration unvollständig (bot_token/chat_id[s])")
        return
    if requests is None:
        logging.warning("requests-Modul nicht verfügbar – Telegram-Versand nicht möglich")
        return

    message = build_telegram_message(config, results, failed_symbols, duration_minutes, period_label)
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    parse_mode = telegram_cfg.get("message_format", "Markdown")

    for chat_id in chat_ids:
        try:
            resp = requests.post(
                url,
                data={
                    "chat_id": chat_id,
                    "text": message,
                    "parse_mode": parse_mode,
                    "disable_web_page_preview": True,
                },
                timeout=15,
            )
            if resp.ok:
                logging.info("Telegram-Zusammenfassung versendet (%s)", chat_id)
            else:
                logging.warning("Telegram-Versand fehlgeschlagen: %s %s", resp.status_code, resp.text)
        except Exception as exc:
            logging.error("Telegram-Versand Exception (%s): %s", chat_id, exc)


def main():
    parser = argparse.ArgumentParser(description="Goldjunge Train-KI-Bot")
    parser.add_argument("--config", type=Path, default=CONFIG_DEFAULT)
    parser.add_argument("--data-dir", type=Path, default=None)
    parser.add_argument("--rules-dir", type=Path, default=None)
    parser.add_argument("--models-dir", type=Path, default=None)
    parser.add_argument("--reports-dir", type=Path, default=None)
    args = parser.parse_args()

    setup_logging()
    logging.info("Train-KI-Bot gestartet")

    config = load_config(args.config)
    settings = extract_training_settings(config)
    trading_enabled = bool(config.get("trade_active", True))
    symbols = list_config_symbols(config)
    if not symbols:
        logging.error("Keine Symbole in der Config gefunden")
        return

    period_label, period_days = get_reporting_period(config)
    paths_cfg = config.get("paths", {}) if isinstance(config, dict) else {}

    data_dir = args.data_dir or Path(paths_cfg.get("data_dir", DATA_DEFAULT))
    rules_dir = args.rules_dir or Path(paths_cfg.get("rules_dir", RULES_DEFAULT))
    models_dir = args.models_dir or Path(paths_cfg.get("models_dir", MODELS_DEFAULT))
    reports_dir = args.reports_dir or Path(paths_cfg.get("reports_dir", REPORTS_DEFAULT))

    results: List[SymbolResult] = []
    failed_symbols: List[str] = []

    training_started = time.time()

    for symbol in symbols:
        res = process_symbol(
            symbol,
            data_dir,
            rules_dir,
            models_dir,
            reports_dir,
            settings,
            config,
            period_days,
            trading_enabled,
        )
        if res:
            results.append(res)
        else:
            failed_symbols.append(symbol)

    write_summary(results, reports_dir, trading_enabled)

    duration_minutes = (time.time() - training_started) / 60.0 if results or failed_symbols else 0.0
    send_telegram_summary(config, results, failed_symbols, duration_minutes, period_label)
    try:
        with WELLDONE_PATH.open("w", encoding="utf-8") as welldone:
            timestamp = pd.Timestamp.now().strftime("%Y-%m-%d %H:%M:%S")
            welldone.write(f"Train-KI-Bot completed on {timestamp}\n")
            welldone.write(f"Symbols trained: {len(results)}\n")
        logging.info("welldone.txt geschrieben: %s", WELLDONE_PATH)
    except Exception as exc:
        logging.error("Konnte welldone.txt nicht schreiben: %s", exc)
    logging.info("Train-KI-Bot beendet")


if __name__ == "__main__":
    main()
