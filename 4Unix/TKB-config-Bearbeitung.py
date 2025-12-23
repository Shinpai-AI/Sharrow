#!/usr/bin/env python3
"""
TKB-config-Bearbeitung.py

Ein einziges, zentrales Config-File für Sharrow: TKB-config.json

Funktionen:
  - --init                 Erstellt eine neue Grundkonfiguration
  - --import-symbols CSV   Importiert Symbol-Parameter aus CSV (z.B. aus SharrowReport/SymbolDataExport.csv)
  - --set key=val [...]    Setzt Felder per Dot-Path (z.B. paths.rules_dir=../rules)
  - --add-symbol SYM       Fügt ein Symbol mit Defaultparametern hinzu
  - --remove-symbol SYM    Entfernt ein Symbol
  - --update-news-triggers Updates all symbols with Sharrow-style news triggers
  - --summary              Zeigt kurze Zusammenfassung

Beispiel:
  python3 TKB-config-Bearbeitung.py --init
  python3 TKB-config-Bearbeitung.py --import-symbols ../Sharrow-Bak/SymbolDataExport.csv
  python3 TKB-config-Bearbeitung.py --set paths.mt5_path="C:/Pfad/zu/MetaTrader"
"""
import argparse, json, os, sys, csv, io

# Helper definitions kept inline so the tool stays self-contained.
SUPPORTED_ASSET_TYPES = {"FOREX", "CRYPTO"}

POSITIVE_SENTIMENT_WORDS = [
    "bullish", "positive", "strong", "strength", "growth", "recovery",
    "optimistic", "upbeat", "support", "supportive", "bid", "rally",
    "surge", "breakout", "break higher", "climb", "climbs", "climbing",
    "rise", "rises", "rising", "advance", "advances", "advancing",
    "soar", "soars", "soaring", "appreciates", "appreciation", "firmer",
    "firm", "upside", "gains", "gaining", "rebounds", "rebound",
    "bounces", "bounce", "lifts", "lift", "pushes higher"
]

NEGATIVE_SENTIMENT_WORDS = [
    "bearish", "negative", "weak", "weakness", "decline", "declines",
    "fall", "falls", "falling", "drop", "drops", "dropping", "slip",
    "slips", "slipping", "retreat", "retreats", "retreating", "selloff",
    "sell-off", "selling", "loss", "losses", "lower", "under pressure",
    "pressure", "downside", "profit-taking", "pullback", "pull-back",
    "panic", "crash", "dump", "collapse", "plunge", "plunges",
    "deteriorates", "risk-off"
]

CURRENCY_REGIONS = {
    "AUD": ["australia", "australian", "reserve bank australia", "RBA"],
    "CAD": ["canada", "canadian", "bank of canada", "BOC"],
    "CHF": ["switzerland", "swiss", "swiss national bank", "SNB"],
    "EUR": ["europe", "european", "eurozone", "ECB", "european central bank"],
    "GBP": ["britain", "UK", "united kingdom", "bank of england", "BOE"],
    "JPY": ["japan", "japanese", "bank of japan", "BOJ", "tokyo"],
    "NZD": ["new zealand", "reserve bank new zealand", "RBNZ"],
    "USD": ["united states", "america", "federal reserve", "fed", "US"],
}

CRYPTO_QUERIES = {
    "BTC": ["bitcoin", "BTC"],
    "ETH": ["ethereum", "ETH", "smart contracts", "DeFi"],
    "XRP": ["ripple", "XRP", "cross border payments"],
    "SOL": ["solana", "SOL", "DeFi", "NFT", "web3"],
    "LTC": ["litecoin", "LTC", "digital silver"],
}

FOREX_ECON_EVENTS = ["inflation", "interest rate", "unemployment", "GDP", "trade", "tariff"]


def normalize_asset_type(asset_type, default="FOREX"):
    value = str(asset_type).strip().upper() if asset_type is not None else default
    return value if value in SUPPORTED_ASSET_TYPES else default


def split_symbol(symbol: str):
    cleaned = (symbol or "").strip().upper()
    if len(cleaned) >= 6 and cleaned[:3].isalpha() and cleaned[3:6].isalpha():
        return cleaned[:3], cleaned[3:6]
    return cleaned[:3], "USD"


def _derive_central_banks(regions):
    banks = []
    for region in regions:
        lower = region.lower()
        if any(token in lower for token in ["bank", "fed", "ecb", "boe", "boj", "snb", "rba", "boc", "rbnz"]):
            banks.append(region)
    return banks


def create_news_triggers(symbol: str, asset_type: str = "FOREX"):
    asset_type_up = normalize_asset_type(asset_type)
    base_currency, quote_currency = split_symbol(symbol)

    base = {
        "queries": [],
        "regions": [],
        "keywords": [],
        "central_banks": [],
        "economic_events": [],
        "sentiment_words": {
            "positive": POSITIVE_SENTIMENT_WORDS,
            "negative": NEGATIVE_SENTIMENT_WORDS,
        },
    }

    if asset_type_up == "FOREX":
        base["queries"] = [
            f"{base_currency} {quote_currency}",
            f"{base_currency}/{quote_currency}",
            f"{base_currency.lower()} {quote_currency.lower()}",
        ]
        regions = CURRENCY_REGIONS.get(base_currency, []) + CURRENCY_REGIONS.get(quote_currency, [])
        base["regions"] = regions
        base["central_banks"] = _derive_central_banks(regions)
        base["economic_events"] = FOREX_ECON_EVENTS
        keywords = []
        if "GBP" in {base_currency, quote_currency}:
            keywords.append("brexit")
        base["keywords"] = keywords
    elif asset_type_up == "CRYPTO":
        base["queries"] = CRYPTO_QUERIES.get(base_currency, [f"{base_currency} cryptocurrency"])
        base["regions"] = ["global", "worldwide", "international"]
        base["keywords"] = [
            "cryptocurrency", "blockchain", "digital currency", "crypto regulation", "SEC", "ETF"
        ]
        base["economic_events"] = ["regulation", "adoption", "institutional", "mining", "halving"]
    else:
        base["queries"] = [symbol]

    return base


def build_symbol_entry(symbol: str, asset_type: str = "FOREX", **overrides):
    asset_type_up = normalize_asset_type(asset_type)
    base_currency, quote_currency = split_symbol(symbol)
    pip_size = 0.01 if "JPY" in symbol.upper() else 0.0001
    tp_preset_override = overrides.pop("tp_settings", None) if "tp_settings" in overrides else None
    payload = {
        "pip_size": pip_size,
        "min_lot": 0.01,
        "max_lot": 50.0,
        "volume_step": 0.01,
        "quote_currency": quote_currency,
        "base_currency": base_currency,
        "contract_size": 100000,
        "asset_type": asset_type_up,
        "tp_settings": tp_preset_override or {
            "atr_multiplier": 1.0,
            "swing": False,
        },
    }
    payload.update({k: v for k, v in overrides.items() if v is not None})
    payload["asset_type"] = normalize_asset_type(payload.get("asset_type", asset_type_up))
    payload["news_triggers"] = create_news_triggers(symbol, payload["asset_type"])
    return payload


def iter_symbol_configs(symbols_block):
    for symbol, data in (symbols_block or {}).items():
        if str(symbol).lower() == "symbols_description":
            continue
        yield symbol, data


def list_config_symbols(config):
    symbols_block = config.get("symbols", {}) if isinstance(config, dict) else {}
    return [symbol for symbol, _ in iter_symbol_configs(symbols_block)]


def ensure_tp_settings(cfg: dict) -> int:
    symbols = cfg.get("symbols", {}) if isinstance(cfg, dict) else {}
    changed = 0
    for sym, sym_cfg in iter_symbol_configs(symbols):
        if not isinstance(sym_cfg, dict):
            continue
        block = sym_cfg.get("tp_settings")
        if not isinstance(block, dict):
            sym_cfg["tp_settings"] = {
                "atr_multiplier": 1.0,
                "swing": False,
            }
            changed += 1
        else:
            updated = False
            if "atr_multiplier" not in block:
                block["atr_multiplier"] = 1.0
                updated = True
            if "swing" not in block:
                block["swing"] = False
                updated = True
            if updated:
                changed += 1
    return changed


def detect_rules_dir(cfg: dict) -> str:
    paths_cfg = cfg.get("paths", {}) if isinstance(cfg, dict) else {}
    raw = paths_cfg.get("rules_dir")
    if raw:
        expanded = os.path.expanduser(str(raw))
        if not os.path.isabs(expanded):
            expanded = os.path.join(ROOT_DIR, expanded)
        return os.path.abspath(expanded)
    return DEFAULT_RULES_DIR


def parse_rules_tp(path: str):
    tp_mode = None
    tp_value = None
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as handle:
            for line in handle:
                stripped = line.strip()
                if not stripped or stripped.startswith('//'):
                    continue
                lower = stripped.lower()
                if lower.startswith('tp_mode'):
                    _, val = stripped.split(':', 1)
                    tp_mode = val.strip().lower()
                elif lower.startswith('tp'):
                    _, val = stripped.split(':', 1)
                    try:
                        tp_value = float(val.strip())
                    except Exception:
                        tp_value = None
                if tp_mode and (tp_value is not None or tp_mode == 'swing'):
                    break
    except Exception:
        return None, None
    return tp_mode, tp_value


def sync_tp_settings_from_rules(cfg: dict, rules_dir: str):
    symbols = cfg.get('symbols', {}) if isinstance(cfg, dict) else {}
    if not os.path.isdir(rules_dir):
        raise SystemExit(f"Rules-Verzeichnis nicht gefunden: {rules_dir}")
    updated_syms = []
    missing_rules = []
    for sym, sym_cfg in iter_symbol_configs(symbols):
        rules_path = os.path.join(rules_dir, f"rules_{sym}.txt")
        if not os.path.isfile(rules_path):
            missing_rules.append(sym)
            continue
        tp_mode, tp_value = parse_rules_tp(rules_path)
        if not tp_mode:
            continue
        sym_cfg.setdefault("tp_settings", {"atr_multiplier": 1.0, "swing": False})
        block = sym_cfg["tp_settings"]
        changed = False
        if tp_mode == 'swing':
            if block.get("swing") is not True:
                block["swing"] = True
                changed = True
            if tp_value is not None and block.get("atr_multiplier") != tp_value:
                block["atr_multiplier"] = tp_value
                changed = True
        else:
            if block.get("swing"):
                block["swing"] = False
                changed = True
            if tp_value is not None and block.get("atr_multiplier") != tp_value:
                block["atr_multiplier"] = tp_value
                changed = True
        if changed:
            updated_syms.append(sym)
    return updated_syms, missing_rules

CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'TKB-config.json')
LOG_FILE = os.path.join(os.path.dirname(__file__), 'TKB.log')
ROOT_DIR = os.path.dirname(__file__)
DEFAULT_RULES_DIR = ROOT_DIR


def log_msg(message: str, *, stdout: bool = True) -> None:
    line = f"{message}\n"
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as handle:
            handle.write(line)
    except Exception:
        pass
    if stdout:
        print(message)

def save(cfg, path=CONFIG_PATH):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)

def load(path=CONFIG_PATH):
    if not os.path.exists(path):
        raise SystemExit(f"Config nicht gefunden: {path}. Erst --init ausführen.")
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def default_config():
    return {
        "project": {"name": "Sharrow (Ray)", "version": "3.0"},
        "paths": {
            "mt5_path": "/home/shinpai/.wine/drive_c/Program Files/MetaTrader 5",
            "mt5_files_subpath": "MQL5/Files",
            "mt5_logs_subpath": "MQL5/Logs",
            "python_bin": "/usr/bin/python3",
        },
        "news": {
            "provider": "manual",
            "keywords": {
                "hawkish": "BUY",
                "dovish": "SELL",
                "rate hike": "BUY",
                "rate cut": "SELL",
            },
        },
        "news_bot": {
            "lookback_days": 30,
            "max_positive_triggers": 10,
            "max_negative_triggers": 10,
        },
        "features": {
            "stoch_k": 14,
            "stoch_d": 3,
            "stoch_slow": 3,
            "adx": 14,
            "atr": 14,
        },
        "train": {
            "split_ratio": 0.8,
            "walk_forward_months": 6,
            "target_metric": "winrate",
        },
        "rules": {"min_winrate": 0.7},
        "symbols": {
            "EURUSD": build_symbol_entry("EURUSD"),
            "USDJPY": build_symbol_entry("USDJPY"),
        },
    }

def coerce_value(s):
    if s.lower() in ("true","false"): return s.lower()=="true"
    try:
        if "." in s: return float(s)
        return int(s)
    except: return s

def set_by_dot(cfg, dotkey, value):
    keys = dotkey.split('.')
    cur = cfg
    for k in keys[:-1]:
        if k not in cur or not isinstance(cur[k], dict):
            cur[k] = {}
        cur = cur[k]
    cur[keys[-1]] = value

def import_symbols(cfg, csv_path):
    if not os.path.exists(csv_path):
        raise SystemExit(f"CSV nicht gefunden: {csv_path}")
    # Encoding-robust: BOM/utf-16/utf-8-sig/latin-1 Fallback
    with open(csv_path, 'rb') as fb:
        raw = fb.read()
    enc = 'utf-8'
    if raw.startswith(b'\xff\xfe') or raw.startswith(b'\xfe\xff'):
        enc = 'utf-16'
    elif raw.startswith(b'\xef\xbb\xbf'):
        enc = 'utf-8-sig'
    else:
        try:
            raw.decode('utf-8')
            enc = 'utf-8'
        except Exception:
            enc = 'latin-1'
    text = raw.decode(enc, errors='replace')
    sample = text[:2048]
    delimiter = ';' if ';' in sample else ','
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)

    if 'symbols' not in cfg or not isinstance(cfg['symbols'], dict):
        cfg['symbols'] = {}

    existing_symbols = {sym for sym, _ in iter_symbol_configs(cfg['symbols'])}
    seen_symbols = set()
    added_symbols = set()
    updated_symbols = set()
    exchange_rates = dict(cfg.get('exchange_rates', {}))
    exchange_updates = set()

    for row in reader:
        sym = row.get('Symbol') or row.get('symbol') or row.get('SYMBOL')
        if not sym:
            continue
        sym = sym.strip().upper()
        pip = 0.01 if 'JPY' in sym else 0.0001
        def _f(x, default):
            try:
                return float(x)
            except Exception:
                return default
        asset_type = normalize_asset_type(row.get('asset_type') or row.get('AssetType') or row.get('asset_Type'))
        base_currency = (row.get('base_currency') or row.get('BaseCurrency') or row.get('baseCurrency') or '') or ''
        base_currency = str(base_currency).strip().upper()
        quote_currency = (row.get('quote_currency') or row.get('Quote') or row.get('QuoteCurrency') or 'USD') or 'USD'
        quote_currency = str(quote_currency).strip().upper()
        mid_raw = (row.get('mid_price') or row.get('MidPrice') or row.get('midPrice') or row.get('Mid_Price'))
        mid_price = _f(mid_raw, None)
        existing_entry = cfg['symbols'].get(sym, {})
        target = build_symbol_entry(
            sym,
            asset_type=asset_type,
            pip_size=pip,
            min_lot=_f(row.get('MinLot', 0.01) or 0.01, 0.01),
            max_lot=_f(row.get('MaxLot', 50.0) or 50.0, 50.0),
            volume_step=_f(row.get('VolumeStep', 0.01) or 0.01, 0.01),
            quote_currency=quote_currency,
            contract_size=_f(row.get('ContractSize', 100000) or 100000, 100000),
            base_currency=base_currency or None,
        )
        previous_tp = existing_entry.get("tp_settings") if isinstance(existing_entry, dict) else None
        if isinstance(previous_tp, dict) and previous_tp:
            merged_tp = target.get("tp_settings", {}).copy()
            merged_tp.update({k: v for k, v in previous_tp.items() if v is not None})
            target["tp_settings"] = merged_tp

        if sym in cfg['symbols']:
            updated_symbols.add(sym)
        else:
            added_symbols.add(sym)
        cfg['symbols'][sym] = target
        seen_symbols.add(sym)

        if base_currency and quote_currency and mid_price and mid_price > 0:
            pair_key = f"{base_currency}/{quote_currency}"
            exchange_rates[pair_key] = mid_price
            exchange_updates.add(pair_key)
            reverse_key = f"{quote_currency}/{base_currency}"
            try:
                exchange_rates[reverse_key] = 1.0 / mid_price
                exchange_updates.add(reverse_key)
            except ZeroDivisionError:
                pass

    removed_symbols = sorted(existing_symbols - seen_symbols)
    for sym in removed_symbols:
        cfg['symbols'].pop(sym, None)

    if exchange_updates:
        cfg['exchange_rates'] = exchange_rates

    ensure_tp_settings(cfg)
    return cfg, sorted(added_symbols), sorted(updated_symbols), removed_symbols, sorted(exchange_updates)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--init', action='store_true')
    ap.add_argument('--import-symbols')
    ap.add_argument('--set', nargs='*')
    ap.add_argument('--add-symbol')
    ap.add_argument('--remove-symbol')
    ap.add_argument('--update-news-triggers', action='store_true')
    ap.add_argument('--ensure-tp-settings', action='store_true')
    ap.add_argument('--sync-tp-from-rules', action='store_true')
    ap.add_argument('--summary', action='store_true')
    args = ap.parse_args()

    if args.init:
        cfg = default_config()
        save(cfg)
        log_msg(f"[OK] Neu erstellt: {CONFIG_PATH}")
        return 0

    cfg = load()

    if args.import_symbols:
        cfg, added, updated, removed, fx_updates = import_symbols(cfg, args.import_symbols)
        save(cfg)
        summary = []
        if added:
            summary.append(f"+{len(added)} neu")
        if updated:
            summary.append(f"~{len(updated)} aktualisiert")
        if removed:
            summary.append(f"-{len(removed)} entfernt")
        info = f"[OK] Symbole importiert aus {args.import_symbols}"
        if summary:
            info += " (" + ", ".join(summary) + ")"
        log_msg(info)
        if added:
            log_msg("    hinzugefügt: " + ", ".join(added))
        if updated:
            log_msg("    aktualisiert: " + ", ".join(updated))
        if removed:
            log_msg("    entfernt: " + ", ".join(removed))
        if fx_updates:
            log_msg(f"    FX aktualisiert: {len(fx_updates)} Paare")

    if args.set:
        for item in args.set:
            if '=' not in item:
                log_msg(f"Ignoriere --set Eintrag ohne '=': {item}")
                continue
            k, v = item.split('=', 1)
            set_by_dot(cfg, k, coerce_value(v))
        save(cfg)
        log_msg("[OK] Werte gesetzt.")

    if args.add_symbol:
        sym = args.add_symbol.upper()
        cfg.setdefault('symbols', {})
        cfg['symbols'][sym] = build_symbol_entry(sym)
        save(cfg)
        log_msg(f"[OK] Symbol hinzugefügt: {sym} (mit News-Triggern)")

    if args.remove_symbol:
        sym = args.remove_symbol.upper()
        cfg['symbols'].pop(sym, None)
        save(cfg)
        log_msg(f"[OK] Symbol entfernt: {sym}")

    if args.update_news_triggers:
        updated_count = 0
        for sym, sym_cfg in iter_symbol_configs(cfg.get('symbols', {})):
            asset_type = normalize_asset_type(sym_cfg.get('asset_type'))
            sym_cfg['news_triggers'] = create_news_triggers(sym, asset_type)
            updated_count += 1
        save(cfg)
        log_msg(f"[OK] News-Trigger aktualisiert für {updated_count} Symbole (Sharrow-Style)")

    if args.ensure_tp_settings:
        count = ensure_tp_settings(cfg)
        if count > 0:
            save(cfg)
        log_msg(f"[OK] TP-Settings geprüft/ergänzt für {count} Symbole")

    if args.sync_tp_from_rules:
        rules_dir = detect_rules_dir(cfg)
        updated_syms, missing_rules = sync_tp_settings_from_rules(cfg, rules_dir)
        if updated_syms:
            save(cfg)
        log_msg(f"[OK] TP/Swing aus Rules übernommen ({len(updated_syms)} aktualisiert, Quelle: {rules_dir})")
        if updated_syms:
            log_msg("    aktualisiert: " + ", ".join(sorted(updated_syms)))
        if missing_rules:
            log_msg("    ohne Rules-Datei: " + ", ".join(sorted(missing_rules)))

    if args.summary:
        summary = json.dumps({
            "symbols": list_config_symbols(cfg),
            "paths": cfg.get('paths'),
            "news": {"provider": cfg.get('news',{}).get('provider','manual')},
        }, indent=2, ensure_ascii=False)
        log_msg(summary, stdout=False)
        print(summary)

    return 0

if __name__ == '__main__':
    sys.exit(main())
