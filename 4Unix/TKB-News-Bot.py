import requests
from datetime import datetime, timedelta
import os
import re
import json
import time

# Inline helpers keep the bot self-contained and consistent with config tooling.
SUPPORTED_ASSET_TYPES = {"FOREX", "CRYPTO"}
GENERAL_FINANCE_KEYWORDS = [
    "central bank", "ecb", "federal reserve", "fed", "bank of england", "boe",
    "inflation", "interest rate", "monetary policy", "currency", "forex",
    "precious metals", "gold", "silver", "commodities", "safe haven",
    "cryptocurrency", "bitcoin", "ethereum", "blockchain", "crypto"
]

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

    payload = {
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
        payload["queries"] = [
            f"{base_currency} {quote_currency}",
            f"{base_currency}/{quote_currency}",
            f"{base_currency.lower()} {quote_currency.lower()}",
        ]
        regions = CURRENCY_REGIONS.get(base_currency, []) + CURRENCY_REGIONS.get(quote_currency, [])
        payload["regions"] = regions
        payload["central_banks"] = _derive_central_banks(regions)
        payload["economic_events"] = FOREX_ECON_EVENTS
        keywords = []
        if "GBP" in {base_currency, quote_currency}:
            keywords.append("brexit")
        payload["keywords"] = keywords
    elif asset_type_up == "CRYPTO":
        payload["queries"] = CRYPTO_QUERIES.get(base_currency, [f"{base_currency} cryptocurrency"])
        payload["regions"] = ["global", "worldwide", "international"]
        payload["keywords"] = [
            "cryptocurrency", "blockchain", "digital currency", "crypto regulation", "SEC", "ETF"
        ]
        payload["economic_events"] = ["regulation", "adoption", "institutional", "mining", "halving"]
    else:
        payload["queries"] = [symbol]

    return payload


def iter_symbol_configs(symbols_block):
    for symbol, data in (symbols_block or {}).items():
        if str(symbol).lower() == "symbols_description":
            continue
        yield symbol, data


def list_config_symbols(config):
    block = config.get('symbols', {}) if isinstance(config, dict) else {}
    return [symbol for symbol, _ in iter_symbol_configs(block)]

# TKB NEWS BOT v3.0 (Sharrow Autarke Edition)
# UNIVERSELLES NEWS-SYSTEM basierend auf TKB-config.json
# Automatische Symbol-Erkennung und intelligente Trigger-Generierung
# Multi-API Rate-Limiting mit dynamischer Symbol-Verteilung

# === GLOBAL CONFIGURATION ===
script_dir = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(script_dir, "TKB-config.json")
OUTPUT_DIR = script_dir
LOG_DIR = script_dir
DEFAULT_NEWS_SETTINGS = {
    "lookback_days": 30,
    "max_positive_triggers": 10,
    "max_negative_triggers": 10,
}
MAX_POS_TRIGGERS = DEFAULT_NEWS_SETTINGS["max_positive_triggers"]
MAX_NEG_TRIGGERS = DEFAULT_NEWS_SETTINGS["max_negative_triggers"]
DAYS_LOOKBACK = DEFAULT_NEWS_SETTINGS["lookback_days"]


def resolve_path(path_value, base_dir):
    if not path_value:
        return base_dir
    if not os.path.isabs(path_value):
        return os.path.normpath(os.path.join(base_dir, path_value))
    return path_value

# === SPEZIALISIERTE NEWS-API CONFIGURATION ===
# APIs werden aus TKB-config.json geladen - keine hardcoded Keys!

def load_config():
    """Lädt TKB-config.json und extrahiert Symbol-Informationen"""
    config_file = CONFIG_PATH
    
    if not os.path.exists(config_file):
        print(f"❌ TKB-config.json nicht gefunden: {config_file}")
        return None
    
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)

        symbol_count = len(list_config_symbols(config))
        print(f"✅ Config geladen: {symbol_count} Symbole gefunden")
        return config
    except Exception as e:
        print(f"❌ Fehler beim Laden der Config: {e}")
        return None


def apply_news_settings(config):
    """Setzt Laufzeit-Parameter aus der Config."""
    global DAYS_LOOKBACK, MAX_POS_TRIGGERS, MAX_NEG_TRIGGERS

    news_settings = {}
    if isinstance(config, dict):
        news_settings = config.get('news_bot') or config.get('news_settings') or {}

    DAYS_LOOKBACK = int(news_settings.get('lookback_days', DEFAULT_NEWS_SETTINGS['lookback_days']))
    MAX_POS_TRIGGERS = int(news_settings.get('max_positive_triggers', DEFAULT_NEWS_SETTINGS['max_positive_triggers']))
    MAX_NEG_TRIGGERS = int(news_settings.get('max_negative_triggers', DEFAULT_NEWS_SETTINGS['max_negative_triggers']))

def get_asset_api_mapping(symbols_block):
    """Mappt Symbole auf spezialisierte APIs basierend auf Asset-Type"""
    api_mapping = {}

    for symbol, symbol_data in iter_symbol_configs(symbols_block):
        asset_type = normalize_asset_type(symbol_data.get('asset_type'))

        if asset_type == 'FOREX':
            api_mapping[symbol] = 'forexnews'
        elif asset_type == 'CRYPTO':
            api_mapping[symbol] = 'cryptonews'
        else:
            print(f"⚠️ {symbol}: Asset-Type {asset_type} nicht unterstützt - überspringe Symbol")

    return api_mapping

def get_specialized_api(symbol, symbol_api_mapping, config):
    """Gibt die spezialisierte API-Config für ein Symbol aus der Config zurück"""
    api_type = symbol_api_mapping.get(symbol)
    if not api_type:
        print(f"❌ No API mapping found for symbol: {symbol}")
        return None
    
    api_settings = config.get('api_settings', {})
    api_config = api_settings.get(api_type)
    
    if not api_config:
        print(f"❌ API config not found for type: {api_type}")
        return None
    
    if not api_config.get('enabled', False):
        print(f"❌ API {api_type} is disabled in config")
        return None
        
    return api_config


def ensure_symbol_triggers(symbol: str, symbol_data: dict):
    """Sorgt dafür, dass News-Trigger für ein Symbol verfügbar sind."""
    triggers = symbol_data.get('news_triggers') if isinstance(symbol_data, dict) else None
    if not triggers or 'sentiment_words' not in triggers:
        asset_type = symbol_data.get('asset_type') if isinstance(symbol_data, dict) else None
        triggers = create_news_triggers(symbol, asset_type)
        if isinstance(symbol_data, dict):
            symbol_data['news_triggers'] = triggers
    return triggers

def build_query_from_triggers(symbol, news_triggers):
    """Baut News-Query aus Config-Triggern zusammen"""
    query_parts = []
    
    # Basis-Queries aus Config
    queries = news_triggers.get("queries", [])
    if queries:
        query_parts.extend(queries[:3])  # Max 3 für bessere Performance
    
    # Regions hinzufügen (begrenzt)
    regions = news_triggers.get("regions", [])
    if regions:
        query_parts.extend(regions[:2])  # Max 2 Regions
    
    # Keywords hinzufügen (begrenzt) 
    keywords = news_triggers.get("keywords", [])
    if keywords:
        query_parts.extend(keywords[:2])  # Max 2 Keywords
    
    # Fallback falls keine Trigger vorhanden
    if not query_parts:
        query_parts = [symbol, "finance", "trading"]
    
    return " ".join(query_parts)

def fetch_symbol_news(symbol, news_triggers, symbol_api_mapping, symbol_data=None, config=None):
    """Fetched News für ein spezifisches Symbol basierend auf spezialisierten APIs"""
    api_config = get_specialized_api(symbol, symbol_api_mapping, config)
    if not api_config:
        return {"status": "error", "totalResults": 0, "articles": []}
    
    api_type = symbol_api_mapping.get(symbol)
    api_key = api_config["api_key"]
    base_url = api_config["base_url"]
    max_items = api_config.get("max_items", 3)
    request_delay = api_config.get("request_delay", 1.0)
    
    # Query aus Config-Triggern bauen  
    query = build_query_from_triggers(symbol, news_triggers)
    from_date = (datetime.now() - timedelta(days=DAYS_LOOKBACK)).strftime("%Y-%m-%d")
    
    print(f"🎯 {symbol}: Using {api_type.upper()}")
    
    # Extrahiere Währungen aus symbol_data falls verfügbar
    base_currency, quote_currency = split_symbol(symbol)
    if symbol_data:
        base_currency = symbol_data.get('base_currency', base_currency) or base_currency
        quote_currency = symbol_data.get('quote_currency', quote_currency) or quote_currency
    
    # API-spezifische URL-Struktur
    if api_type == "forexnews":
        # ForexNewsAPI.com - API aus Config 
        currency_pair = f"{base_currency}-{quote_currency}" if base_currency and quote_currency else "EUR-USD"
        url = f"{base_url}?currencypair={currency_pair}&items={max_items}&token={api_key}"
    elif api_type == "cryptonews":
        # CryptoNews-API.com - API aus Config
        ticker = base_currency if base_currency in ["BTC", "ETH", "XRP", "LTC", "SOL"] else "BTC"
        url = f"{base_url}?tickers={ticker}&items={max_items}&token={api_key}"
    else:
        print(f"❌ {symbol}: Unbekannter API-Type: {api_type}")
        return {"status": "error", "totalResults": 0, "articles": []}
    
    headers = {
        "User-Agent": "Sharrow-SpecializedNews-Bot",
        "Accept": "application/json"
    }
    
    try:
        print(f"   🔍 Query: {query[:60]}...")
        print(f"   📡 API: {api_type} → {url[:80]}...")
        
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        data = response.json()
        
        # API-Response normalisieren
        articles = []
        if api_type == "forexnews":
            # ForexNewsAPI Format: direktes Array oder unter "data" key
            if isinstance(data, list):
                articles = data
            elif "data" in data:
                articles = data["data"]
            else:
                articles = data.get("articles", [])
        elif api_type == "cryptonews":
            # CryptoNewsAPI Format: direktes Array oder unter "data" key
            if isinstance(data, list):
                articles = data
            elif "data" in data:
                articles = data["data"] 
            else:
                articles = data.get("articles", [])
        
        print(f"📰 {symbol}: {len(articles)} articles from {api_type.upper()}")
        
        # Normalisiertes Format zurückgeben
        return {
            "status": "ok",
            "totalResults": len(articles),
            "articles": articles
        }
        
    except requests.exceptions.RequestException as e:
        print(f"❌ {api_type.upper()} fetch failed for {symbol}: {e}")
        return {"status": "error", "totalResults": 0, "articles": []}

def clean_text(text):
    """Text bereinigen"""
    if not isinstance(text, str):
        return ""
    return text.lower()

def clean_for_print(text):
    """Text für print bereinigen"""
    if not isinstance(text, str):
        return ""
    return text.encode('cp1252', errors='replace').decode('cp1252')

def extract_symbol_triggers(article, symbol, news_triggers):
    """Extrahiert Symbol-spezifische Trigger aus Artikel basierend auf Config"""
    title = clean_text(article.get("title", ""))
    description = clean_text(article.get("description", ""))
    source_name = clean_text(article.get("source", {}).get("name", ""))
    
    # Bereinigte Versionen für print
    clean_title = clean_for_print(article.get("title", ""))
    clean_source = clean_for_print(source_name)
    print(f"🔍 {symbol}: {clean_source} - {clean_title}")
    
    text = title + " " + description
    triggers = {}
    pos_count = 0
    neg_count = 0

    # INTELLIGENTER RELEVANZ-FILTER
    symbol_keywords = []
    symbol_keywords.extend(news_triggers.get("queries", []))
    symbol_keywords.extend(news_triggers.get("keywords", []))
    symbol_keywords.extend(news_triggers.get("regions", []))
    
    # Konvertiere zu lowercase für Vergleich
    symbol_keywords_lower = [kw.lower() for kw in symbol_keywords]
    general_keywords_lower = [kw.lower() for kw in GENERAL_FINANCE_KEYWORDS]
    
    # Prüfe Symbol-spezifische Keywords
    symbol_relevance = sum(1 for keyword in symbol_keywords_lower if keyword in text)
    
    # Prüfe allgemeine Finance-Keywords  
    general_relevance = sum(1 for keyword in general_keywords_lower if keyword in text)
    
    total_relevance = symbol_relevance + general_relevance
    
    if total_relevance == 0:
        print(f"⚠️ {symbol}: Article not relevant (no finance keywords found)")
        return None
    
    # Zeige welche Art von Relevanz gefunden wurde
    if symbol_relevance > 0 and general_relevance > 0:
        print(f"🎯 {symbol}: Article relevant (symbol:{symbol_relevance} + general:{general_relevance})")
    elif symbol_relevance > 0:
        print(f"🎯 {symbol}: Article relevant (symbol-specific:{symbol_relevance})")
    else:
        print(f"💼 {symbol}: Article relevant (general finance:{general_relevance})")
    
    relevance_score = total_relevance

    # Sentiment-Keywords aus Config holen
    sentiment_words = news_triggers.get("sentiment_words", {})
    positive_keywords = sentiment_words.get("positive", [])
    negative_keywords = sentiment_words.get("negative", [])

    # Positive Trigger
    for keyword in positive_keywords:
        if pos_count >= MAX_POS_TRIGGERS:
            break
        pattern = re.compile(re.escape(keyword), re.IGNORECASE)
        if pattern.search(text):
            triggers[keyword] = True
            pos_count += 1
            print(f"✅ {symbol}: Positive trigger '{keyword}' found")
        else:
            triggers[keyword] = False

    # Negative Trigger
    for keyword in negative_keywords:
        if neg_count >= MAX_NEG_TRIGGERS:
            break
        pattern = re.compile(re.escape(keyword), re.IGNORECASE)
        if pattern.search(text):
            triggers[keyword] = True
            neg_count += 1
            print(f"🔴 {symbol}: Negative trigger '{keyword}' found")
        else:
            triggers[keyword] = False

    # Relevanz-Score hinzufügen
    triggers["relevance_score"] = relevance_score
    triggers["symbol_specific"] = True
    
    return triggers if pos_count > 0 or neg_count > 0 else None

def save_symbol_triggers(symbol, triggers_list):
    """Speichert Symbol-spezifische Trigger"""
    filename = f"{symbol}_Info.txt"
    filepath = os.path.join(OUTPUT_DIR, filename)

    with open(filepath, "w", encoding="cp1252") as f:
        if not triggers_list:
            f.write("NoTriggers: true\n")
            f.write(f"Symbol: {symbol}\n")
            f.write(f"LastUpdate: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            print(f"📄 {symbol}: No triggers found - wrote to {filename}")
            return

        # Aggregierte Trigger
        aggregated = {}
        total_relevance = 0
        total_articles = len(triggers_list)
        
        for triggers in triggers_list:
            if triggers:
                total_relevance += triggers.get("relevance_score", 0)
                for key, value in triggers.items():
                    if key in ["relevance_score", "symbol_specific"]:
                        continue
                    if value:
                        aggregated[key] = True
                    elif key not in aggregated:
                        aggregated[key] = False

        # Schreibe Header
        f.write(f"Symbol: {symbol}\n")
        f.write(f"LastUpdate: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"ArticlesProcessed: {total_articles}\n")
        f.write(f"RelevanceScore: {total_relevance}\n")
        f.write(f"SymbolSpecific: true\n")
        
        # Schreibe Trigger
        has_trigger = False
        for key, value in aggregated.items():
            if value:
                has_trigger = True
            f.write(f"{key}: {str(value).lower()}\n")
        
        if not has_trigger:
            f.write("NoTriggers: true\n")
        
        print(f"📄 {symbol}: Triggers saved to {filename} (Relevance: {total_relevance})")

def process_symbol(symbol, news_triggers, symbol_api_mapping, symbol_data=None, config=None):
    """Verarbeitet News für ein einzelnes Symbol basierend auf Config"""
    print(f"\n🎯 Processing {symbol}...")
    
    # Rate limiting zwischen API calls - aus Config
    if config:
        api_type = symbol_api_mapping.get(symbol)
        api_config = config.get('api_settings', {}).get(api_type, {})
        delay = api_config.get('request_delay', 1.0)
        time.sleep(delay)
    else:
        time.sleep(1)
    
    news_data = fetch_symbol_news(symbol, news_triggers, symbol_api_mapping, symbol_data, config)
    
    if news_data.get("status") != "ok":
        print(f"❌ {symbol}: News fetch failed - {news_data.get('message', 'Unknown error')}")
        save_symbol_triggers(symbol, [])
        return False

    if news_data.get("totalResults", 0) == 0:
        print(f"📰 {symbol}: No news articles found")
        save_symbol_triggers(symbol, [])
        return False

    articles = news_data.get("articles", [])
    triggers_list = []
    
    for article in articles:
        triggers = extract_symbol_triggers(article, symbol, news_triggers)
        if triggers:
            triggers_list.append(triggers)
    
    save_symbol_triggers(symbol, triggers_list)
    return True

def create_completion_signal(symbol_count):
    """Erstellt welldone-News.txt Signal für RUN-Script"""
    signal_file = os.path.join(OUTPUT_DIR, "welldone-News.txt")
    try:
        with open(signal_file, "w", encoding="utf-8") as f:
            f.write(f"News update completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Symbols processed: {symbol_count}\n")
            f.write(f"Files created: {symbol_count} *_Info.txt files\n")
            f.write("Status: SUCCESS\n")
        print(f"✅ Created completion signal: welldone-News.txt")
    except Exception as e:
        print(f"❌ Failed to create completion signal: {e}")

def run_news_update(config, symbol_api_mapping):
    """Führt eine komplette News-Update-Runde durch basierend auf Config"""
    print(f"\n🚀 [{datetime.now().strftime('%H:%M:%S')}] GOLDJUNGE HOURLY NEWS UPDATE")
    print("=" * 60)
    
    successful = 0
    failed = 0
    symbols = config.get('symbols', {})

    total_symbols = len(symbol_api_mapping)

    for symbol, symbol_data in iter_symbol_configs(symbols):
        if symbol not in symbol_api_mapping:
            asset_type = normalize_asset_type(symbol_data.get('asset_type'))
            print(f"⚠️ {symbol}: Asset-Type {asset_type} übersprungen (nur FOREX+CRYPTO)")
            continue

        try:
            news_triggers = ensure_symbol_triggers(symbol, symbol_data)
            if process_symbol(symbol, news_triggers, symbol_api_mapping, symbol_data, config):
                successful += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ {symbol}: Critical error - {e}")
            failed += 1
    
    # Erstelle Completion Signal für RUN-Script
    create_completion_signal(total_symbols)
    
    print("\n" + "=" * 60)
    print(f"📈 NEWS UPDATE COMPLETE")
    attempts = successful + failed
    success_rate = (successful / attempts * 100.0) if attempts else 0.0
    print(f"✅ Successful: {successful}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Success Rate: {success_rate:.1f}%")
    print(f"📄 Signal file: welldone-News.txt created")
    print(f"🕐 Next update in 1 hour")

def main():
    """Hauptfunktion: Stündliche Symbol-spezifische News Updates basierend auf Config"""
    print("🚀 GOLDJUNGE CONFIG-BASED NEWS BOT v3.0 - HOURLY MODE")
    print("=" * 60)
    
    # Config laden
    config = load_config()
    if not config:
        print("❌ Konfiguration konnte nicht geladen werden - Beende Script")
        return
    apply_news_settings(config)
    
    paths = config.get('paths', {}) if isinstance(config, dict) else {}
    base_dir = os.path.dirname(CONFIG_PATH)
    global OUTPUT_DIR, LOG_DIR
    OUTPUT_DIR = resolve_path(paths.get('news_dir'), base_dir)
    LOG_DIR = resolve_path(paths.get('logs_dir'), base_dir)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)
    
    symbols_block = config.get('symbols', {})

    # API-Mapping für spezialisierte APIs generieren
    symbol_api_mapping = get_asset_api_mapping(symbols_block)
    forex_count = sum(1 for api_type in symbol_api_mapping.values() if api_type == 'forexnews')
    crypto_count = sum(1 for api_type in symbol_api_mapping.values() if api_type == 'cryptonews')

    total_symbols_configured = len(list_config_symbols(config))

    print(f"📊 Config contains {total_symbols_configured} symbols")
    print(f"🎯 Processing {len(symbol_api_mapping)} symbols: {forex_count} FOREX + {crypto_count} CRYPTO")
    print(f"🎯 Using specialized APIs from config: ForexNewsAPI + CryptoNewsAPI")
    print(f"🔍 Lookback period: {DAYS_LOOKBACK} days")
    print(f"📁 Output directory: {OUTPUT_DIR}")
    print(f"⏰ Update frequency: Every hour (24x per day per symbol)")
    print(f"📰 News triggers loaded from TKB-config.json")
    print("=" * 60)
    
    # Führe einmalig News Update durch (RUN-Script macht Scheduling)
    print("🎯 Running single news update...")
    run_news_update(config, symbol_api_mapping)
    
    print("✅ News update completed - Script finishing")
    print("📄 Check *_Info.txt files and welldone-News.txt signal")

def run_correlation_enhancement():
    """Post-Processing: Erweitere Cross-Pairs mit Correlation-Magic"""
    print("\n🧠 STARTING CORRELATION ENHANCEMENT...")
    print("=" * 60)
    
    # Import correlation engine logic
    from datetime import datetime
    
    # Major Pairs die direkte News haben
    MAJOR_PAIRS = {
        'EUR': 'EURUSD', 'GBP': 'GBPUSD', 'AUD': 'AUDUSD', 'NZD': 'NZDUSD',
        'USD': 'USDJPY', 'JPY': 'USDJPY', 'CHF': 'USDCHF', 'CAD': 'USDCAD'
    }
    
    # Cross-Pairs die berechnet werden sollen
    CROSS_PAIRS = [
        'EURCHF', 'EURGBP', 'EURCAD', 'EURJPY',
        'GBPCHF', 'GBPCAD', 'GBPJPY',
        'AUDCHF', 'AUDCAD', 'AUDJPY', 'NZDCHF', 'NZDCAD', 'NZDJPY',
        'CADCHF', 'CADJPY', 'CHFJPY'
    ]
    
    def load_major_news_data(symbol):
        file_path = os.path.join(OUTPUT_DIR, f"{symbol}_Info.txt")
        if not os.path.exists(file_path):
            return None
        
        news_data = {}
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if ':' in line:
                        key, value = line.split(':', 1)
                        key, value = key.strip(), value.strip()
                        if value.lower() == 'true':
                            news_data[key] = True
                        elif value.lower() == 'false':
                            news_data[key] = False
                        else:
                            news_data[key] = value
        except:
            return None
        return news_data
    
    def count_sentiment_signals(news_data, signal_type):
        if signal_type == 'bullish':
            keys = ['bullish', 'positive', 'strong', 'growth', 'recovery', 'optimistic', 'rally', 'surge', 'breakout', 'support']
        else:  # bearish
            keys = ['bearish', 'negative', 'weak', 'decline', 'crisis', 'panic', 'crash', 'dump', 'resistance', 'breakdown']
        return sum(1 for key in keys if news_data.get(key, False))
    
    def calculate_cross_correlation(base_currency, quote_currency):
        base_major = MAJOR_PAIRS.get(base_currency)
        quote_major = MAJOR_PAIRS.get(quote_currency)
        
        if not base_major or not quote_major:
            return None
            
        base_news = load_major_news_data(base_major)
        quote_news = load_major_news_data(quote_major)
        
        if not base_news or not quote_news:
            return None
        
        if base_news.get('NoTriggers') or quote_news.get('NoTriggers'):
            return None
        
        # Calculate sentiment strength
        base_bullish = count_sentiment_signals(base_news, 'bullish')
        base_bearish = count_sentiment_signals(base_news, 'bearish')
        quote_bullish = count_sentiment_signals(quote_news, 'bullish')
        quote_bearish = count_sentiment_signals(quote_news, 'bearish')
        
        # Currency strength calculation (with USD inversion logic)
        if base_major.endswith('USD'):
            base_strength = base_bullish - base_bearish
        else:
            base_strength = quote_bearish - quote_bullish  # Invert for USD pairs
            
        if quote_major.startswith('USD'):  
            quote_strength = quote_bearish - quote_bullish  # Invert for USD base
        else:
            quote_strength = quote_bullish - quote_bearish
        
        net_signal = base_strength - quote_strength
        
        result = {}
        if net_signal > 0:
            result['bullish'] = True
            result['bearish'] = False
            print(f"   ✅ {base_currency}/{quote_currency} → BULLISH (+{net_signal})")
        elif net_signal < 0:
            result['bullish'] = False  
            result['bearish'] = True
            print(f"   ✅ {base_currency}/{quote_currency} → BEARISH ({net_signal})")
        else:
            result['bullish'] = False
            result['bearish'] = False
            print(f"   ⚖️ {base_currency}/{quote_currency} → NEUTRAL (0)")
            
        return result
    
    def create_correlation_news_file(symbol, sentiment):
        file_path = os.path.join(OUTPUT_DIR, f"{symbol}_Info.txt")
        
        content = f"""Symbol: {symbol}
LastUpdate: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
ArticlesProcessed: 2
RelevanceScore: 2
SymbolSpecific: true
bullish: {str(sentiment.get('bullish', False)).lower()}
positive: false
strong: false
growth: false
recovery: false
optimistic: false
rally: false
surge: false
breakout: false
support: false
bearish: {str(sentiment.get('bearish', False)).lower()}
negative: false
weak: false
decline: false
crisis: false
panic: false
crash: false
dump: false
resistance: false
breakdown: false
"""
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"📄 Enhanced: {symbol}_Info.txt")
            return True
        except Exception as e:
            print(f"❌ Failed: {symbol}_Info.txt - {e}")
            return False
    
    # Process all cross pairs
    enhanced_count = 0
    for cross_pair in CROSS_PAIRS:
        base_currency = cross_pair[:3]
        quote_currency = cross_pair[3:]
        
        print(f"🎯 Processing {cross_pair}...")
        sentiment = calculate_cross_correlation(base_currency, quote_currency)
        
        if sentiment:
            if create_correlation_news_file(cross_pair, sentiment):
                enhanced_count += 1
        else:
            # Create NoTriggers file
            file_path = os.path.join(OUTPUT_DIR, f"{cross_pair}_Info.txt")
            try:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(f"NoTriggers: true\n")
                    f.write(f"Symbol: {cross_pair}\n") 
                    f.write(f"LastUpdate: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                print(f"📄 NoTriggers: {cross_pair}_Info.txt")
                enhanced_count += 1
            except:
                pass
    
    print("=" * 60)
    print(f"🧠 CORRELATION ENHANCEMENT COMPLETE")
    print(f"✅ Enhanced: {enhanced_count}/{len(CROSS_PAIRS)} cross-pairs")
    print(f"🎯 Cross-pairs now have intelligent news via correlation!")
    print("=" * 60)

if __name__ == "__main__":
    main()
    # Post-Processing: Add correlation intelligence
    run_correlation_enhancement()
