#!/usr/bin/env python3
"""
TKB-config-Bearbeitung.py

Ein einziges, zentrales Config-File für Goldjunge: TKB-config.json

Funktionen:
  - --init                 Erstellt eine neue Grundkonfiguration
  - --import-symbols CSV   Importiert Symbol-Parameter aus CSV (z.B. aus GoldReport/SymbolDataExport.csv)
  - --set key=val [...]    Setzt Felder per Dot-Path (z.B. paths.rules_dir=../rules)
  - --add-symbol SYM       Fügt ein Symbol mit Defaultparametern hinzu
  - --remove-symbol SYM    Entfernt ein Symbol
  - --update-news-triggers Updates all symbols with Goldjunge-style news triggers
  - --summary              Zeigt kurze Zusammenfassung

Beispiel:
  python3 TKB-config-Bearbeitung.py --init
  python3 TKB-config-Bearbeitung.py --import-symbols ../Goldjunge-Bak/SymbolDataExport.csv
  python3 TKB-config-Bearbeitung.py --set paths.mt5_path="C:/Pfad/zu/MetaTrader"
"""
import argparse, json, os, sys, csv, io

CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'TKB-config.json')

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
        "project": {"name": "Sharrow Trading System", "version": "1.0"},
        "paths": {
            "mt5_path": "C:/Program Files/MetaTrader 5",
            "mt5_files_subpath": "MQL5/Files",
            "mt5_logs_subpath": "MQL5/Logs",
            "python_bin": "python3"
        },
        "news": {"provider": "manual", "keywords": {"hawkish":"BUY","dovish":"SELL","rate hike":"BUY","rate cut":"SELL"}},
        "features": {"stoch_k": 14, "stoch_d": 3, "stoch_slow": 3, "adx": 14, "atr": 14},
        "train": {"split_ratio": 0.8, "walk_forward_months": 6, "target_metric": "winrate"},
        "rules": {"min_winrate": 0.7},
        "symbols": {
            "EURUSD": {
                "pip_size": 0.0001,
                "min_lot": 0.01,
                "max_lot": 50.0,
                "volume_step": 0.01,
                "quote_currency": "USD",
                "contract_size": 100000,
                "asset_type": "FOREX",
                "news_triggers": create_news_triggers("EURUSD", "FOREX")
            },
            "USDJPY": {
                "pip_size": 0.01,
                "min_lot": 0.01,
                "max_lot": 50.0,
                "volume_step": 0.01,
                "quote_currency": "JPY",
                "contract_size": 100000,
                "asset_type": "FOREX",
                "news_triggers": create_news_triggers("USDJPY", "FOREX")
            }
        }
    }

def create_news_triggers(symbol, asset_type="FOREX"):
    """
    Erstellt News-Trigger für ein Symbol automatisch basierend auf Asset-Type
    Portiert aus dem ursprünglichen Goldjunge-TKB-System
    """
    # Symbol-Parser für FOREX
    if len(symbol) == 6:  # EURUSD Format
        base_currency = symbol[:3]
        quote_currency = symbol[3:]
    else:
        base_currency = symbol
        quote_currency = "USD"  # Fallback
    
    # BASIS-TRIGGER für alle Asset-Types
    positive_sentiments = [
        "bullish", "positive", "strong", "strength", "growth", "recovery", "optimistic",
        "upbeat", "support", "supportive", "bid", "rally", "surge", "breakout", "break higher",
        "climb", "climbs", "climbing", "rise", "rises", "rising", "advance", "advances",
        "advancing", "soar", "soars", "soaring", "appreciates", "appreciation", "firmer",
        "firm", "upside", "gains", "gaining", "rebounds", "rebound", "bounces", "bounce",
        "lifts", "lift", "pushes higher"
    ]
    negative_sentiments = [
        "bearish", "negative", "weak", "weakness", "decline", "declines", "fall", "falls",
        "falling", "drop", "drops", "dropping", "slip", "slips", "slipping", "retreat",
        "retreats", "retreating", "selloff", "sell-off", "selling", "loss", "losses", "lower",
        "under pressure", "pressure", "downside", "profit-taking", "pullback", "pull-back",
        "panic", "crash", "dump", "collapse", "plunge", "plunges", "deteriorates", "risk-off"
    ]

    base_triggers = {
        "queries": [],
        "regions": [],
        "keywords": [],
        "central_banks": [],
        "economic_events": [],
        "sentiment_words": {
            "positive": positive_sentiments,
            "negative": negative_sentiments
        }
    }
    
    # FOREX-SPEZIFISCHE TRIGGER
    if asset_type == "FOREX":
        # Basis-Queries
        base_triggers["queries"] = [
            f"{base_currency} {quote_currency}",
            f"{base_currency}/{quote_currency}",
            f"{base_currency.lower()} {quote_currency.lower()}"
        ]
        
        # Regions basierend auf Währungen
        currency_regions = {
            "EUR": ["europe", "european", "eurozone", "ECB", "european central bank"],
            "USD": ["united states", "america", "federal reserve", "fed", "US"],
            "GBP": ["britain", "UK", "united kingdom", "bank of england", "BOE"],
            "JPY": ["japan", "japanese", "bank of japan", "BOJ", "tokyo"],
            "CHF": ["switzerland", "swiss", "swiss national bank", "SNB"],
            "AUD": ["australia", "australian", "reserve bank australia", "RBA"],
            "CAD": ["canada", "canadian", "bank of canada", "BOC"],
            "NZD": ["new zealand", "reserve bank new zealand", "RBNZ"]
        }
        
        base_triggers["regions"] = currency_regions.get(base_currency, []) + currency_regions.get(quote_currency, [])
        base_triggers["central_banks"] = [cb for cb in base_triggers["regions"] if any(x in cb.lower() for x in ["bank", "fed", "ecb", "boe", "boj", "snb", "rba", "boc", "rbnz"])]
        
        # Forex-spezifische Events
        base_triggers["economic_events"] = ["inflation", "interest rate", "unemployment", "GDP", "trade", "tariff"]
        
        # Brexit für GBP-Paare
        if "GBP" in [base_currency, quote_currency]:
            base_triggers["keywords"].append("brexit")
    
    # CRYPTO-SPEZIFISCHE TRIGGER  
    elif asset_type == "CRYPTO":
        crypto_names = {
            "BTC": ["bitcoin", "BTC"],
            "ETH": ["ethereum", "ETH", "smart contracts", "DeFi"],
            "XRP": ["ripple", "XRP", "cross border payments"],
            "SOL": ["solana", "SOL", "DeFi", "NFT", "web3"],
            "LTC": ["litecoin", "LTC", "digital silver"]
        }
        
        base_triggers["queries"] = crypto_names.get(base_currency, [f"{base_currency} cryptocurrency"])
        base_triggers["regions"] = ["global", "worldwide", "international"]
        base_triggers["keywords"] = ["cryptocurrency", "blockchain", "digital currency", "crypto regulation", "SEC", "ETF"]
        base_triggers["economic_events"] = ["regulation", "adoption", "institutional", "mining", "halving"]
    
    # METALS/OTHER DEAKTIVIERT - NUR FOREX + CRYPTO!
    else:
        print(f"⚠️ {symbol}: Asset-Type {asset_type} nicht unterstützt - News-Trigger minimal")
        base_triggers["queries"] = [symbol]
        base_triggers["regions"] = []
        base_triggers["keywords"] = []
        base_triggers["economic_events"] = []
    
    return base_triggers

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

    existing_symbols = set(cfg['symbols'].keys())
    seen_symbols = set()
    added_symbols = set()
    updated_symbols = set()

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
        asset_type = (row.get('asset_type') or row.get('AssetType') or row.get('asset_Type') or 'FOREX') or 'FOREX'
        asset_type = str(asset_type).strip().upper()
        if asset_type not in {"FOREX", "CRYPTO"}:
            asset_type = "FOREX"
        quote_currency = (row.get('quote_currency') or row.get('Quote') or row.get('QuoteCurrency') or 'USD') or 'USD'
        quote_currency = str(quote_currency).strip().upper()
        target = {
            "pip_size": pip,
            "min_lot": _f(row.get('MinLot', 0.01) or 0.01, 0.01),
            "max_lot": _f(row.get('MaxLot', 50.0) or 50.0, 50.0),
            "volume_step": _f(row.get('VolumeStep', 0.01) or 0.01, 0.01),
            "quote_currency": quote_currency,
            "contract_size": _f(row.get('ContractSize', 100000) or 100000, 100000),
            "asset_type": asset_type,
            "news_triggers": create_news_triggers(sym, asset_type)  # GOLDJUNGE-STYLE NEWS-TRIGGER GENERATION!
        }
        if sym in cfg['symbols']:
            updated_symbols.add(sym)
        else:
            added_symbols.add(sym)
        cfg['symbols'][sym] = target
        seen_symbols.add(sym)

    preserved_keys = {"symbols_description"}
    removed_symbols = sorted(sym for sym in existing_symbols - seen_symbols if sym not in preserved_keys)
    for sym in removed_symbols:
        cfg['symbols'].pop(sym, None)

    return cfg, sorted(added_symbols), sorted(updated_symbols), removed_symbols

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--init', action='store_true')
    ap.add_argument('--import-symbols')
    ap.add_argument('--set', nargs='*')
    ap.add_argument('--add-symbol')
    ap.add_argument('--remove-symbol')
    ap.add_argument('--update-news-triggers', action='store_true')
    ap.add_argument('--summary', action='store_true')
    args = ap.parse_args()

    if args.init:
        cfg = default_config()
        save(cfg)
        print(f"[OK] Neu erstellt: {CONFIG_PATH}")
        return 0

    cfg = load()

    if args.import_symbols:
        cfg, added, updated, removed = import_symbols(cfg, args.import_symbols)
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
        print(info)
        if added:
            print("    hinzugefügt: " + ", ".join(added))
        if updated:
            print("    aktualisiert: " + ", ".join(updated))
        if removed:
            print("    entfernt: " + ", ".join(removed))

    if args.set:
        for item in args.set:
            if '=' not in item:
                print(f"Ignoriere --set Eintrag ohne '=': {item}")
                continue
            k, v = item.split('=', 1)
            set_by_dot(cfg, k, coerce_value(v))
        save(cfg)
        print("[OK] Werte gesetzt.")

    if args.add_symbol:
        sym = args.add_symbol.upper()
        pip = 0.01 if 'JPY' in sym else 0.0001
        cfg['symbols'][sym] = {
            "pip_size": pip, 
            "min_lot": 0.01, 
            "max_lot": 50.0, 
            "volume_step": 0.01, 
            "quote_currency": "USD", 
            "contract_size": 100000,
            "asset_type": "FOREX",
            "news_triggers": create_news_triggers(sym, "FOREX")  # GOLDJUNGE-STYLE NEWS-TRIGGER GENERATION!
        }
        save(cfg)
        print(f"[OK] Symbol hinzugefügt: {sym} (mit News-Triggern)")

    if args.remove_symbol:
        sym = args.remove_symbol.upper()
        cfg['symbols'].pop(sym, None)
        save(cfg)
        print(f"[OK] Symbol entfernt: {sym}")

    if args.update_news_triggers:
        updated_count = 0
        for sym in cfg.get('symbols', {}):
            if sym == 'symbols_description':  # Skip description entry
                continue
            cfg['symbols'][sym]['news_triggers'] = create_news_triggers(sym, "FOREX")
            updated_count += 1
        save(cfg)
        print(f"[OK] News-Trigger aktualisiert für {updated_count} Symbole (Goldjunge-Style)")

    if args.summary:
        print(json.dumps({
            "symbols": list(cfg.get('symbols', {}).keys()),
            "paths": cfg.get('paths'),
            "news": {"provider": cfg.get('news',{}).get('provider','manual')},
        }, indent=2, ensure_ascii=False))

    return 0

if __name__ == '__main__':
    sys.exit(main())
