import requests
from datetime import datetime, timedelta
import os
import re
import json
import time

# TKB NEWS BOT v3.0 (Goldjunge Autarke Edition)
# UNIVERSELLES NEWS-SYSTEM basierend auf TKB-config.json
# Automatische Symbol-Erkennung und intelligente Trigger-Generierung
# Multi-API Rate-Limiting mit dynamischer Symbol-Verteilung

# === GLOBAL CONFIGURATION ===
script_dir = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(script_dir, "TKB-config.json")
OUTPUT_DIR = script_dir
LOG_DIR = script_dir
MAX_POS_TRIGGERS = 10
MAX_NEG_TRIGGERS = 10
DAYS_LOOKBACK = 30  # 1 Monat für mehr relevante News


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
        
        symbols = config.get('symbols', {})
        # Entferne die Beschreibung aus der Symbol-Liste
        symbols.pop('symbols_description', None)
        
        print(f"✅ Config geladen: {len(symbols)} Symbole gefunden")
        return config
    except Exception as e:
        print(f"❌ Fehler beim Laden der Config: {e}")
        return None

def get_asset_api_mapping(symbols):
    """Mappt Symbole auf spezialisierte APIs basierend auf Asset-Type"""
    api_mapping = {}
    
    for symbol, symbol_data in symbols.items():
        if symbol == 'symbols_description':
            continue
            
        asset_type = symbol_data.get('asset_type', '').upper()
        
        if asset_type == 'FOREX':
            api_mapping[symbol] = 'forexnews'
        elif asset_type == 'CRYPTO':
            api_mapping[symbol] = 'cryptonews'
        else:
            # Metalle/Rohstoffe überspringen
            print(f"⚠️ {symbol}: Asset-Type {asset_type} nicht unterstützt - überspringe Symbol")
            continue
    
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
    base_currency = symbol_data.get('base_currency', '') if symbol_data else ''
    quote_currency = symbol_data.get('quote_currency', '') if symbol_data else ''
    
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
        "User-Agent": "Goldjunge-SpecializedNews-Bot",
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
    
    # ALLGEMEINE FINANCE-KEYWORDS (immer relevant)
    general_finance_keywords = [
        "central bank", "ecb", "federal reserve", "fed", "bank of england", "boe",
        "inflation", "interest rate", "monetary policy", "currency", "forex",
        "precious metals", "gold", "silver", "commodities", "safe haven",
        "cryptocurrency", "bitcoin", "ethereum", "blockchain", "crypto"
    ]
    
    # Konvertiere zu lowercase für Vergleich
    symbol_keywords_lower = [kw.lower() for kw in symbol_keywords]
    general_keywords_lower = [kw.lower() for kw in general_finance_keywords]
    
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
    
    # Verarbeite nur FOREX + CRYPTO Symbole
    for symbol, symbol_data in symbols.items():
        if symbol == 'symbols_description':
            continue
        
        # Filter: Nur FOREX und CRYPTO
        asset_type = symbol_data.get('asset_type', '').upper()
        if asset_type not in ['FOREX', 'CRYPTO']:
            print(f"⚠️ {symbol}: Asset-Type {asset_type} übersprungen (nur FOREX+CRYPTO)")
            continue
            
        try:
            news_triggers = symbol_data.get('news_triggers', {})
            if process_symbol(symbol, news_triggers, symbol_api_mapping, symbol_data, config):
                successful += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ {symbol}: Critical error - {e}")
            failed += 1
    
    # Erstelle Completion Signal für RUN-Script
    create_completion_signal(len(symbols) - 1)  # -1 für symbols_description
    
    print("\n" + "=" * 60)
    print(f"📈 NEWS UPDATE COMPLETE")
    print(f"✅ Successful: {successful}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Success Rate: {successful/(successful+failed)*100:.1f}%")
    print(f"📄 Signal file: welldone-News.txt created")
    print(f"🕐 Next update in 1 hour")

def run_scheduler():
    """Scheduler Thread für stündliche Updates"""
    print("⏰ Starting hourly scheduler...")
    while True:
        schedule.run_pending()
        time.sleep(60)  # Check every minute

def main():
    """Hauptfunktion: Stündliche Symbol-spezifische News Updates basierend auf Config"""
    print("🚀 GOLDJUNGE CONFIG-BASED NEWS BOT v3.0 - HOURLY MODE")
    print("=" * 60)
    
    # Config laden
    config = load_config()
    if not config:
        print("❌ Konfiguration konnte nicht geladen werden - Beende Script")
        return
    
    paths = config.get('paths', {}) if isinstance(config, dict) else {}
    base_dir = os.path.dirname(CONFIG_PATH)
    global OUTPUT_DIR, LOG_DIR
    OUTPUT_DIR = resolve_path(paths.get('news_dir'), base_dir)
    LOG_DIR = resolve_path(paths.get('logs_dir'), base_dir)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)
    
    symbols = config.get('symbols', {})
    symbol_count = len(symbols) - 1  # -1 für symbols_description
    
    # API-Mapping für spezialisierte APIs generieren
    symbol_api_mapping = get_asset_api_mapping(symbols)
    
    forex_count = sum(1 for api_type in symbol_api_mapping.values() if api_type == 'forexnews')
    crypto_count = sum(1 for api_type in symbol_api_mapping.values() if api_type == 'cryptonews')
    
    print(f"📊 Processing {len(symbol_api_mapping)} symbols: {forex_count} FOREX + {crypto_count} CRYPTO")
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