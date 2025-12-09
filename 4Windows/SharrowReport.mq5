//+------------------------------------------------------------------+
//| GoldReport.mq5 v4.0 – Sharrow Showcase Edition                |
//| Snapshot-basierter Trading Report Bot + Symbol Data Export      |
//| Herzstück des Sharrow Trading Systems                         |
//| Sharrow Timer Rhythm (kein Init-Export, nur Smart Scheduler)  |
//+------------------------------------------------------------------+
#property copyright "Shinpai-AI"
#property link      "https://github.com/Shinpai-AI"
#property version   "4.00"
#property description "Snapshot Trading Reports & Symbol Export – Sharrow Style"

//+------------------------------------------------------------------+
//| Enums - Sharrow Style                                         |
//+------------------------------------------------------------------+
enum ENUM_INTERVAL {
   INTERVAL_OFF = 0,     // Aus
   INTERVAL_DAILY = 1,   // Täglich
   INTERVAL_2_DAYS = 2,  // Alle 2 Tage (Mo, Mi, Fr, So)
   INTERVAL_3_DAYS = 3,  // Alle 3 Tage (Mo, Do, So)
   INTERVAL_4_DAYS = 4,  // Alle 4 Tage (Mo, Fr)
   INTERVAL_7_DAYS = 7   // Alle 7 Tage (So)
};

enum ENUM_HOUR {
   HOUR_0 = 0, HOUR_1 = 1, HOUR_2 = 2, HOUR_3 = 3, HOUR_4 = 4, HOUR_5 = 5, HOUR_6 = 6, 
   HOUR_7 = 7, HOUR_8 = 8, HOUR_9 = 9, HOUR_10 = 10, HOUR_11 = 11, HOUR_12 = 12, 
   HOUR_13 = 13, HOUR_14 = 14, HOUR_15 = 15, HOUR_16 = 16, HOUR_17 = 17, HOUR_18 = 18, 
   HOUR_19 = 19, HOUR_20 = 20, HOUR_21 = 21, HOUR_22 = 22, HOUR_23 = 23
};

enum ENUM_MINUTE {
   MINUTE_0 = 0, MINUTE_1 = 1, MINUTE_2 = 2, MINUTE_3 = 3, MINUTE_4 = 4, MINUTE_5 = 5, 
   MINUTE_6 = 6, MINUTE_7 = 7, MINUTE_8 = 8, MINUTE_9 = 9, MINUTE_10 = 10, MINUTE_11 = 11, 
   MINUTE_12 = 12, MINUTE_13 = 13, MINUTE_14 = 14, MINUTE_15 = 15, MINUTE_16 = 16, MINUTE_17 = 17, 
   MINUTE_18 = 18, MINUTE_19 = 19, MINUTE_20 = 20, MINUTE_21 = 21, MINUTE_22 = 22, MINUTE_23 = 23, 
   MINUTE_24 = 24, MINUTE_25 = 25, MINUTE_26 = 26, MINUTE_27 = 27, MINUTE_28 = 28, MINUTE_29 = 29, 
   MINUTE_30 = 30, MINUTE_31 = 31, MINUTE_32 = 32, MINUTE_33 = 33, MINUTE_34 = 34, MINUTE_35 = 35, 
   MINUTE_36 = 36, MINUTE_37 = 37, MINUTE_38 = 38, MINUTE_39 = 39, MINUTE_40 = 40, MINUTE_41 = 41, 
   MINUTE_42 = 42, MINUTE_43 = 43, MINUTE_44 = 44, MINUTE_45 = 45, MINUTE_46 = 46, MINUTE_47 = 47, 
   MINUTE_48 = 48, MINUTE_49 = 49, MINUTE_50 = 50, MINUTE_51 = 51, MINUTE_52 = 52, MINUTE_53 = 53, 
   MINUTE_54 = 54, MINUTE_55 = 55, MINUTE_56 = 56, MINUTE_57 = 57, MINUTE_58 = 58, MINUTE_59 = 59
};

enum ENUM_MONTH_DAY {
   MONTH_DAY_OFF = 0,    // Aus
   MONTH_DAY_1 = 1,      // 1.
   MONTH_DAY_2 = 2,      // 2.
   MONTH_DAY_3 = 3,      // 3.
   MONTH_DAY_4 = 4,      // 4.
   MONTH_DAY_5 = 5,      // 5.
   MONTH_DAY_6 = 6,      // 6.
   MONTH_DAY_7 = 7,      // 7.
   MONTH_DAY_8 = 8,      // 8.
   MONTH_DAY_9 = 9,      // 9.
   MONTH_DAY_10 = 10,    // 10.
   MONTH_DAY_11 = 11,    // 11.
   MONTH_DAY_12 = 12,    // 12.
   MONTH_DAY_13 = 13,    // 13.
   MONTH_DAY_14 = 14,    // 14.
   MONTH_DAY_15 = 15,    // 15.
   MONTH_DAY_16 = 16,    // 16.
   MONTH_DAY_17 = 17,    // 17.
   MONTH_DAY_18 = 18,    // 18.
   MONTH_DAY_19 = 19,    // 19.
   MONTH_DAY_20 = 20,    // 20.
   MONTH_DAY_21 = 21,    // 21.
   MONTH_DAY_22 = 22,    // 22.
   MONTH_DAY_23 = 23,    // 23.
   MONTH_DAY_24 = 24,    // 24.
   MONTH_DAY_25 = 25,    // 25.
   MONTH_DAY_26 = 26,    // 26.
   MONTH_DAY_27 = 27,    // 27.
   MONTH_DAY_28 = 28,    // 28.
   MONTH_DAY_29 = 29,    // 29.
   MONTH_DAY_30 = 30,    // 30.
   MONTH_DAY_31 = 31     // 31.
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== TELEGRAM MULTI-CHAT SETTINGS ==="
input string TelegramBotToken = "";     // Bot Token from @BotFather
input string TelegramChatID1 = "";      // Chat ID 1 (Primary)
input string TelegramChatID2 = "";      // Chat ID 2 (Optional)
input string TelegramChatID3 = "";      // Chat ID 3 (Optional)

input group "=== REPORT SCHEDULE ==="
input ENUM_INTERVAL ReportInterval = INTERVAL_7_DAYS;  // Report Interval (Sharrow Style)
input ENUM_MONTH_DAY ReportMonthDay = MONTH_DAY_OFF;   // Monatlicher Report-Tag
input ENUM_HOUR ReportHour = HOUR_16;                   // Report Hour
input ENUM_MINUTE ReportMinute = MINUTE_0;              // Report Minute

input group "=== SYMBOL DATA EXPORT ==="
input ENUM_INTERVAL ExportInterval = INTERVAL_2_DAYS;   // Symbol Export Interval
input ENUM_MONTH_DAY ExportMonthDay = MONTH_DAY_OFF;    // Monatlicher Export-Tag
input ENUM_HOUR ExportHour = HOUR_0;                    // Export Hour
input ENUM_MINUTE ExportMinute = MINUTE_0;              // Export Minute
input bool EnableSymbolExport = true;                   // Enable Symbol Data Export

input group "=== DEBUG SETTINGS ==="
input bool EnableDebugMode = false;                     // Debug-Modus (zeigt Snapshot-Details)

//+------------------------------------------------------------------+
//| Account Snapshot Structure                                       |
//+------------------------------------------------------------------+
struct AccountSnapshot
{
   datetime snapshot_time;
   double balance;
   double equity;
   double floating_profit;
   double margin_used;
   double margin_free;
   bool is_valid;
};

//+------------------------------------------------------------------+
//| Global Variables (SIMPLIFIED - NO INIT TIMER!)                  |
//+------------------------------------------------------------------+
AccountSnapshot current_snapshot;
AccountSnapshot last_snapshot;
datetime last_report_time = 0;
datetime last_debug_time = 0;
datetime last_export_time = 0;
datetime last_report_date = 0, last_export_date = 0;
bool timer_initialized = false;
bool snapshots_initialized = false;

//+------------------------------------------------------------------+
//| Smart Rhythm Analyzer - FROM SHARROW (SIMPLIFIED!)            |
//+------------------------------------------------------------------+
int GetTriggerDaysForInterval(ENUM_INTERVAL interval, int &trigger_days[]) {
   ArrayFree(trigger_days);
   
   if(interval == INTERVAL_DAILY) {
      int temp[] = {0, 1, 2, 3, 4, 5, 6};
      ArrayCopy(trigger_days, temp);
      return 7;
   }
   else if(interval == INTERVAL_2_DAYS) {
      int temp[] = {0, 2, 4, 6}; // Mo, Mi, Fr, So
      ArrayCopy(trigger_days, temp);
      return 4;
   }
   else if(interval == INTERVAL_3_DAYS) {
      int temp[] = {0, 3, 6}; // Mo, Do, So
      ArrayCopy(trigger_days, temp);
      return 3;
   }
   else if(interval == INTERVAL_4_DAYS) {
      int temp[] = {0, 4}; // Mo, Fr
      ArrayCopy(trigger_days, temp);
      return 2;
   }
   else if(interval == INTERVAL_7_DAYS) {
      int temp[] = {6}; // Nur Sonntag!
      ArrayCopy(trigger_days, temp);
      return 1;
   }
   
   return 0; // INTERVAL_OFF
}

bool IsRhythmTriggerToday(ENUM_INTERVAL interval, int current_day_since_monday) {
   if(interval == INTERVAL_OFF) return false;
   
   int trigger_days[];
   int count = GetTriggerDaysForInterval(interval, trigger_days);
   
   for(int i = 0; i < count; i++) {
      if(trigger_days[i] == current_day_since_monday) {
         return true;
      }
   }
   return false;
}

int FindNextRhythmTrigger(ENUM_INTERVAL interval, int current_day_since_monday) {
   if(interval == INTERVAL_OFF) return -1;
   
   int trigger_days[];
   int count = GetTriggerDaysForInterval(interval, trigger_days);
   
   // Finde nächsten Tag >= heute in dieser Woche
   for(int i = 0; i < count; i++) {
      if(trigger_days[i] >= current_day_since_monday) {
         return trigger_days[i] - current_day_since_monday; // Tage bis zum nächsten Trigger
      }
   }
   
   // Kein Trigger mehr diese Woche → erster Trigger nächste Woche
   return (7 - current_day_since_monday) + trigger_days[0];
}

// Helper function - From Sharrow.mq5
bool IsValidDay(int month, int day, int year)
{
    if(month < 1 || month > 12) return false;
    if(day < 1 || day > 31) return false;
    
    int days_in_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    
    // Check for leap year
    if(month == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)))
        days_in_month[1] = 29;
    
    return (day <= days_in_month[month - 1]);
}

//+------------------------------------------------------------------+
//| Symbol Data Export Functions - From SymbolDataExport.mq5        |
//+------------------------------------------------------------------+

// Funktion zum Prüfen, ob Symbol schon in Array ist
bool IsSymbolInArray(string symbol, string &symbols[], int size) {
   for (int i = 0; i < size; i++) {
      if (symbols[i] == symbol) return true;
   }
   return false;
}

// Asset-Typ basierend auf Symbol (Universal)
string GetAssetType(string symbol) {
   string upper = symbol;
   StringToUpper(upper);

   static const string crypto_list[] = {
      "BTC","ETH","XRP","SOL","ADA","LTC","DOGE","AVAX","LINK","DOT"
   };
   for(int i = 0; i < ArraySize(crypto_list); i++)
      if(StringFind(upper, crypto_list[i]) >= 0)
         return "CRYPTO";

   static const string metal_list[] = {
      "XAU","XAG","XPD","XPT","GOLD","SILVER"
   };
   for(int i = 0; i < ArraySize(metal_list); i++)
      if(StringFind(upper, metal_list[i]) >= 0)
         return "METAL";

   static const string commodity_list[] = {
      "USO","UKO","OIL","BRENT","WTI","CRUDE"
   };
   for(int i = 0; i < ArraySize(commodity_list); i++)
      if(StringFind(upper, commodity_list[i]) >= 0)
         return "COMMODITY";

   static const string index_list[] = {
      "US30","NAS","SPX","DAX","FTSE","NIKKEI"
   };
   for(int i = 0; i < ArraySize(index_list); i++)
      if(StringFind(upper, index_list[i]) >= 0)
         return "INDEX";

   static const string stock_list[] = {
      "AAPL","MSFT","GOOGL","AMZN","TSLA"
   };
   for(int i = 0; i < ArraySize(stock_list); i++)
      if(StringFind(upper, stock_list[i]) >= 0)
         return "STOCK";

   if(StringLen(upper) <= 5)
      return "STOCK";

   return "FOREX";
}

// Calc Mode als Text
string GetCalcModeText(ENUM_SYMBOL_CALC_MODE mode) {
   switch(mode) {
      case SYMBOL_CALC_MODE_FOREX: return "FOREX";
      case SYMBOL_CALC_MODE_CFD: return "CFD";
      case SYMBOL_CALC_MODE_FUTURES: return "FUTURES";
      case SYMBOL_CALC_MODE_CFDINDEX: return "CFD_INDEX";
      case SYMBOL_CALC_MODE_CFDLEVERAGE: return "CFD_LEVERAGE";
      case SYMBOL_CALC_MODE_EXCH_STOCKS: return "STOCKS";
      case SYMBOL_CALC_MODE_EXCH_FUTURES: return "EXCHANGE_FUTURES";
      case SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS: return "FUTURES_FORTS";
      default: return "OTHER";
   }
}

// Currency Detection (Universal)
string GetQuoteCurrency(string symbol) {
   string upper = symbol;
   StringToUpper(upper);

   if(StringLen(upper) == 6)
      return StringSubstr(upper, 3, 3);

   static const string currencies[] = {
      "USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD"
   };
   for(int i = 0; i < ArraySize(currencies); i++) {
      int pos = StringFind(upper, currencies[i]);
      if(pos > 0)
         return currencies[i];
   }
   return "USD";
}

string GetBaseCurrency(string symbol) {
   string upper = symbol;
   StringToUpper(upper);

   if(StringLen(upper) == 6)
      return StringSubstr(upper, 0, 3);

   static const string base_tokens[] = {
      "BTC","ETH","XRP","SOL","ADA","LTC","XAU","XAG","XPD","XPT","USO","UKO"
   };
   for(int i = 0; i < ArraySize(base_tokens); i++)
      if(StringFind(upper, base_tokens[i]) == 0)
         return base_tokens[i];

   if(StringLen(upper) >= 3)
      return StringSubstr(upper, 0, 3);

   return upper;
}

// Export Symbol Data - SICHERE VERSION mit Error-Handling
bool ExportSymbolData()
{
    Print("🚀 Starting SAFE Symbol Data Export...");

    string filename = "SymbolDataExport.csv";
    int handle = FileOpen(filename, FILE_WRITE | FILE_CSV, ';');
    if (handle == INVALID_HANDLE) {
        Print("❌ Fehler beim Öffnen der Datei: ", filename, " Error: ", GetLastError());
        return false;
    }

    // CSV-Header - ALLE Felder für KI-Verarbeitung
    FileWrite(handle,
             "symbol", "asset_type", "base_currency", "quote_currency", "decimal_places",
             "contract_size", "min_lot", "max_lot", "volume_step", "pip_size",
             "leverage", "calc_mode", "trade_mode", "margin_initial", "margin_maintenance",
             "tick_value", "tick_size", "point_value",
             "bid", "ask", "spread_absolute", "spread_percent", "spread_pips", "mid_price",
             "lot_value_base", "lot_value_margin_raw",
             "stops_level", "freeze_level",
             "swap_long", "swap_short", "swap_mode",
             "session_deals", "session_buy_orders", "session_sell_orders",
             "expiration_mode", "filling_mode", "order_mode",
             "account_currency", "margin_per_lot", "margin_currency");

    // SICHERE Chart-Iteration mit MAX_LIMIT
    long chart_id = ChartFirst();
    int symbol_count = 0;
    int max_charts = 50; // SAFETY LIMIT!
    string symbols[];
    ArrayResize(symbols, 0);

    Print("🔍 Starting chart iteration...");
    
    while (chart_id != -1 && chart_id != 0 && symbol_count < max_charts) {
        string symbol = ChartSymbol(chart_id);
        Print("🔍 Checking chart: ", chart_id, " Symbol: ", symbol);
        
        if (symbol != "" && !IsSymbolInArray(symbol, symbols, symbol_count)) {
            ArrayResize(symbols, symbol_count + 1);
            symbols[symbol_count] = symbol;
            symbol_count++;

            Print("🔍 Processing Symbol ", symbol_count, "/", max_charts, ": ", symbol);

            // BASIC Symbol Info (nur essentials)
            string asset_type = GetAssetType(symbol);
            string base_currency = GetBaseCurrency(symbol);
            string quote_currency = GetQuoteCurrency(symbol);
            int decimal_places = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            double pip_size = (decimal_places >= 4) ? 0.0001 : 0.01;

            double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

            double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
            ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
            string calc_mode_text = GetCalcModeText(calc_mode);
            double margin_initial = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
            double margin_maintenance = SymbolInfoDouble(symbol, SYMBOL_MARGIN_MAINTENANCE);

            double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
            double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            double point_value = SymbolInfoDouble(symbol, SYMBOL_POINT);

            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double spread_absolute = ask - bid;
            double spread_percent = (ask > 0 && bid > 0) ? (spread_absolute / ((bid + ask) / 2)) * 100 : 0;
            double spread_pips = spread_absolute / pip_size;
            double mid_price = (bid + ask) / 2;

            double lot_value_base = contract_size * mid_price;
            // ECHTE MT5-Margin-Werte verwenden - KEINE fehlerhafte Berechnung!
            double lot_value_margin_raw = margin_initial > 0 ? margin_initial : (lot_value_base / leverage);

            int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            int freeze_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

            double swap_long = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
            double swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
            int swap_mode = (int)SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);

            int session_deals = (int)SymbolInfoInteger(symbol, SYMBOL_SESSION_DEALS);
            int session_buy_orders = (int)SymbolInfoInteger(symbol, SYMBOL_SESSION_BUY_ORDERS);
            int session_sell_orders = (int)SymbolInfoInteger(symbol, SYMBOL_SESSION_SELL_ORDERS);

            int expiration_mode = (int)SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_MODE);
            int filling_mode = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
            int order_mode = (int)SymbolInfoInteger(symbol, SYMBOL_ORDER_MODE);
            
            // UNIVERSELLE ACCOUNT-WÄHRUNG DETECTION
            string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
            
            // ROBUSTE MT5-MARGIN-BERECHNUNG mit Retry-Logic
            const int MAX_RETRIES = 3;
            const int RETRY_DELAY_MS = 100;
            
            double margin_per_lot = 0.0;
            bool success = false;
            
            // Retry-Logic für OrderCalcMargin() - KEINE Endlosschleife!
            for (int i = 0; i < MAX_RETRIES && !success; i++) {
                if (OrderCalcMargin(ORDER_TYPE_BUY, symbol, 1.0, bid, margin_per_lot)) {
                    if (margin_per_lot > 0) {
                        success = true;
                        Print("✅ ", symbol, ": ECHTE Margin berechnet: ", margin_per_lot, " ", account_currency, " (Versuch ", i+1, ")");
                    }
                }
                if (!success && i < MAX_RETRIES - 1) {  // Nicht beim letzten Versuch
                    Print("⚠️ ", symbol, ": OrderCalcMargin Versuch ", i+1, " fehlgeschlagen, retry in 100ms...");
                    Sleep(RETRY_DELAY_MS);
                }
            }
            
            if (!success) {
                Print("❌ ", symbol, ": OrderCalcMargin FAILED nach ", MAX_RETRIES, " Versuchen! Calc-Mode: ", calc_mode_text);
                margin_per_lot = -1.0;  // ERROR marker - KEINE Fantasie-Zahlen!
            }
            
            // MARGIN-WÄHRUNG (Quote-Währung des Symbols)
            string margin_currency = quote_currency;

            // Basic Error checking
            if (bid <= 0 || ask <= 0) {
                Print("⚠️ ", symbol, ": Invalid bid/ask data - using defaults");
                bid = 1.0; ask = 1.0;
            }
            if (contract_size <= 0) {
                Print("⚠️ ", symbol, ": Invalid contract size - using default");
                contract_size = 1.0;
            }

            // CSV-Zeile schreiben - MIT NEUEN ACCOUNT-WÄHRUNG FELDERN
            FileWrite(handle,
                      symbol, asset_type, base_currency, quote_currency, decimal_places,
                      DoubleToString(contract_size, 4), DoubleToString(min_lot, 4), DoubleToString(max_lot, 4), 
                      DoubleToString(volume_step, 4), DoubleToString(pip_size, 4),
                      StringFormat("1:%.0f", leverage), calc_mode_text, "FULL",
                      DoubleToString(margin_initial, 2), DoubleToString(margin_maintenance, 2),
                      DoubleToString(tick_value, 5), DoubleToString(tick_size, 5), DoubleToString(point_value, 8),
                      DoubleToString(bid, 5), DoubleToString(ask, 5), DoubleToString(spread_absolute, 5),
                      DoubleToString(spread_percent, 3), DoubleToString(spread_pips, 1), DoubleToString(mid_price, 5),
                      DoubleToString(lot_value_base, 2), DoubleToString(lot_value_margin_raw, 2),
                      stops_level, freeze_level,
                      DoubleToString(swap_long, 2), DoubleToString(swap_short, 2), swap_mode,
                      session_deals, session_buy_orders, session_sell_orders,
                      expiration_mode, filling_mode, order_mode,
                      account_currency, DoubleToString(margin_per_lot, 2), margin_currency);
            
            Print("✅ ", symbol, " [", asset_type, "] exported successfully");
        }
        
        // SAFE Chart Navigation
        long next_chart = ChartNext(chart_id);
        if(next_chart == chart_id) {
            Print("⚠️ Chart iteration stuck - breaking loop");
            break;
        }
        chart_id = next_chart;
    }

    FileClose(handle);
    Print("🎯 SAFE Symbol Data Export completed!");
    Print("📈 Symbols processed: ", symbol_count, "/", max_charts);
    Print("📈 File: MQL5/Files/", filename);
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function (SHARROW STYLE - NO INIT TIMER)|
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🏆 GoldReport v3.0 - ULTIMATE Snapshot Edition + Symbol Export");
    Print("📸 Sharrow-Style Timer Logic - NO Init Timer!");
    
    // TELEGRAM VALIDATION - Multi-Chat Support
    bool telegram_configured = (StringLen(TelegramBotToken) > 0 && 
                                (StringLen(TelegramChatID1) > 0 || StringLen(TelegramChatID2) > 0 || StringLen(TelegramChatID3) > 0));
    
    int active_chats = 0;
    if(StringLen(TelegramChatID1) > 0) active_chats++;
    if(StringLen(TelegramChatID2) > 0) active_chats++;
    if(StringLen(TelegramChatID3) > 0) active_chats++;
    
    if(!telegram_configured)
    {
        Print("⚠️ WARNING: Telegram nicht konfiguriert - Reports werden deaktiviert!");
        Print("📋 Tipp: Bot Token und mindestens eine Chat ID in den Einstellungen setzen");
        Print("📈 Symbol Export funktioniert trotzdem normal!");
    }
    else
    {
        Print("✅ Telegram Multi-Chat configured: " + IntegerToString(active_chats) + " chat(s) active");
    }
    
    // Setup timer - every 10 seconds for debug heartbeat, every minute for reports
    int timer_interval = EnableDebugMode ? 10 : 30;  // 10 sec debug, 30 sec normal (für Export-Timing)
    if(!EventSetTimer(timer_interval))
    {
        Print("❌ ERROR: Failed to set timer!");
        return INIT_FAILED;
    }
    
    // Initialize snapshots
    InitializeSnapshots();
    
    // SHARROW STYLE: Sofortiger Export bei Initialisierung (OHNE 10s Timer!)
    if(EnableSymbolExport)
    {
        Print("🚀 SHARROW STYLE: Sofortiger Symbol Export bei Initialisierung...");
        bool export_success = ExportSymbolData();
        if(export_success)
        {
            Print("✅ INIT-EXPORT: Symbol Data Export erfolgreich abgeschlossen!");
            Print("📈 SymbolDataExport.csv erstellt in MQL5/Files/");
        }
        else
        {
            Print("❌ INIT-EXPORT: Symbol Data Export fehlgeschlagen!");
        }
        // WICHTIG: last_export_date NICHT setzen - dann funktioniert regulärer Export!
        last_export_time = TimeCurrent();  // Nur für Referenz
        Print("📈 Regulärer Export nach Zeitsteuerung weiterhin aktiv!");
    }
    
    timer_initialized = true;
    string interval_text = GetIntervalText(ReportInterval);
    Print("✅ GoldReport v3.0 initialized successfully!");
    
    if(telegram_configured)
    {
        Print("📅 Report Schedule: ", interval_text, " um ", ReportHour, ":", StringFormat("%02d", ReportMinute));
    }
    else
    {
        Print("🚫 Report Schedule: DEAKTIVIERT (Telegram nicht konfiguriert)");
    }
    
    Print("📊 Symbol Export: ", EnableSymbolExport ? "ENABLED" : "DISABLED");
    if(EnableSymbolExport)
    {
        string export_interval_text = GetIntervalText(ExportInterval);
        Print("📈 Export Schedule: ", export_interval_text, " um ", ExportHour, ":", StringFormat("%02d", ExportMinute));
    }
    Print("📸 First snapshot taken! Waiting for next report time...");
    
    if(EnableDebugMode)
    {
        Print("🔍 DEBUG MODE: Heartbeat wird alle 10 Sekunden angezeigt!");
        Print("💡 Zum Abstellen: EnableDebugMode = false setzen");
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(timer_initialized)
        EventKillTimer();
    
    Print("👋 GoldReport v3.0 stopped. Snapshots cleared from memory.");
    Print("📸 Next restart will create fresh snapshots!");
}

//+------------------------------------------------------------------+
//| Timer function - SHARROW STYLE (SIMPLIFIED!)                 |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    // DEBUG HEARTBEAT - Show every 10 seconds when debug is enabled
    if(EnableDebugMode)
    {
        if((current_time - last_debug_time) >= 10)  // Every 10 seconds
        {
            AccountSnapshot live_snapshot = TakeAccountSnapshot();
            Print("🔍 DEBUG HEARTBEAT - ", TimeToString(current_time, TIME_MINUTES), 
                  " | Balance: ", DoubleToString(live_snapshot.balance, 2), "€", 
                  " | Equity: ", DoubleToString(live_snapshot.equity, 2), "€",
                  " | Floating: ", DoubleToString(live_snapshot.floating_profit, 2), "€");
            last_debug_time = current_time;
        }
    }
    
    // REPORT & EXPORT LOGIC - Only check on minute boundaries (xx:xx:00)
    // FIX: Immer prüfen, nicht nur erste 10 Sekunden (für 60s Timer)
    if(true)  // Immer prüfen, unabhängig von Sekunden
    {
        if(EnableDebugMode) Print("🔍 DEBUG: Timer reached export logic check at ", TimeToString(current_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
        // SHARROW STYLE: EINFACHE Timer-Logik
        datetime now = current_time;
        MqlDateTime time_struct;
        TimeToStruct(now, time_struct);  // Verwende current_time (= TimeCurrent() von oben)
        
        // FIX: Verwende RECHNERZEIT für einheitliche Systeme!
        datetime local_now = TimeLocal();
        MqlDateTime local_time_struct;
        TimeToStruct(local_now, local_time_struct);
        if(EnableDebugMode) Print("🔍 DEBUG: Broker-Zeit: ", time_struct.hour, ":", StringFormat("%02d", time_struct.min), ", Rechner-Zeit: ", local_time_struct.hour, ":", StringFormat("%02d", local_time_struct.min));
        
        // Verwende RECHNERZEIT für alle Checks!
        time_struct = local_time_struct;
        now = local_now;
        
        // Calculate days since Monday for rhythm analyzer
        datetime last_monday = now - (now % 86400) - ((time_struct.day_of_week == 0 ? 6 : time_struct.day_of_week - 1) * 86400);
        int days_since_monday = (int)((now - last_monday) / 86400);
        if(EnableDebugMode) Print("🔍 DEBUG: Today is day ", days_since_monday, " since Monday, Time: ", time_struct.hour, ":", StringFormat("%02d", time_struct.min));
        
        // ===== EXPORT LOGIC - SHARROW STYLE =====
        bool export_triggered = false;
        if(EnableDebugMode) Print("🔍 DEBUG: Checking export trigger - Interval: ", (int)ExportInterval, ", Hour: ", (int)ExportHour, ", Minute: ", (int)ExportMinute);
        
        // Monatlicher Export-Tag hat Priorität
        if(ExportMonthDay != MONTH_DAY_OFF && time_struct.day == ExportMonthDay && 
           IsValidDay(time_struct.mon, time_struct.day, time_struct.year) &&
           MathAbs(time_struct.hour * 60 + time_struct.min - (ExportHour * 60 + ExportMinute)) <= 5) {
           export_triggered = true;
        } 
        // Smart Rhythm Check für Intervalle - DEBUG LOGIC
        bool rhythm_trigger = IsRhythmTriggerToday(ExportInterval, days_since_monday);
        int current_time_minutes = time_struct.hour * 60 + time_struct.min;
        int export_time_minutes = ExportHour * 60 + ExportMinute;
        int time_diff = MathAbs(current_time_minutes - export_time_minutes);
        
        if(EnableDebugMode) {
            Print("🔍 EXPORT DEBUG: MonthDay=", ExportMonthDay, ", Interval=", (int)ExportInterval, ", RhythmToday=", rhythm_trigger);
            Print("🔍 EXPORT DEBUG: CurrentTime=", current_time_minutes, "min (", time_struct.hour, ":", StringFormat("%02d", time_struct.min), "), ExportTime=", export_time_minutes, "min (", ExportHour, ":", StringFormat("%02d", ExportMinute), "), TimeDiff=", time_diff, "min");
        }
        
        if(ExportMonthDay == MONTH_DAY_OFF && ExportInterval != INTERVAL_OFF &&
           rhythm_trigger && time_diff <= 5) {
           export_triggered = true;
        }
        
        // EXPORT-PROTECTION: Einmal pro Tag (sinnvolle Blockade wieder aktiviert)
        string today_date = TimeToString(now, TIME_DATE);
        string last_export_date_str = TimeToString(last_export_date, TIME_DATE);
        bool export_already_done_today = (today_date == last_export_date_str);
        
        if(EnableDebugMode) {
            Print("🔍 DEBUG: Export triggered: ", export_triggered ? "YES" : "NO", ", EnableSymbolExport: ", EnableSymbolExport ? "YES" : "NO");
            Print("🔍 DEBUG: Today: ", today_date, ", LastExport: ", last_export_date_str, ", AlreadyDone: ", export_already_done_today ? "YES" : "NO");
        }
        
        if(EnableSymbolExport && export_triggered && !export_already_done_today) {
           int next_in_days = FindNextRhythmTrigger(ExportInterval, days_since_monday);
           Print("🎯 Smart Rhythm: Export-Tag erkannt! Nächster Trigger in ", next_in_days, " Tagen");
           Print("✅ Export-Timer ausgelöst für ", today_date, " um ", time_struct.hour, ":", StringFormat("%02d", time_struct.min));
           Print("🚀 Starte Symbol Data Export...");
           bool success = ExportSymbolData();
           if(success) {
               Print("✅ Symbol Data Export erfolgreich!");
           } else {
               Print("❌ Symbol Data Export fehlgeschlagen!");
           }
           last_export_time = now;
           last_export_date = now; // Blockiere weitere Exports heute
           Print("✅ Export abgeschlossen - nächster Export nach Zeitplan!");
        } else if(export_triggered && export_already_done_today) {
           if(EnableDebugMode) Print("⏭️ Export heute bereits erledigt - überspringe");
        }
        
        // ===== REPORT LOGIC - Only if Telegram configured =====
        bool telegram_configured = (StringLen(TelegramBotToken) > 0 && 
                                    (StringLen(TelegramChatID1) > 0 || StringLen(TelegramChatID2) > 0 || StringLen(TelegramChatID3) > 0));
        
        if(telegram_configured) {
            // Report Logic - Similar to Export
            bool report_triggered = false;
            
            // Monatlicher Report-Tag hat Priorität
            if(ReportMonthDay != MONTH_DAY_OFF && time_struct.day == ReportMonthDay && 
               IsValidDay(time_struct.mon, time_struct.day, time_struct.year) &&
               MathAbs(time_struct.hour * 60 + time_struct.min - (ReportHour * 60 + ReportMinute)) <= 1) {
               report_triggered = true;
            } 
            // Smart Rhythm Check für Intervalle
            else if(ReportMonthDay == MONTH_DAY_OFF && ReportInterval != INTERVAL_OFF &&
                    IsRhythmTriggerToday(ReportInterval, days_since_monday) &&
                    MathAbs(time_struct.hour * 60 + time_struct.min - (ReportHour * 60 + ReportMinute)) <= 1) {
               report_triggered = true;
            }
            
            // Check if report already done today
            string last_report_date_str = TimeToString(last_report_date, TIME_DATE);
            bool report_already_done_today = (today_date == last_report_date_str);
            
            if(report_triggered && !report_already_done_today) {
                string interval_text = GetIntervalText(ReportInterval);
                Print("✅ ", interval_text, " Report um ", ReportHour, ":", StringFormat("%02d", ReportMinute), " - Zeit für Snapshot-Report!");
                SendSnapshotReport();
                last_report_time = current_time;
                last_report_date = current_time;
                Print("✅ Report abgeschlossen und als erledigt markiert für ", today_date);
            } else if(report_triggered && report_already_done_today) {
                Print("⏭️ Report heute bereits erledigt (", last_report_date_str, ") - überspringe");
            }
        }
        
        // ===== RHYTHM DEBUG INFO (nur beim ersten Timer-Lauf) =====
        static bool rhythm_info_shown = false;
        if(!rhythm_info_shown) {
            string day_names[] = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"};
            Print("🎵 SHARROW REPORT SMART RHYTHM ANALYZER gestartet:");
            Print("📅 Heute: ", day_names[days_since_monday], " (Tag ", days_since_monday, " seit Montag)");
            
            // Report Rhythm Info
            if(ReportInterval != INTERVAL_OFF) {
               int report_trigger_days[];
               int report_count = GetTriggerDaysForInterval(ReportInterval, report_trigger_days);
               string report_pattern = "";
               for(int i = 0; i < report_count; i++) {
                  if(i > 0) report_pattern += ", ";
                  report_pattern += day_names[report_trigger_days[i]];
               }
               int next_report_days = FindNextRhythmTrigger(ReportInterval, days_since_monday);
               Print("📊 Report Pattern: [", report_pattern, "] → Nächster in ", next_report_days, " Tagen");
            }
            
            // Export Rhythm Info  
            if(ExportInterval != INTERVAL_OFF) {
               int export_trigger_days[];
               int export_count = GetTriggerDaysForInterval(ExportInterval, export_trigger_days);
               string export_pattern = "";
               for(int i = 0; i < export_count; i++) {
                  if(i > 0) export_pattern += ", ";
                  export_pattern += day_names[export_trigger_days[i]];
               }
               int next_export_days = FindNextRhythmTrigger(ExportInterval, days_since_monday);
               Print("📤 Export Pattern: [", export_pattern, "] → Nächster in ", next_export_days, " Tagen");
            }
            
            rhythm_info_shown = true;
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize snapshot system                                       |
//+------------------------------------------------------------------+
void InitializeSnapshots()
{
    // Take initial snapshot
    current_snapshot = TakeAccountSnapshot();
    last_snapshot = current_snapshot;  // Both start the same
    snapshots_initialized = true;
    
    Print("📸 Initial snapshots created:");
    Print("💰 Starting Balance: ", DoubleToString(current_snapshot.balance, 2), " EUR");
    Print("📈 Starting Equity: ", DoubleToString(current_snapshot.equity, 2), " EUR");
    Print("⏰ Snapshot Time: ", TimeToString(current_snapshot.snapshot_time, TIME_DATE|TIME_MINUTES));
    
    if(EnableDebugMode)
    {
        Print("🔍 DEBUG MODE ENABLED - Additional snapshot details:");
        Print("📊 Margin Used: ", DoubleToString(current_snapshot.margin_used, 2), " EUR");
        Print("💳 Margin Free: ", DoubleToString(current_snapshot.margin_free, 2), " EUR");
        Print("⚡ Floating P&L: ", DoubleToString(current_snapshot.floating_profit, 2), " EUR");
    }
}

//+------------------------------------------------------------------+
//| Take account snapshot using Account APIs                        |
//+------------------------------------------------------------------+
AccountSnapshot TakeAccountSnapshot()
{
    AccountSnapshot snapshot;
    
    snapshot.snapshot_time = TimeCurrent();
    snapshot.balance = AccountInfoDouble(ACCOUNT_BALANCE);
    snapshot.equity = AccountInfoDouble(ACCOUNT_EQUITY);
    snapshot.floating_profit = AccountInfoDouble(ACCOUNT_PROFIT);
    snapshot.margin_used = AccountInfoDouble(ACCOUNT_MARGIN);
    snapshot.margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    snapshot.is_valid = true;
    
    return snapshot;
}

//+------------------------------------------------------------------+
//| Send snapshot-based report                                      |
//+------------------------------------------------------------------+
void SendSnapshotReport()
{
    if(!snapshots_initialized)
    {
        Print("❌ Snapshots not initialized! Cannot send report.");
        return;
    }
    
    // Take new snapshot
    current_snapshot = TakeAccountSnapshot();
    
    if(EnableDebugMode)
    {
        Print("🔍 DEBUG: New snapshot taken for report:");
        Print("📊 Current Balance: ", DoubleToString(current_snapshot.balance, 2), " EUR");
        Print("📈 Current Equity: ", DoubleToString(current_snapshot.equity, 2), " EUR");
        Print("📊 Last Balance: ", DoubleToString(last_snapshot.balance, 2), " EUR");
        Print("📈 Last Equity: ", DoubleToString(last_snapshot.equity, 2), " EUR");
    }
    
    // Calculate period performance
    double balance_change = current_snapshot.balance - last_snapshot.balance;
    double equity_change = current_snapshot.equity - last_snapshot.equity;
    
    // Determine period name based on ReportInterval
    string period_name;
    if(ReportInterval == INTERVAL_DAILY)
        period_name = "Tagesbericht";
    else
        period_name = GetIntervalText(ReportInterval) + " Report";
    
    // Format and send message
    string message = FormatSnapshotMessage(balance_change, equity_change, period_name);
    bool sent = SendTelegramMessage(message);
    
    if(sent)
    {
        Print("📤 ", period_name, " sent successfully!");
        Print("💰 Balance Change: ", DoubleToString(balance_change, 2), " EUR");
        Print("📈 Equity Change: ", DoubleToString(equity_change, 2), " EUR");
        
        // Update last snapshot for next period
        last_snapshot = current_snapshot;
        Print("📸 Snapshot updated for next report period!");
    }
    else
    {
        Print("❌ Failed to send ", period_name, "!");
    }
}

//+------------------------------------------------------------------+
//| Format snapshot-based message                                   |
//+------------------------------------------------------------------+
string FormatSnapshotMessage(double balance_change, double equity_change, string period_name)
{
    string message = "";
    
    // Header with date range
    string start_date = TimeToString(last_snapshot.snapshot_time, TIME_DATE);
    string end_date = TimeToString(current_snapshot.snapshot_time, TIME_DATE);
    
    message += "🏆 GoldReport " + period_name + " (" + start_date + " - " + end_date + ")\n";
    message += "💰 Balance-Änderung: " + DoubleToString(balance_change, 2) + "€\n";
    message += "📈 Equity-Entwicklung: " + DoubleToString(equity_change, 2) + "€\n";
    message += "📊 Aktuelle Balance: " + DoubleToString(current_snapshot.balance, 2) + "€\n";
    message += "⚡ Floating P&L: " + DoubleToString(current_snapshot.floating_profit, 2) + "€\n\n";
    
    // Add performance assessment based on balance change
    string period_word = (period_name == "Tagesbericht") ? "Tag" : "Woche";
    
    if(balance_change > 500)
    {
        message += "Dieser " + period_word + " war LEGENDÄR! 🚀💰\nAbsoluter WAHNSINN! 🔥✨";
    }
    else if(balance_change > 100)
    {
        message += "Dieser " + period_word + " war der HAMMER! 🚀💰\nKeep it up, Champ! 😎";
    }
    else if(balance_change > 50)
    {
        message += "Solider " + period_word + "! 📈✨\nSteady progress, nice! 💪";
    }
    else if(balance_change > 0)
    {
        message += "Grüner " + period_word + "! 🌱📊\nJeder Euro zählt! 👍";
    }
    else if(balance_change > -50)
    {
        message += "Leichte Delle 📉\nKopf hoch, das wird schon! 💪🔥";
    }
    else if(balance_change > -100)
    {
        message += "Harter " + period_word + " 😵‍💫\nNächster wird besser! 🚀";
    }
    else
    {
        message += "Dieser " + period_word + " war mies 📉💸\nAber Sharrow gibt nicht auf! 🦾⚡";
    }
    
    return message;
}

//+------------------------------------------------------------------+
//| Helper Functions - Sharrow Style                              |
//+------------------------------------------------------------------+

// Get Interval Text for Display
string GetIntervalText(ENUM_INTERVAL interval)
{
    switch(interval)
    {
        case INTERVAL_OFF: return "AUS";
        case INTERVAL_DAILY: return "TÄGLICH";
        case INTERVAL_2_DAYS: return "ALLE 2 TAGE";
        case INTERVAL_3_DAYS: return "ALLE 3 TAGE";
        case INTERVAL_4_DAYS: return "ALLE 4 TAGE";
        case INTERVAL_7_DAYS: return "WÖCHENTLICH";
        default: return "UNBEKANNT";
    }
}

//+------------------------------------------------------------------+
//| Send message via Telegram                                       |
//+------------------------------------------------------------------+
bool SendTelegramMessage(string message)
{
    if(StringLen(TelegramBotToken) == 0)
    {
        Print("❌ Telegram Bot Token not configured");
        return false;
    }
    
    string chat_ids[];
    int chat_count = 0;
    
    // Sammle alle konfigurierten Chat-IDs
    if(StringLen(TelegramChatID1) > 0) 
    {
        ArrayResize(chat_ids, chat_count + 1);
        chat_ids[chat_count] = TelegramChatID1;
        chat_count++;
    }
    if(StringLen(TelegramChatID2) > 0) 
    {
        ArrayResize(chat_ids, chat_count + 1);
        chat_ids[chat_count] = TelegramChatID2;
        chat_count++;
    }
    if(StringLen(TelegramChatID3) > 0) 
    {
        ArrayResize(chat_ids, chat_count + 1);
        chat_ids[chat_count] = TelegramChatID3;
        chat_count++;
    }
    
    if(chat_count == 0)
    {
        Print("❌ No Telegram Chat IDs configured");
        return false;
    }
    
    string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendMessage";
    int success_count = 0;
    
    // Sende an alle konfigurierten Chats
    for(int i = 0; i < chat_count; i++)
    {
        string post_data = "chat_id=" + chat_ids[i] + "&text=" + message + "&parse_mode=HTML";
        
        char data[];
        char result[];
        string headers;
        
        ArrayResize(data, StringToCharArray(post_data, data, 0, WHOLE_ARRAY, CP_UTF8) - 1);
        
        int timeout = 5000; // 5 seconds
        int res = WebRequest("POST", url, NULL, timeout, data, result, headers);
        
        if(res == 200)
        {
            success_count++;
            Print("✅ Telegram message sent to chat " + IntegerToString(i+1) + "/" + IntegerToString(chat_count) + " (ID: " + chat_ids[i] + ")");
        }
        else
        {
            Print("❌ Telegram send failed to chat " + IntegerToString(i+1) + "/" + IntegerToString(chat_count) + " (ID: " + chat_ids[i] + "). Response code: " + IntegerToString(res));
            if(ArraySize(result) > 0)
            {
                string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
                Print("Response: ", response);
            }
        }
    }
    
    if(success_count > 0)
    {
        Print("📢 Telegram Multi-Chat: " + IntegerToString(success_count) + "/" + IntegerToString(chat_count) + " chats reached successfully");
        return true;
    }
    else
    {
        Print("❌ Telegram Multi-Chat: Failed to reach any of " + IntegerToString(chat_count) + " chats");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function (not used, but required)                   |
//+------------------------------------------------------------------+
void OnTick()
{
    // This EA only works on timer events for snapshots
    // No tick processing needed for report generation
}
