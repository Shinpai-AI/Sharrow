// Sharrow.mq5 - AI-Powered Trading System (H1 Trading + Multi-TF Export + Smart News Integration)
// Copyright: Sharrow Project
// Link: https://github.com/Shinpai-AI/Sharrow
// Version: 1.0 BETA (AI-Optimized Strategy + News Filtering)

#property copyright "Sharrow Project"
#property link      "https://github.com/Shinpai-AI/Sharrow"
#property version   "1.00"

// Abhängigkeiten
#include <Trade\Trade.mqh>
#include <Files\File.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Math\Stat\Weibull.mqh>
#include <Math\Stat\Poisson.mqh>
#include <Math\Stat\Exponential.mqh>

// Enums für TP/SL-Dropdowns
enum ENUM_TP_MULTIPLIER {
   TP_0_2 = 0,  // 0.2xATR
   TP_0_3 = 1,  // 0.3xATR
   TP_0_4 = 2,  // 0.4xATR
   TP_0_5 = 3,  // 0.5xATR
   TP_0_6 = 4,  // 0.6xATR
   TP_0_7 = 5,  // 0.7xATR
   TP_0_8 = 6,  // 0.8xATR
   TP_1_0 = 7,  // 1.0xATR
   TP_1_2 = 8,  // 1.2xATR
   TP_1_5 = 9,  // 1.5xATR
   TP_2_0 = 10, // 2.0xATR
   TP_2_5 = 11, // 2.5xATR
   TP_3_0 = 12  // 3.0xATR
};

enum ENUM_SL_VARIANT {
   SL_1_5ATR = 0,       // 1.5xATR
   SL_2_0ATR = 1,       // 2.0xATR
   SL_2_5ATR = 2,       // 2.5xATR
   SL_3_0ATR = 3,       // 3.0xATR
   SL_3_5ATR = 4,       // 3.5xATR
   SL_EXTREM14_0_2 = 5, // extrem14+0.2xATR
   SL_EXTREM14_0_3 = 6, // extrem14+0.3xATR
   SL_EXTREM14_0_5 = 7, // extrem14+0.5xATR
   SL_EXTREM14_0_7 = 8, // extrem14+0.7xATR
   SL_EXTREM14_1_0 = 9, // extrem14+1.0xATR
   SL_EXTREM14_1_5 = 10,// extrem14+1.5xATR
   SL_EXTREM14_2_0 = 11 // extrem14+2.0xATR
};

enum ENUM_INTERVAL {
   INTERVAL_OFF = 0,     // Aus
   INTERVAL_DAILY = 1,   // Täglich
   INTERVAL_2_DAYS = 2,  // Alle 2 Tage (Mo, Mi, Fr, So)
   INTERVAL_3_DAYS = 3,  // Alle 3 Tage (Mo, Do, So)
   INTERVAL_4_DAYS = 4,  // Alle 4 Tage (Mo, Fr)
   INTERVAL_7_DAYS = 7   // Alle 7 Tage (Mo)
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

enum ENUM_HOUR {
   HOUR_0 = 0, HOUR_1 = 1, HOUR_2 = 2, HOUR_3 = 3, HOUR_4 = 4, HOUR_5 = 5, HOUR_6 = 6,
   HOUR_7 = 7, HOUR_8 = 8, HOUR_9 = 9, HOUR_10 = 10, HOUR_11 = 11, HOUR_12 = 12,
   HOUR_13 = 13, HOUR_14 = 14, HOUR_15 = 15, HOUR_16 = 16, HOUR_17 = 17, HOUR_18 = 18,
   HOUR_19 = 19, HOUR_20 = 20, HOUR_21 = 21, HOUR_22 = 22, HOUR_23 = 23
};

enum ENUM_SIGNAL_SOURCE {
   SIGNAL_ALL = 0,           // Alle Signale (Rules + Logic + News) - 80-90% WinRate
   SIGNAL_RULES_NEWS = 1,    // Nur Rules + News (Logic ignorieren) - ML Power 90% WinRate
   SIGNAL_LOGIC_NEWS = 2,    // Nur Logic + News (Rules ignorieren) - Lotto Mode 50% WinRate
   SIGNAL_LOGIC_ONLY = 3     // DEAKTIVIERT - Logic alleine ist sinnlos
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

// ENUM_NEWS_INHALTE entfernt - automatische Symbol-basierte Info.txt Erkennung

enum ENUM_NEWS_CHECK_INTERVAL {
   NEWS_INTERVAL_15 = 15, NEWS_INTERVAL_30 = 30, INTERVAL_45 = 45, INTERVAL_60 = 60,
   NEWS_INTERVAL_75 = 75, NEWS_INTERVAL_90 = 90, NEWS_INTERVAL_105 = 105, NEWS_INTERVAL_120 = 120
};

// ===== GOLDJUNGE INPUT-PARAMETER (v3.0) =====

// === GRUNDEINSTELLUNGEN ===
input string HistoryStartDate = "2023.01.01";         // Startdatum für Historie
input int MaxBarsToExport = 40000;                    // Max. Bars für Export
input double RiskPercent = 10.0;                      // Lot-Wert in % vom Konto (OHNE SL-Berechnung!)
input double FixedLot = 0.0;                          // Feste Lot-Größe (0 = automatisch)
input double Leverage = 30.0;                         // Hebel
input double MinSLPips = 10.0;                        // Minimale SL-Distanz in Pips
input bool EnableTrading = false;                     // Trading aktivieren/deaktivieren
input bool NewsClosingEnabled = true;                 // News-Flip Trade-Closing aktivieren
input bool RulesIntegration = false;                  // Rules Integration für Trade-Entscheidung (default: false = nur Logic+News)
input ENUM_SIGNAL_SOURCE SignalSource = SIGNAL_ALL;   // Signal-Quelle: Welche Signale verwenden?
input bool EnableDebug = false;                        // Debug-Logs aktivieren

// === TEST-MODI (nur temporär verwenden) ===
input bool TestModeNewsObjectionOnly = false;          // true = News blocken nur bei direktem Widerspruch (Test), false = News müssen aktiv bestätigen

// === TRADE MANAGEMENT ERWEITERUNGEN ===
input int CooldownMinutesAfterLoss = 5;               // Cooldown nach SL (Minuten, 0 = aus)
input bool CooldownWaitForNewH1Bar = true;            // Nach SL neue H1-Kerze abwarten
input bool EnableBreakEven = true;                    // Break-Even Absicherung aktivieren
input double BreakEvenTriggerATR = 0.5;               // SL nachziehen ab Gewinn >= X * ATR
input double BreakEvenOffsetPips = 1.0;               // Sicherheitsabstand über/unter Entry (in Pips)
input double BreakEvenProfitThreshold = 0.0;          // Zusätzlicher Break-Even Trigger in Kontowährung (0 = deaktiviert)
input bool TpSwingMode = false;                       // TP-Swing deaktiviert (false) oder aktiviert (true)
input bool NightStopEnabled = false;                  // Night-Break: Keine Trades zwischen 22-06 Uhr Serverzeit

// === WEEKEND GAP PROTECTION ===
input bool GapProtection = true;                      // Schutz vor Weekend-Gaps aktivieren
input int StopHoursBeforeClose = 5;                   // Stunden vor Marktschluss stoppen  
input int MinGapHours = 12;                           // Min. Stunden Pause für Gap-Schutz

// === BREAKREVERT WAHRSCHEINLICHKEITS-PARAMETER ===
input double Breakout_Threshold = 0.4;                // Min. Wahrscheinlichkeit für Breakout (0-1)
input double Mean_Reversion_Threshold = 0.4;          // Schwellwert für Mean-Reversion (0-1)
input int Lookback_Period = 1;                        // Anzahl Kerzen für Wahrscheinlichkeit

// === QUALITY FILTER EINSTELLUNGEN ===
input double Quality_Stoch_Buy_Max = 30.0;            // Buy nur wenn Stochastic unter diesem Wert
input double Quality_Stoch_Sell_Min = 70.0;           // Sell nur wenn Stochastic über diesem Wert
input double Quality_Volume_Min = 1000.0;             // Minimales Volume für Signale

// === TP/SL EINSTELLUNGEN ===
input ENUM_TP_MULTIPLIER FixedTP = TP_2_0;            // Take-Profit (Fallback)
input ENUM_SL_VARIANT FixedSL = SL_2_0ATR;            // Stop-Loss (Fallback)
input bool UseSpreadAdjustment = true;                // Live-Spread zu TP addieren (Broker-Realität)
input int OrderDeviationPoints = 20;                  // Maximaler Slippage-Puffer für Market Orders (in Punkten)

// === INDIKATOREN ===
input int Stochastic_K_Period = 14;                   // Stochastic K-Periode
input int Stochastic_D_Period = 3;                    // Stochastic D-Periode
input int Stochastic_Slowing = 3;                     // Stochastic Slowing
input int ATR_Period = 14;                            // ATR-Periode
input int ADX_Period = 14;                            // ADX-Periode (für Trend-Stärke)
input double ADX_Min = 25.0;                          // ADX Minimum für Signale
input double ADX_Strong_Min = 40.0;                   // ADX Minimum für starken Trend

// === EXPORT/IMPORT TIMING (NUR EXPORT) ===
input ENUM_INTERVAL ExportInterval = INTERVAL_2_DAYS; // Export-Intervall
input ENUM_INTERVAL ImportInterval = INTERVAL_2_DAYS; // Import-Intervall
input ENUM_MONTH_DAY ExportMonthDay = MONTH_DAY_OFF;  // Monatlicher Export-Tag
input ENUM_MONTH_DAY ImportMonthDay = MONTH_DAY_OFF;  // Monatlicher Import-Tag
input ENUM_HOUR ExportHour = HOUR_0;                  // Export-Stunde
input ENUM_MINUTE ExportMinute = MINUTE_0;            // Export-Minute
input ENUM_HOUR ImportHour = HOUR_2;                  // Import-Stunde
input ENUM_MINUTE ImportMinute = MINUTE_0;            // Import-Minute

// === NEWS EINSTELLUNGEN ===
// News-Typ automatisch basierend auf Symbol - kein Input mehr nötig
input ENUM_NEWS_CHECK_INTERVAL NewsCheckInterval = NEWS_INTERVAL_30; // News-Check-Intervall

// 🚀 NEUE STRUKTUR: Symbol-spezifische optimierte Parameter
struct OptimizedParameters {
   double adx_min;           // Optimierte ADX-Schwelle
   double stoch_buy_max;     // Optimierte Stochastic BUY-Schwelle  
   double stoch_sell_min;    // Optimierte Stochastic SELL-Schwelle
   double volume_min;        // Optimierte Volume-Schwelle
   bool parameters_loaded;   // Flag ob Parameter aus Rules geladen wurden
};

// Globale Variablen
CTrade trade;
int stochastic_handle, atr_handle, adx_handle;
string account_currency;
datetime last_export = 0, last_rules_import = 0;
datetime last_export_date = 0, last_import_date = 0;
const double MIN_STOP_BUFFER_PIPS = 5.0;             // Mindestens so viele Pips Abstand zu SL/TP (zusätzlich zum Broker-Minimum)

// 🚀 NEUE GLOBALE VARIABLE: Optimierte Parameter für aktuelles Symbol  
OptimizedParameters g_optimized_params;

// === TRADE-HISTORY TRACKING FÜR COOLDOWN ===
ulong    last_processed_deal_ticket = 0;
datetime last_deal_time = 0;
double   last_deal_profit = 0.0;
int      last_deal_reason = -1;
datetime last_loss_time = 0;
datetime history_sync_from = 0;

// === STATE LOGGING ===
string STATE_LOG_FILE = "Goldjunge-state.log";

void StateLog(const string event, const string details)
{
   int handle = FileOpen(STATE_LOG_FILE, FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_TXT);
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle, 0, SEEK_END);

   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string line = "[" + timestamp + "] [" + _Symbol + "] [" + event + "] " + details;
   FileWrite(handle, line);
   FileFlush(handle);
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| Smart Rhythm Analyzer - Universal für alle Intervalle          |
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
bool news_proved = false;
datetime news_timer_start = 0;
int last_news_signal = 0;
long news_check_interval_seconds;
string last_news_status = "", last_rules_status = "";

// === TP SWING STATE ===
double swing_target_price = 0.0;
double swing_step_size = 0.0;
int swing_direction_type = -1;  // POSITION_TYPE_BUY / POSITION_TYPE_SELL
bool swing_active = false;

string BuildSwingKey(const string suffix)
{
   return "GJ_SWING_" + _Symbol + "_" + suffix;
}

bool IsNightStopActive()
{
   if(!NightStopEnabled)
      return false;

   datetime now = TimeTradeServer();
   MqlDateTime tm;
   TimeToStruct(now, tm);

   int current_minutes = tm.hour * 60 + tm.min;
   int start_minutes = 22 * 60; // 22:00
   int end_minutes = 6 * 60;    // 06:00

   if(start_minutes <= end_minutes)
      return (current_minutes >= start_minutes && current_minutes < end_minutes);

   // Fenster über Mitternacht
   return (current_minutes >= start_minutes || current_minutes < end_minutes);
}

void PersistSwingState()
{
   if(!TpSwingMode || !swing_active)
   {
      GlobalVariableDel(BuildSwingKey("STEP"));
      GlobalVariableDel(BuildSwingKey("TARGET"));
      GlobalVariableDel(BuildSwingKey("TYPE"));
      return;
   }

   GlobalVariableSet(BuildSwingKey("STEP"), swing_step_size);
   GlobalVariableSet(BuildSwingKey("TARGET"), swing_target_price);
   GlobalVariableSet(BuildSwingKey("TYPE"), (double)swing_direction_type);
}

void ResetSwingState(const bool clear_globals = true)
{
   swing_target_price = 0.0;
   swing_step_size = 0.0;
   swing_direction_type = -1;
   swing_active = false;

   if(clear_globals)
      PersistSwingState();
}

void LoadSwingState()
{
   ResetSwingState(false);

   if(!TpSwingMode)
      return;

   if(GlobalVariableCheck(BuildSwingKey("STEP")) && GlobalVariableCheck(BuildSwingKey("TARGET")) && GlobalVariableCheck(BuildSwingKey("TYPE")))
   {
      swing_step_size = GlobalVariableGet(BuildSwingKey("STEP"));
      swing_target_price = GlobalVariableGet(BuildSwingKey("TARGET"));
      swing_direction_type = (int)MathRound(GlobalVariableGet(BuildSwingKey("TYPE")));
      swing_active = (swing_step_size > 0.0 && (swing_direction_type == POSITION_TYPE_BUY || swing_direction_type == POSITION_TYPE_SELL));
   }
}

void InitializeSwingState(int position_type, double entry_price, double initial_target)
{
   ResetSwingState(false);

   if(!TpSwingMode)
      return;

   double step = MathAbs(initial_target - entry_price);
   if(step <= _Point)
   {
      StateLog("TP_SWING_SKIP", StringFormat("step<=Point entry=%.5f target=%.5f", entry_price, initial_target));
      PersistSwingState();
      return;
   }

   swing_step_size = step;
   swing_target_price = NormalizeDouble(initial_target, _Digits);
   swing_direction_type = position_type;
   swing_active = true;

   StateLog("TP_SWING_INIT", StringFormat("type=%s entry=%.5f target=%.5f step=%.5f",
           position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
           entry_price,
           swing_target_price,
           swing_step_size));
   PersistSwingState();
}

void HandleTpSwing()
{
   if(!TpSwingMode)
   {
      if(swing_active)
         ResetSwingState();
      return;
   }

   if(!PositionSelect(_Symbol))
   {
      if(swing_active)
         ResetSwingState();
      return;
   }

   if(!swing_active || swing_step_size <= 0.0)
      return;

   int position_type = (int)PositionGetInteger(POSITION_TYPE);
   if(position_type != swing_direction_type)
   {
      ResetSwingState();
      return;
   }

   // Aktuellen Preis für Vergleich nutzen
   double current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(current_price <= 0)
      return;

   double tolerance = _Point / 2.0;
   int safety_counter = 0;

   while(safety_counter < 5)
   {
      bool target_reached = (position_type == POSITION_TYPE_BUY)
                            ? (current_price + tolerance >= swing_target_price)
                            : (current_price - tolerance <= swing_target_price);

      if(!target_reached)
         break;

      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double prev_target = swing_target_price;
      double requested_sl = NormalizeDouble(prev_target, _Digits);
      bool already_guarded = (position_type == POSITION_TYPE_BUY && current_sl >= requested_sl - tolerance) ||
                             (position_type == POSITION_TYPE_SELL && current_sl <= requested_sl + tolerance && current_sl > 0);

      if(!already_guarded)
      {
         bool modified = trade.PositionModify(_Symbol, requested_sl, current_tp);
         if(!modified)
         {
            int err = GetLastError();
            if(err == 130 || err == 4108)
            {
               ResetLastError();
               double stop_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
               double min_gap = MathMax(stop_level, _Point);
               if(position_type == POSITION_TYPE_BUY)
                  requested_sl = NormalizeDouble(MathMin(requested_sl, current_price - min_gap), _Digits);
               else
                  requested_sl = NormalizeDouble(MathMax(requested_sl, current_price + min_gap), _Digits);

               modified = trade.PositionModify(_Symbol, requested_sl, current_tp);
               if(!modified)
               {
                  err = GetLastError();
                  StateLog("TP_SWING_FAIL", StringFormat("type=%s target=%.5f step=%.5f error=%d",
                                                       position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                                       requested_sl,
                                                       swing_step_size,
                                                       err));
                  Print("TP-SWING FEHLGESCHLAGEN: ", _Symbol, " ", (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                        " SL", DoubleToString(requested_sl, _Digits), " -> Error ", err);
                  ResetLastError();
                  return;
               }
            }
            else
            {
               StateLog("TP_SWING_FAIL", StringFormat("type=%s target=%.5f step=%.5f error=%d",
                                                    position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                                    requested_sl,
                                                    swing_step_size,
                                                    err));
               Print("TP-SWING FEHLGESCHLAGEN: ", _Symbol, " ", (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     " SL", DoubleToString(requested_sl, _Digits), " -> Error ", err);
               ResetLastError();
               return;
            }
         }

         double next_target_preview = (position_type == POSITION_TYPE_BUY)
                                      ? prev_target + swing_step_size
                                      : prev_target - swing_step_size;

         StateLog("TP_SWING_STEP", StringFormat("type=%s sl=%.5f locked=%.5f step=%.5f next=%.5f",
                                                position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                                requested_sl,
                                                prev_target,
                                                swing_step_size,
                                                next_target_preview));
         Print("TP-SWING: SL auf ", DoubleToString(requested_sl, _Digits), " gezogen (", _Symbol, ")");
      }
      else
      {
         StateLog("TP_SWING_LOCKED", StringFormat("type=%s sl=%.5f locked=%.5f step=%.5f",
                                                  position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                                  current_sl,
                                                  prev_target,
                                                  swing_step_size));
      }

      double next_target = (position_type == POSITION_TYPE_BUY)
                           ? prev_target + swing_step_size
                           : prev_target - swing_step_size;

      swing_target_price = NormalizeDouble(next_target, _Digits);

      PersistSwingState();

      current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(current_price <= 0)
         break;

      safety_counter++;
   }
}

// Erweiterte Sentiment-Keyword-Listen (müssen zu den News-Bot Triggern passen)
string g_positive_news_keywords[] = {
   "bullish", "positive", "strong", "strength", "growth", "recovery", "optimistic",
   "upbeat", "support", "supportive", "bid", "rally", "surge", "breakout",
   "break higher", "climb", "climbs", "climbing", "rise", "rises", "rising",
   "advance", "advances", "advancing", "soar", "soars", "soaring", "appreciates",
   "appreciation", "firmer", "firm", "upside", "gains", "gaining", "rebounds",
   "rebound", "bounces", "bounce", "lifts", "lift", "pushes higher", "rate cut"
};

string g_negative_news_keywords[] = {
   "bearish", "negative", "weak", "weakness", "decline", "declines", "fall",
   "falls", "falling", "drop", "drops", "dropping", "slip", "slips", "slipping",
   "retreat", "retreats", "retreating", "selloff", "sell-off", "selling", "loss",
   "losses", "lower", "under pressure", "pressure", "downside", "profit-taking",
   "pullback", "pull-back", "panic", "crash", "dump", "collapse", "plunge",
   "plunges", "deteriorates", "risk-off", "rate hike", "sanctions", "recession"
};

int CountKeywordHits(const string line, string &keywords[]) {
   int hits = 0;
   for(int i = 0; i < ArraySize(keywords); i++) {
      if(StringFind(line, keywords[i] + ": true") >= 0)
         hits++;
   }
   return hits;
}

double global_tp_atr = 0.0;
string global_sl_type = "";
double global_sl_dist = 0.0;
double global_win_rate = 0.0;
bool global_trade_active = true;  // TradeActive Flag aus Rules - Standard: aktiv
bool account_too_small = false;    // Trigger: Konto zu klein für Symbol
double global_lot_size = 0.0;     // LotSize aus Rules - 0.0 = verwende EA Einstellungen

// === NEWS-SENTIMENT SYSTEM - Einfaches News-Closing ===
int trade_entry_sentiment = 0;    // News-Sentiment beim Trade-Start: 1=BULLISH, -1=BEARISH, 0=NEUTRAL
datetime trade_entry_time = 0;    // Zeitpunkt der Trade-Eröffnung
bool news_closing_enabled = true; // News-Closing aktivieren/deaktivieren

// === GOLDJUNGE DECISION TREE ENGINE ===
// RuleNode für 4-Stage Pipeline (stochastic, adx, atr, weibull_prob, poisson_prob, volume)
struct GoldRuleNode {
   string feature;        // "stochastic", "adx", "atr", "weibull_prob", "poisson_prob", "volume"
   double threshold;      // Vergleichswert (normalisiert für ML-Features)
   bool is_less_equal;    // true für <=, false für >
   int signal;            // 0=Hold, 1=Buy, 2=Sell (wie in Goldjunge Train-KI-Bot.py)
   bool is_leaf;          // true für Endknoten mit Signal
   int parent_index;      // Index des Elternknotens
   int left_child;        // Index des linken Kindes  
   int right_child;       // Index des rechten Kindes
};
GoldRuleNode decision_tree[];
int tree_node_count = 0;
int rule_count = 0;
CArrayDouble m_close_prices_m1, m_close_prices_m15, m_close_prices_h1;
CArrayDouble m_weibull_values, m_poisson_values, m_exponential_values;

// Berechnet die Einrückungstiefe (Baum-Ebene) eines Decision-Tree-Strings
// und liefert gleichzeitig den Index, ab dem der eigentliche Knotentext beginnt.
int GetDecisionTreeIndent(const string line, int &content_start) {
   int level = 0;
   int idx = 0;
   int length = StringLen(line);

   while(idx < length) {
      if(idx + 4 <= length && StringSubstr(line, idx, 4) == "|   ") {
         level++;
         idx += 4;
         continue;
      }
      if(idx + 5 <= length && StringSubstr(line, idx, 5) == "|--- ") {
         idx += 5;
         break;
      }
      if(idx + 4 <= length && StringSubstr(line, idx, 4) == "|---") {
         idx += 4;
         break;
      }
      int ch = StringGetCharacter(line, idx);
      if(ch == ' ' || ch == '\t') {
         idx++;
         continue;
      }
      break;
   }

   while(idx < length && StringGetCharacter(line, idx) == ' ') idx++;
   content_start = idx;
   return level;
}

// H1 Trading Only
bool is_h1_timeframe = false;
string timeframe_warning = "";

// Quality Filter Statistiken (Counter für später, aber nicht in Bericht anzeigen)
int quality_signals_total = 0;
int quality_signals_passed = 0;
int quality_filter_1_fails = 0; // ADX
int quality_filter_2_fails = 0; // Stochastic
int quality_filter_3_fails = 0; // Volume
int quality_filter_4_fails = 0; // News-Konflikt
int quality_bonus_confirms = 0;  // News-Bestätigungen

// Globale Symbol-Parameter
double g_pip_size = 0.0;
double g_contract_size = 0.0;
double g_min_lot = 0.0;
double g_max_lot = 0.0;
double g_volume_step = 0.0;
double g_pip_value_account = 0.0;
double g_margin_per_lot = 0.0;
double g_max_margin = 0.0;
// 🧹 g_lot_size ENTFERNT - Ersetzt durch GetFinalLotSize() Master-Funktion!
string g_news_file = "";

// Lookup-Arrays
double GetTPMultiplier(int index) {
   double values[] = {0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0};
   if(index >= 0 && index < ArraySize(values)) return values[index];
   return 2.0;
}

string GetSLVariant(int index) {
   string values[] = {"1.5xATR", "2.0xATR", "2.5xATR", "3.0xATR", "3.5xATR", 
                      "extrem14+0.2xATR", "extrem14+0.3xATR", "extrem14+0.5xATR", 
                      "extrem14+0.7xATR", "extrem14+1.0xATR", "extrem14+1.5xATR", "extrem14+2.0xATR"};
   if(index >= 0 && index < ArraySize(values)) return values[index];
   return "2.0xATR";
}

// Debug-Log
void DebugLog(string message) {
   if(!EnableDebug) return;
   Print(message);
}

//+------------------------------------------------------------------+
//| Dynamische Stops Level Validation (Anti-Invalid-Stops-System)   |
//+------------------------------------------------------------------+
void ValidateStops(double &sl_price, double &tp_price, int signal) {
   // Broker Mindestabstände auslesen (dynamisch pro Symbol)
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip_size = g_pip_size > 0.0 ? g_pip_size : 0.0;
   if(pip_size <= 0.0) {
      pip_size = point;
      if(digits == 3 || digits == 5) pip_size = point * 10.0;
   }
   
   double current_price = (signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(current_price <= 0.0) {
      current_price = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   }
   
   // Mindestabstand in Preis umrechnen (Broker + Zusatzpuffer)
   double broker_min_distance = stops_level > 0 ? stops_level * point : 0.0;
   double buffer_min_distance = MIN_STOP_BUFFER_PIPS * pip_size;
   double min_distance = MathMax(MathMax(broker_min_distance, buffer_min_distance), point * 2.0);
   
   // Original Distanzen berechnen
   double original_sl_distance = MathAbs(current_price - sl_price);
   double original_tp_distance = MathAbs(current_price - tp_price);
   
   // SL Validation und Korrektur
   if(original_sl_distance < min_distance) {
      if(signal == 1) {
         sl_price = current_price - min_distance;
      } else {
         sl_price = current_price + min_distance;
      }
      if(EnableDebug) {
         DebugLog("ValidateStops: SL korrigiert von " + DoubleToString(original_sl_distance / pip_size, 2) +
                  " auf " + DoubleToString(min_distance / pip_size, 2) + " Pips (BrokerMin=" + IntegerToString(stops_level) + ")");
      }
   }
   
   // TP Validation und Korrektur
   if(original_tp_distance < min_distance) {
      if(signal == 1) { // BUY
         tp_price = current_price + min_distance;
      } else { // SELL
         tp_price = current_price - min_distance;
      }
      if(EnableDebug) {
         DebugLog("ValidateStops: TP korrigiert von " + DoubleToString(original_tp_distance / pip_size, 2) +
                  " auf " + DoubleToString(min_distance / pip_size, 2) + " Pips (BrokerMin=" + IntegerToString(stops_level) + ")");
      }
   }
   
   // Final Normalization
   sl_price = NormalizeDouble(sl_price, _Digits);
   tp_price = NormalizeDouble(tp_price, _Digits);
   
   if(EnableDebug) {
      DebugLog("ValidateStops: Symbol=" + _Symbol + ", StopsLevel=" + IntegerToString(stops_level) +
               ", FreezeLevel=" + IntegerToString(freeze_level) +
               ", MinDistance=" + DoubleToString(min_distance / pip_size, 2) + " Pips");
   }
}

// Prüft, ob ein Tag im Monat gültig ist
bool IsValidDay(int month, int day, int year) {
   if(day < 1 || day > 31) return false;
   if(month == 2) {
      bool is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return day <= (is_leap ? 29 : 28);
   }
   if(month == 4 || month == 6 || month == 9 || month == 11) return day <= 30;
   return true;
}

// ===== EXPORT FIX FUNKTIONEN (RAY'S LÖSUNG!) =====

// Hilfsfunktion: Datum String zu datetime konvertieren
datetime StringToDatetime(string date_str) {
   // Format: "2023.01.01" -> datetime
   string parts[];
   if(StringSplit(date_str, '.', parts) != 3) {
      Print("FEHLER: Ungültiges Datumsformat: ", date_str, " (erwartet: YYYY.MM.DD)");
      return D'2023.01.01 00:00:00';  // Fallback
   }
   
   int year = (int)StringToInteger(parts[0]);
   int month = (int)StringToInteger(parts[1]);
   int day = (int)StringToInteger(parts[2]);
   
   if(year < 2020 || year > 2030) {
      Print("WARNUNG: Jahr außerhalb des gültigen Bereichs: ", year);
      year = 2023;
   }
   if(month < 1 || month > 12) {
      Print("WARNUNG: Monat außerhalb des gültigen Bereichs: ", month);
      month = 1;
   }
   if(day < 1 || day > 31) {
      Print("WARNUNG: Tag außerhalb des gültigen Bereichs: ", day);
      day = 1;
   }
   
   MqlDateTime dt;
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
datetime result = StructToTime(dt);
   Print("Datum konvertiert: ", date_str, " -> ", TimeToString(result, TIME_DATE));
   return result;
}

// Berechnet die optimale Anzahl Bars zum Kopieren
int CalculateBarsToExport(string symbol, ENUM_TIMEFRAMES tf, datetime start_date, int max_bars) {
   // 1. Verfügbare Bars im Symbol prüfen
   int available_bars = iBars(symbol, tf);
   if(available_bars <= 0) {
      Print("FEHLER: Keine Bars verfügbar für ", symbol, " ", EnumToString(tf));
      return 0;
   }
   
   Print("Verfügbare Bars für ", symbol, " ", EnumToString(tf), ": ", available_bars);
   
   // 2. Start-Datum zu Bar-Index konvertieren
   int start_bar_index = iBarShift(symbol, tf, start_date, false);
   if(start_bar_index < 0) {
      Print("WARNUNG: Start-Datum zu weit in der Zukunft oder ungültig, verwende maximale Bars");
      start_bar_index = available_bars - 1;  // Älteste verfügbare Bar
   }
   
   Print("Start-Datum ", TimeToString(start_date, TIME_DATE), " entspricht Bar-Index: ", start_bar_index);
   
   // 3. Anzahl Bars berechnen (von start_bar_index bis aktuell)
   int bars_from_date = start_bar_index + 1;  // +1 weil Index 0-basiert ist
   
   // 4. Minimum von (Bars seit Datum, Max Bars, Verfügbare Bars) nehmen
   int bars_to_export = MathMin(bars_from_date, max_bars);
   bars_to_export = MathMin(bars_to_export, available_bars);
   
   Print("Export-Berechnung:");
   Print("- Bars seit Start-Datum: ", bars_from_date);
   Print("- Max Bars Setting: ", max_bars);
   Print("- Verfügbare Bars: ", available_bars);
   Print("- Finale Export-Anzahl: ", bars_to_export);
   
   return bars_to_export;
}

// News-basierte Pip-Size Berechnung
double CalculateNewsPipSize() {
   int decimal_places = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pip_size = 0.0;
   
   // Automatische Pip-Size-Bestimmung basierend auf Symbol
   string asset_type = GetAssetType(_Symbol);
   if(asset_type == "CRYPTO") {
      pip_size = (StringFind(_Symbol, "XRP") >= 0) ? 0.0001 : 0.01; // XRP spezial
   } else if(asset_type == "METAL") {
      pip_size = 0.01; // METALS
   } else {
      // FOREX
      if(StringFind(_Symbol, "JPY") >= 0) {
         pip_size = decimal_places == 2 ? 0.01 : 0.001;
      } else {
         pip_size = decimal_places == 4 ? 0.0001 : 0.00001;
      }
   }
   
   if(pip_size == 0.0) pip_size = MathMax(0.0001, point);
   
   // Asset-Type automatisch bestimmen
   string news_type = GetAssetType(_Symbol);
   DebugLog("CalculateNewsPipSize: news_type=" + news_type + ", symbol=" + _Symbol + 
            ", decimal_places=" + IntegerToString(decimal_places) + 
            ", calculated_pip_size=" + DoubleToString(pip_size, 8));
   
   return pip_size;
}

// Alle Symbol-Parameter einmal berechnen
void InitializeSymbolParameters() {
   account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   g_contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   g_min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   g_pip_size = CalculateNewsPipSize();
   
   double pip_value_quote = g_pip_size * g_contract_size;
   g_pip_value_account = ConvertToAccountCurrency(pip_value_quote, _Symbol);
   
   g_margin_per_lot = CalculateUniversalMarginPerLot();
   g_max_margin = 0.8 * balance * Leverage;
   
   // Automatisches News-File basierend auf aktuellem Symbol
   g_news_file = _Symbol + "_Info.txt";
   
   DebugLog("InitializeSymbolParameters: pip_size=" + DoubleToString(g_pip_size, 8) + 
            ", pip_value_account=" + DoubleToString(g_pip_value_account, 2) + 
            ", contract_size=" + DoubleToString(g_contract_size, 2) + 
            ", margin_per_lot=" + DoubleToString(g_margin_per_lot, 2) + 
            ", news_file=" + g_news_file);
}

// ECHTE MT5-Margin-Berechnung wie in GoldReport.mq5
double CalculateUniversalMarginPerLot() {
   double margin_per_lot = 0.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // ROBUSTE MT5-MARGIN-BERECHNUNG mit Retry-Logic (wie GoldReport)
   const int MAX_RETRIES = 3;
   const int RETRY_DELAY_MS = 100;
   bool success = false;
   
   // Retry-Logic für OrderCalcMargin() - ECHTE Broker-Margin!
   for (int i = 0; i < MAX_RETRIES && !success; i++) {
      if (OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, bid, margin_per_lot)) {
         if (margin_per_lot > 0) {
            success = true;
            DebugLog("✅ " + _Symbol + ": ECHTE Margin berechnet: " + DoubleToString(margin_per_lot, 2) + " " + account_currency + " (Versuch " + IntegerToString(i+1) + ")");
         }
      }
      if (!success && i < MAX_RETRIES - 1) {  // Nicht beim letzten Versuch
         DebugLog("⚠️ " + _Symbol + ": OrderCalcMargin Versuch " + IntegerToString(i+1) + " fehlgeschlagen, retry in 100ms...");
         Sleep(RETRY_DELAY_MS);
      }
   }
   
   // Fallback nur bei totalem Versagen
   if (!success) {
      DebugLog("❌ " + _Symbol + ": OrderCalcMargin FAILED nach " + IntegerToString(MAX_RETRIES) + " Versuchen! Verwende Fallback-Berechnung");
      
      // Fallback: Basis-Berechnung
      double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
      double margin_initial = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
      
      if(margin_initial > 0) {
         margin_per_lot = margin_initial;  // MT5-Wert nutzen
      } else {
         double mid_price = (bid + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
         margin_per_lot = (contract_size * mid_price) / leverage;  // Standard-Fallback
      }
      
      // KEINE ConvertToAccountCurrency() - OrderCalcMargin() gibt bereits Account-Währung zurück!
   }
   
   // Finale Validierung - Nur extreme Fehler abfangen
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Nur bei offensichtlich fehlerhaften Berechnungen eingreifen
   if(margin_per_lot <= 0) {
      DebugLog("ERROR: Margin ist 0 oder negativ für " + _Symbol);
      margin_per_lot = 10.0;  // Sicherheits-Fallback
   }
   
   // Warnung bei extrem hohen Werten (aber nicht blockieren für große Konten)
   if(margin_per_lot > balance * 2.0) {
      DebugLog("WARNING: Margin sehr hoch (" + DoubleToString(margin_per_lot, 2) + 
               "), prüfen Sie die Berechnung für " + _Symbol);
   }
   
   // Debug-Ausgabe mit ECHTEN Werten
   ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   string calc_mode_text = "";
   switch(calc_mode) {
      case SYMBOL_CALC_MODE_FOREX: calc_mode_text = "FOREX"; break;
      case SYMBOL_CALC_MODE_CFD: calc_mode_text = "CFD"; break;
      case SYMBOL_CALC_MODE_FUTURES: calc_mode_text = "FUTURES"; break;
      case SYMBOL_CALC_MODE_CFDINDEX: calc_mode_text = "CFD_INDEX"; break;
      case SYMBOL_CALC_MODE_CFDLEVERAGE: calc_mode_text = "CFD_LEVERAGE"; break;
      case SYMBOL_CALC_MODE_EXCH_STOCKS: calc_mode_text = "STOCKS"; break;
      case SYMBOL_CALC_MODE_EXCH_FUTURES: calc_mode_text = "EXCHANGE_FUTURES"; break;
      case SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS: calc_mode_text = "FUTURES_FORTS"; break;
      default: calc_mode_text = "OTHER"; break;
   }
   
   DebugLog("CalculateUniversalMarginPerLot: " + _Symbol + 
            ", calc_mode=" + calc_mode_text + 
            ", ECHTE_margin_per_lot=" + DoubleToString(margin_per_lot, 2) + " " + account_currency +
            ", success=" + (success ? "YES" : "FALLBACK"));
   
   return margin_per_lot;
}

double GetFinalLotSize() {
   account_too_small = false;
   
   // Prioritäten: Rules → Fixed → Risk-basiert
   if(global_lot_size > 0) {
      return global_lot_size;
   }
   if(FixedLot > 0) {
      return FixedLot;
   }
   
   // Risk-basierte Berechnung
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * RiskPercent / 100.0;
   double calculated_lot = risk_amount / g_margin_per_lot;
   
   // Broker-Limits anwenden
   calculated_lot = MathMax(g_min_lot, MathMin(g_max_lot, NormalizeDouble(calculated_lot / g_volume_step, 4) * g_volume_step));
   
   // Account-too-small Check
   double min_lot_cost = g_min_lot * g_margin_per_lot;
   if(min_lot_cost > risk_amount * 1.5) {
      account_too_small = true;
   }
   
   return calculated_lot;
}

// Währung umrechnen
double ConvertToAccountCurrency(double value, string symbol) {
   string base_currency = StringSubstr(symbol, 0, 3);
   string quote_currency = StringSubstr(symbol, 3, 3);
   
   // KRITISCHER FIX: Wenn Account-Währung = Base-Währung, ist der Wert bereits korrekt!
   // Beispiel: EURCHF mit EUR-Account → value ist bereits in EUR
   if(account_currency == base_currency) {
      return value;  // KEIN Umrechnen nötig!
   }
   
   // Wenn Account-Währung = Quote-Währung, auch kein Umrechnen nötig
   if(account_currency == quote_currency) return value;
   
   // Nur bei Cross-Currency-Paaren umrechnen
   string pair = account_currency + quote_currency;
   double bid = SymbolInfoDouble(pair, SYMBOL_BID);
   if(bid > 0) return value / bid;
   pair = quote_currency + account_currency;
   bid = SymbolInfoDouble(pair, SYMBOL_BID);
   if(bid > 0) return value * bid;
   Print("Warnung: Kein Umrechnungspaar für ", symbol, " gefunden, Fallback-Wert verwendet");
   return value;
}

// Preise für M1, M15, H1 laden
bool UpdatePriceData() {
   bool success = true;
   int safe_lookback = MathMax(1, Lookback_Period);

   double prices_m1[];
   int copied_m1 = CopyClose(_Symbol, PERIOD_M1, 0, safe_lookback, prices_m1);
   if(copied_m1 <= 0) {
      ArrayResize(prices_m1, 1);
      prices_m1[0] = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      success = false;
   }
   m_close_prices_m1.AssignArray(prices_m1);

   double prices_m15[];
   int copied_m15 = CopyClose(_Symbol, PERIOD_M15, 0, safe_lookback, prices_m15);
   if(copied_m15 <= 0) {
      ArrayResize(prices_m15, 1);
      prices_m15[0] = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      success = false;
   }
   m_close_prices_m15.AssignArray(prices_m15);

   double prices_h1[];
   int copied_h1 = CopyClose(_Symbol, PERIOD_H1, 0, safe_lookback, prices_h1);
   if(copied_h1 <= 0) {
      ArrayResize(prices_h1, 1);
      prices_h1[0] = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      success = false;
   }
   m_close_prices_h1.AssignArray(prices_h1);

   return success && m_close_prices_m1.Total() > 0 && m_close_prices_m15.Total() > 0 && m_close_prices_h1.Total() > 0;
}

// Wahrscheinlichkeiten berechnen
void CalculateProbabilities() {
   if(m_close_prices_m1.Total() == 0) {
      m_weibull_values.Clear();
      m_poisson_values.Clear();
      m_exponential_values.Clear();
      m_weibull_values.Add(0.5);
      m_poisson_values.Add(0.5);
      m_exponential_values.Add(0.5);
      return;
   }

   double temp_array[];
   int size_m1 = m_close_prices_m1.Total();
   ArrayResize(temp_array, size_m1);
   for(int i = 0; i < size_m1; i++) {
      temp_array[i] = m_close_prices_m1.At(i);
      if(temp_array[i] <= 0) temp_array[i] = 1.0;
   }

   double weibull_result[];
   if(!MathProbabilityDensityWeibull(temp_array, 1.5, 5.0, weibull_result) || ArraySize(weibull_result) == 0) {
      ArrayResize(weibull_result, size_m1);
      ArrayInitialize(weibull_result, 0.5);
   }
   m_weibull_values.AssignArray(weibull_result);

   int event_counts_int[];
   ArrayResize(event_counts_int, size_m1);
   ArrayInitialize(event_counts_int, 1);
   if(size_m1 > 1) {
      for(int i = 1; i < size_m1; i++) {
         if(MathAbs(temp_array[i] - temp_array[i - 1]) > 5 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)) {
            event_counts_int[i] = event_counts_int[i - 1] + 1;
         } else {
            event_counts_int[i] = event_counts_int[i - 1];
         }
      }
   }
   double event_counts[];
   ArrayResize(event_counts, size_m1);
   for(int i = 0; i < size_m1; i++) {
      event_counts[i] = (double)event_counts_int[i];
   }
   double sum = 0.0;
   for(int i = 0; i < size_m1; i++) {
      sum += event_counts[i];
   }
   double lambda = sum / size_m1;
   if(lambda <= 0 || lambda > 1000000) lambda = 5.0;
   double poisson_result[];
   if(!MathCumulativeDistributionPoisson(event_counts, lambda, poisson_result)) {
      ArrayResize(poisson_result, size_m1);
      ArrayInitialize(poisson_result, 0.5);
   }
   m_poisson_values.AssignArray(poisson_result);

   sum = 0.0;
   for(int i = 0; i < size_m1; i++) {
      sum += temp_array[i];
   }
   double mu = sum / size_m1;
   if(mu <= 0) mu = 1.0;
   double exp_result[];
   if(!MathCumulativeDistributionExponential(temp_array, mu, exp_result) || ArraySize(exp_result) == 0) {
      ArrayResize(exp_result, size_m1);
      ArrayInitialize(exp_result, 0.5);
   }
   m_exponential_values.AssignArray(exp_result);
}

// ===== HAUPT-LOGIK-SIGNAL (BreakRevert-Basis) - SYMMETRISCH + ADX/STOCH/VOL INTEGRIERT =====
int GetLogicSignal() {
   if(!UpdatePriceData()) return 0;
   CalculateProbabilities();

   double weibull_prob = m_weibull_values.Total() > 0 ? m_weibull_values.At(m_weibull_values.Total() - 1) : 0.5;
   double poisson_prob = m_poisson_values.Total() > 0 ? m_poisson_values.At(m_poisson_values.Total() - 1) : 0.5;

   double m1_trend = m_close_prices_m1.Total() >= 2 ? m_close_prices_m1.At(0) - m_close_prices_m1.At(m_close_prices_m1.Total() - 1) : 0;
   double m15_trend = m_close_prices_m15.Total() >= 2 ? m_close_prices_m15.At(0) - m_close_prices_m15.At(m_close_prices_m15.Total() - 1) : 0;
   double h1_min = m_close_prices_h1.Total() > 0 ? m_close_prices_h1[0] : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 1; i < m_close_prices_h1.Total(); i++) {
      if(m_close_prices_h1[i] < h1_min) h1_min = m_close_prices_h1[i];
   }
   double h1_max = m_close_prices_h1.Total() > 0 ? m_close_prices_h1[0] : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 1; i < m_close_prices_h1.Total(); i++) {
      if(m_close_prices_h1[i] > h1_max) h1_max = m_close_prices_h1[i];
   }
   double h1_volatility = h1_max - h1_min;

   // ===== INDIKATOR-DATEN FÜR VERIFIKATION =====
   double adx[2], stochastic_k[2], stochastic_d[2];
   long volume[2];
   
   if(CopyBuffer(adx_handle, 0, 0, 2, adx) < 2 ||
      CopyBuffer(stochastic_handle, 0, 0, 2, stochastic_k) < 2 ||
      CopyBuffer(stochastic_handle, 1, 0, 2, stochastic_d) < 2 ||
      CopyTickVolume(_Symbol, Period(), 0, 2, volume) < 2) {
      DebugLog("Logic Signal: Indikatoren nicht verfügbar, Signal=0");
      return 0;
   }

   // ===== EINHEITLICHES BREAKREVERT-SYSTEM =====
   // H1 entscheidet BREAKOUT vs MEAN REVERSION, M1/M15 bestimmen BUY/SELL
   double h1_trend = m_close_prices_h1.Total() >= 2 ? m_close_prices_h1.At(m_close_prices_h1.Total() - 1) - m_close_prices_h1.At(0) : 0;
   
   // BREAKOUT-SIGNAL: H1 Volatilität hoch + Weibull/Poisson > Threshold
   bool breakout_signal = weibull_prob > Mean_Reversion_Threshold && 
                         poisson_prob > Breakout_Threshold &&
                         h1_volatility > 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // MEAN REVERSION-SIGNAL: H1 Trend schwach + Weibull < Threshold
   bool mean_reversion_signal = weibull_prob < Mean_Reversion_Threshold && 
                               MathAbs(h1_trend) < 20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // ORIGINAL BREAKREVERT-LOGIK (nach BreakRevertPro.mq5)
   int signal_candidate = 0;
   string signal_type = "";
   
   // Original Logic: Breakout → BUY, Mean Reversion → SELL
   if(breakout_signal) {
      signal_candidate = 1;  // BREAKOUT → BUY (Original)
      signal_type = "BREAKOUT BUY";
   } else if(mean_reversion_signal) {
      signal_candidate = -1; // MEAN REVERSION → SELL (Original)
      signal_type = "MEAN REVERSION SELL";
   }
   
   // 🚀 FINALE VERIFIKATION mit optimierten ADX/Stoch/Vol Parametern
   if(signal_candidate != 0) {
      double adx_threshold = g_optimized_params.parameters_loaded ? g_optimized_params.adx_min : ADX_Min;
      double stoch_buy_threshold = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_buy_max : Quality_Stoch_Buy_Max;
      double stoch_sell_threshold = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_sell_min : Quality_Stoch_Sell_Min;
      double volume_threshold = g_optimized_params.parameters_loaded ? g_optimized_params.volume_min : Quality_Volume_Min;
      
      bool adx_ok = adx[1] >= adx_threshold;
      bool stoch_ok = (signal_candidate == 1) ? stochastic_k[1] < stoch_buy_threshold : stochastic_k[1] > stoch_sell_threshold;
      bool volume_ok = volume[1] >= volume_threshold;
      
      if(adx_ok && stoch_ok && volume_ok) {
         DebugLog("Logic Signal: " + signal_type + " ✓ (Weibull=" + DoubleToString(weibull_prob, 3) + 
                  ", Poisson=" + DoubleToString(poisson_prob, 3) + 
                  ", ADX=" + DoubleToString(adx[1], 1) + 
                  ", Stoch=" + DoubleToString(stochastic_k[1], 1) + 
                  ", Vol=" + IntegerToString((int)volume[1]) + ")");
         return signal_candidate;
      }
   }

   // ===== KEIN SIGNAL =====
   string reason = "";
   if(!breakout_signal && !mean_reversion_signal) {
      reason = "BreakRevert Bedingungen nicht erfüllt";
   } else if(breakout_signal) {
      reason = "Breakout möglich aber Trend/Filter nicht erfüllt";
   } else if(mean_reversion_signal) {
      reason = "Mean Reversion möglich aber Trend/Filter nicht erfüllt";
   }
   
   DebugLog("Logic Signal: KEIN SIGNAL - " + reason + 
            " (Weibull=" + DoubleToString(weibull_prob, 3) + 
            ", Poisson=" + DoubleToString(poisson_prob, 3) + 
            ", ADX=" + DoubleToString(adx[1], 1) + 
            ", Stoch=" + DoubleToString(stochastic_k[1], 1) + 
            ", Vol=" + IntegerToString((int)volume[1]) + ")");
   
   return 0;
}

// ===== NEWS-KONFLIKT-FILTER wurde entfernt - wird jetzt im 3-Regel-System behandelt =====

//+------------------------------------------------------------------+
//| 🚀 NEUE FUNKTION: Lade optimierte Parameter aus Rules           |
//+------------------------------------------------------------------+
bool LoadOptimizedParameters() {
   // Initialisierung mit Fallback-Werten
   g_optimized_params.adx_min = ADX_Min;
   g_optimized_params.stoch_buy_max = Quality_Stoch_Buy_Max;
   g_optimized_params.stoch_sell_min = Quality_Stoch_Sell_Min;
   g_optimized_params.volume_min = Quality_Volume_Min;
   g_optimized_params.parameters_loaded = false;
   
   string file_name = "rules_" + _Symbol + ".txt";
   int file_handle = FileOpen(file_name, FILE_READ | FILE_TXT | FILE_ANSI);
   
   if(file_handle == INVALID_HANDLE) {
      Print("⚠️ [OPTIMIZATION] Rules file not found: ", file_name, " - Using input parameters as fallback");
      return false;
   }
   
   Print("🔍 [OPTIMIZATION] Loading optimized parameters from: ", file_name);
   
   bool found_optimized = false;
   
   while(!FileIsEnding(file_handle)) {
      string line = FileReadString(file_handle);
      StringTrimLeft(line);
      StringTrimRight(line);
      
      if(StringLen(line) == 0 || StringFind(line, "//") == 0) continue;
      
      // Parse optimierte Parameter
      if(StringFind(line, "ADX_Min:") == 0) {
         string value_str = StringSubstr(line, StringFind(line, ":") + 1);
         StringTrimLeft(value_str);
         StringTrimRight(value_str);
         g_optimized_params.adx_min = StringToDouble(value_str);
         found_optimized = true;
         Print("📊 [OPTIMIZATION] ADX_Min: ", g_optimized_params.adx_min);
      }
      else if(StringFind(line, "Stoch_Buy_Max:") == 0) {
         string value_str = StringSubstr(line, StringFind(line, ":") + 1);
         StringTrimLeft(value_str);
         StringTrimRight(value_str);
         g_optimized_params.stoch_buy_max = StringToDouble(value_str);
         found_optimized = true;
         Print("📊 [OPTIMIZATION] Stoch_Buy_Max: ", g_optimized_params.stoch_buy_max);
      }
      else if(StringFind(line, "Stoch_Sell_Min:") == 0) {
         string value_str = StringSubstr(line, StringFind(line, ":") + 1);
         StringTrimLeft(value_str);
         StringTrimRight(value_str);
         g_optimized_params.stoch_sell_min = StringToDouble(value_str);
         found_optimized = true;
         Print("📊 [OPTIMIZATION] Stoch_Sell_Min: ", g_optimized_params.stoch_sell_min);
      }
      else if(StringFind(line, "Volume_Min:") == 0) {
         string value_str = StringSubstr(line, StringFind(line, ":") + 1);
         StringTrimLeft(value_str);
         StringTrimRight(value_str);
         g_optimized_params.volume_min = StringToDouble(value_str);
         found_optimized = true;
         Print("📊 [OPTIMIZATION] Volume_Min: ", g_optimized_params.volume_min);
      }
   }
   
   FileClose(file_handle);
   
   if(found_optimized) {
      g_optimized_params.parameters_loaded = true;
      Print("✅ [OPTIMIZATION] Successfully loaded optimized parameters for ", _Symbol);
      Print("   ├── ADX_Min: ", g_optimized_params.adx_min, " (input: ", ADX_Min, ")");
      Print("   ├── Stoch_Buy_Max: ", g_optimized_params.stoch_buy_max, " (input: ", Quality_Stoch_Buy_Max, ")");
      Print("   ├── Stoch_Sell_Min: ", g_optimized_params.stoch_sell_min, " (input: ", Quality_Stoch_Sell_Min, ")");
      Print("   └── Volume_Min: ", g_optimized_params.volume_min, " (input: ", Quality_Volume_Min, ")");
   } else {
      Print("⚠️ [OPTIMIZATION] No optimized parameters found in rules file - using input values");
   }
   
   return found_optimized;
}

// Rules-System (immer aktiv)
void LoadRules(ENUM_TIMEFRAMES tf) {
   string tf_str = tf == PERIOD_M1 ? "M1" : tf == PERIOD_M5 ? "M5" : tf == PERIOD_M15 ? "M15" : tf == PERIOD_M30 ? "M30" : tf == PERIOD_H1 ? "H1" : "H4";
   string file_name = "rules_" + _Symbol + ".txt";  // OHNE TIMEFRAME!
   int file_handle = FileOpen(file_name, FILE_READ | FILE_TXT | FILE_ANSI);
   if(file_handle == INVALID_HANDLE) {
      last_rules_status = "Rules Datei nicht gefunden: " + file_name;
      rule_count = 0;
      global_tp_atr = 0.0;
      global_sl_type = "";
      global_sl_dist = 0.0;
      global_win_rate = 0.0;
      global_lot_size = 0.0;  // RESET! Sonst wird alter Rules-Lot verwendet!
      DebugLog("LoadRules: Datei nicht gefunden: " + file_name);
      return;
   }
   
   rule_count = 0;
   ArrayResize(decision_tree, 0);
   tree_node_count = 0;
   int depth_nodes[];
   ArrayResize(depth_nodes, 0);

   while(!FileIsEnding(file_handle)) {
      string line = FileReadString(file_handle);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(StringLen(line) == 0) continue;
      
      if(StringFind(line, "TP:") >= 0) {
         global_tp_atr = StringToDouble(StringSubstr(line, StringFind(line, ":") + 1));
         DebugLog("LoadRules: TP=" + DoubleToString(global_tp_atr, 2));
      }
      if(StringFind(line, "SL:") >= 0) {
         string sl_value = StringSubstr(line, StringFind(line, ":") + 2);
         StringToLower(sl_value);
         if(StringFind(sl_value, "extrem14") >= 0) {
            global_sl_type = "extrem14";
            string dist_str = StringSubstr(sl_value, StringFind(sl_value, "+") + 1);
            dist_str = StringSubstr(dist_str, 0, StringFind(dist_str, "atr"));
            global_sl_dist = StringToDouble(dist_str);
         } else {
            global_sl_type = "atr";
            global_sl_dist = StringToDouble(StringSubstr(sl_value, 0, StringLen(sl_value) - 3));
         }
         DebugLog("LoadRules: SL=" + global_sl_type + ", Dist=" + DoubleToString(global_sl_dist, 2));
      }
      if(StringFind(line, "WinRate:") >= 0) {
         global_win_rate = StringToDouble(StringSubstr(line, StringFind(line, ":") + 1));
         if(global_win_rate < 0.0 || global_win_rate > 100.0) global_win_rate = 0.0;
         DebugLog("LoadRules: WinRate=" + DoubleToString(global_win_rate, 1) + "%");
      }
      if(StringFind(line, "LotSize:") >= 0) {
         global_lot_size = StringToDouble(StringSubstr(line, StringFind(line, ":") + 1));
         if(global_lot_size < 0.01) global_lot_size = 0.0; // Reset bei ungültigen Werten
         DebugLog("LoadRules: LotSize=" + DoubleToString(global_lot_size, 4));
      }
      if(StringFind(line, "TradeActive:") >= 0) {
         string trade_active_str = StringSubstr(line, StringFind(line, ":") + 1);
         StringTrimLeft(trade_active_str);
         StringTrimRight(trade_active_str);
         StringToLower(trade_active_str);
         global_trade_active = (trade_active_str == "true");
         DebugLog("LoadRules: TradeActive=" + (global_trade_active ? "True" : "False"));
      }
      if(StringFind(line, "Symbol:") >= 0) {
         rule_count++;
      }
      
      // === GOLDJUNGE DECISION TREE PARSER ===
      // Parse Decision Tree Rules (AI-generated strategy)
      if(StringFind(line, "|---") >= 0) {
         int content_start = 0;
         int indent = GetDecisionTreeIndent(line, content_start);
         string content = StringSubstr(line, content_start);
         StringTrimLeft(content);
         StringTrimRight(content);
         if(StringLen(content) == 0) continue;

         GoldRuleNode node;
         node.signal = 0;
         node.left_child = -1;
         node.right_child = -1;
         node.parent_index = -1;
         node.is_leaf = false;
         node.feature = "";
         node.threshold = 0.0;
         node.is_less_equal = true;

         if(StringFind(content, "class:") >= 0) {
            node.is_leaf = true;
            if(StringFind(content, "class: 0") >= 0) node.signal = 0;
            else if(StringFind(content, "class: 1") >= 0) node.signal = 1;
            else if(StringFind(content, "class: 2") >= 0) node.signal = 2;
            DebugLog("ParseTree: Leaf Node - Signal=" + IntegerToString(node.signal));
         } else {
            int pos = StringFind(content, "<=");
            if(pos >= 0) {
               string feature = StringSubstr(content, 0, pos);
               StringTrimLeft(feature);
               StringTrimRight(feature);
               string threshold = StringSubstr(content, pos + 2);
               StringTrimLeft(threshold);
               StringTrimRight(threshold);
               node.feature = feature;
               node.threshold = StringToDouble(threshold);
               node.is_less_equal = true;
            } else {
               pos = StringFind(content, ">");
               if(pos >= 0) {
                  string feature = StringSubstr(content, 0, pos);
                  StringTrimLeft(feature);
                  StringTrimRight(feature);
                  string threshold = StringSubstr(content, pos + 1);
                  StringTrimLeft(threshold);
                  StringTrimRight(threshold);
                  node.feature = feature;
                  node.threshold = StringToDouble(threshold);
                  node.is_less_equal = false;
               } else {
                  DebugLog("ParseTree: Unbekannter Knoten ignoriert -> " + content);
                  continue;
               }
            }
            DebugLog("ParseTree: Condition Node - Feature=" + node.feature + 
                    ", Threshold=" + DoubleToString(node.threshold, 6) + 
                    ", LessEqual=" + (node.is_less_equal ? "Yes" : "No"));
         }

         if(tree_node_count >= 1000) {
            DebugLog("ParseTree: Sicherheitslimit erreicht, restliche Knoten ignoriert");
            continue;
         }

         ArrayResize(decision_tree, tree_node_count + 1);
         decision_tree[tree_node_count] = node;
         int current_index = tree_node_count;
         tree_node_count++;

         ArrayResize(depth_nodes, indent + 1);
         depth_nodes[indent] = current_index;

         if(indent > 0) {
            int parent_index = depth_nodes[indent - 1];
            decision_tree[current_index].parent_index = parent_index;
            if(parent_index >= 0 && parent_index < tree_node_count) {
               if(decision_tree[parent_index].left_child == -1) {
                  decision_tree[parent_index].left_child = current_index;
               } else if(decision_tree[parent_index].right_child == -1) {
                  decision_tree[parent_index].right_child = current_index;
               } else {
                  DebugLog("ParseTree: Parent bereits mit zwei Kindern belegt -> Index " + IntegerToString(parent_index));
               }
            }
         }
      }
   }
   FileClose(file_handle);
   last_rules_status = "Rules geladen: " + IntegerToString(rule_count) + " Regeln, TreeNodes=" + IntegerToString(tree_node_count) + ", WinRate=" + DoubleToString(global_win_rate, 1) + "%, TradeActive=" + (global_trade_active ? "ON" : "OFF");
   DebugLog("LoadRules: " + last_rules_status);
}

// Tagesprozentsatz (TPS) berechnen
double GetTPS() {
   double open_price = iOpen(_Symbol, PERIOD_D1, 0);
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(open_price == 0) return 0.0;
   return ((current_price - open_price) / open_price) * 100.0;
}

// News-Signal einlesen
int GetNewsSignal() {
   if(news_proved && TimeCurrent() >= news_timer_start + news_check_interval_seconds) {
      news_proved = false;
      last_news_signal = 0;
   }

   if(news_proved) return last_news_signal;

   int file_handle = FileOpen(g_news_file, FILE_READ | FILE_TXT | FILE_ANSI);
   int pos_count = 0, neg_count = 0;
   
   if(file_handle == INVALID_HANDLE) {
      double tps = GetTPS();
      int tps_signal = (tps > 1.0) ? 1 : (tps < -1.0) ? -1 : 0;
      last_news_status = "News Datei nicht gefunden, TPS-Fallback: " + DoubleToString(tps, 2) + "% -> Signal=" + IntegerToString(tps_signal);
      news_proved = true;
      news_timer_start = TimeCurrent();
      last_news_signal = tps_signal;
      return tps_signal;
   }

   while(!FileIsEnding(file_handle)) {
      string line = FileReadString(file_handle);
      StringToLower(line);
      pos_count += CountKeywordHits(line, g_positive_news_keywords);
      neg_count += CountKeywordHits(line, g_negative_news_keywords);
      if(StringFind(line, "notriggers: true") >= 0) {
         pos_count = 0;
         neg_count = 0;
         break;
      }
   }
   FileClose(file_handle);

   int asset_info_signal = (pos_count > neg_count) ? 1 : (neg_count > pos_count) ? -1 : 0;
   double tps = GetTPS();
   int final_news_signal = 0;
   if(tps > 1.0) {
      final_news_signal = (asset_info_signal >= 0) ? 1 : 0;
   } else if(tps < -1.0) {
      final_news_signal = (asset_info_signal <= 0) ? -1 : 0;
   } else {
      final_news_signal = asset_info_signal;
   }
   
   news_proved = true;
   news_timer_start = TimeCurrent();
   last_news_signal = final_news_signal;
   last_news_status = "News erfolgreich: Signal=" + IntegerToString(final_news_signal) + ", TPS=" + DoubleToString(tps, 2) + "%";
   return final_news_signal;
}

// === UNIVERSAL ASSET-TYPE DETECTION ===
string GetAssetType(string symbol) {
   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0 || StringFind(symbol, "XRP") >= 0 || 
      StringFind(symbol, "LTC") >= 0 || StringFind(symbol, "SOL") >= 0) {
      return "CRYPTO";
   } else if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0) {
      return "METAL";
   } else if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0 ||
            StringFind(symbol, "JPY") >= 0 || StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "AUD") >= 0 ||
            StringFind(symbol, "CAD") >= 0 || StringFind(symbol, "NZD") >= 0) {
      return "FOREX";
   }
   return "UNKNOWN";
}

// === NEWS-CLOSING SYSTEM - Einfaches News-Flip Detection ===
bool CheckNewsFlip() {
   if(!news_closing_enabled) return false;
   if(trade_entry_sentiment == 0) return false; // Kein Trade-Sentiment gespeichert
   
   int current_sentiment = GetNewsSignal();
   
   // News-Flip erkannt: Trade-Sentiment != Current-Sentiment (und beide nicht NEUTRAL)
   if(trade_entry_sentiment != current_sentiment && current_sentiment != 0) {
      Print("NEWS-FLIP ERKANNT! Trade-Start: ", 
            (trade_entry_sentiment == 1 ? "BULLISH" : trade_entry_sentiment == -1 ? "BEARISH" : "NEUTRAL"),
            " -> Aktuell: ",
            (current_sentiment == 1 ? "BULLISH" : current_sentiment == -1 ? "BEARISH" : "NEUTRAL"));
      return true;
   }
   
   return false;
}

// === TRADE-CLOSING FUNKTION ===
void CloseTradeOnNewsFlip() {
   if(!PositionSelect(_Symbol)) return; // Keine Position vorhanden
   
   if(CheckNewsFlip()) {
      double current_profit = PositionGetDouble(POSITION_PROFIT);
      if(trade.PositionClose(_Symbol)) {
         Print("GOLDJUNGE NEWS-CLOSE: ", _Symbol, " geschlossen bei News-Flip, Profit: ", DoubleToString(current_profit, 2), " ", account_currency);
         
         // Reset Trade-Sentiment nach erfolgreichem Close
         trade_entry_sentiment = 0;
         trade_entry_time = 0;
         StateLog("NEWS_CLOSE", StringFormat("profit=%.2f", current_profit));
      } else {
         Print("Fehler: Trade-Close fehlgeschlagen bei News-Flip, Error: ", GetLastError());
      }
   }
}

// === TRADE HISTORY SYNC (KOORDINIERT MIT COOLDOWN) ===
void SyncLastDeal()
{
   static datetime last_history_sync_time = 0;
   datetime now = TimeCurrent();
   if(now == last_history_sync_time)
      return;

   datetime from_time = history_sync_from;
   if(from_time <= 0)
      from_time = now - 86400 * 90; // Standard: 90 Tage zurück

   if(!HistorySelect(from_time, now))
   {
      last_history_sync_time = now;
      return;
   }

   int total_deals = (int)HistoryDealsTotal();
   if(total_deals <= 0)
   {
      last_history_sync_time = now;
      return;
   }

   for(int i = total_deals - 1; i >= 0; --i)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(last_processed_deal_ticket != 0 && deal_ticket <= last_processed_deal_ticket)
         break;

      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      if(deal_symbol != _Symbol)
         continue;

      int entry_type = (int)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT)
         continue;

      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      int deal_reason = (int)HistoryDealGetInteger(deal_ticket, DEAL_REASON);

      last_processed_deal_ticket = deal_ticket;
      last_deal_time = deal_time;
      last_deal_profit = deal_profit;
      last_deal_reason = deal_reason;

      if(deal_profit < 0.0 || deal_reason == DEAL_REASON_SL)
         last_loss_time = deal_time;

      // Reset News-Sentiment, sobald Position nicht mehr offen ist
      if(!PositionSelect(_Symbol))
      {
         trade_entry_sentiment = 0;
         trade_entry_time = 0;
      }
      break;
   }

   last_history_sync_time = now;
}

bool IsCooldownActive(string &reason)
{
   reason = "";
   if(CooldownMinutesAfterLoss <= 0)
      return false;
   if(last_loss_time == 0)
      return false;

   datetime now = TimeCurrent();
   int cooldown_seconds = CooldownMinutesAfterLoss * 60;
   int elapsed_seconds = (int)(now - last_loss_time);

   if(elapsed_seconds < cooldown_seconds)
   {
      int remaining = cooldown_seconds - elapsed_seconds;
      int remaining_minutes = (remaining + 59) / 60;
      reason = StringFormat("Cooldown aktiv: %d min nach SL (%s)",
                            remaining_minutes,
                            TimeToString(last_loss_time, TIME_MINUTES));
      return true;
   }

   if(CooldownWaitForNewH1Bar)
   {
      datetime current_h1_bar = iTime(_Symbol, PERIOD_H1, 0);
      if(current_h1_bar <= last_loss_time)
      {
         reason = StringFormat("Cooldown: neue H1-Kerze nach SL (%s)",
                               TimeToString(last_loss_time, TIME_MINUTES));
         return true;
      }
   }

   return false;
}

void HandleBreakEven(double atr_value)
{
   if(!EnableBreakEven || atr_value <= 0)
      return;

   if(!PositionSelect(_Symbol))
      return;

   int position_type = (int)PositionGetInteger(POSITION_TYPE);
   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_profit = PositionGetDouble(POSITION_PROFIT);

   double price_diff = (position_type == POSITION_TYPE_BUY) ? (current_price - entry_price) : (entry_price - current_price);
   double trigger = BreakEvenTriggerATR * atr_value;
   bool trigger_by_atr = price_diff >= trigger;
   bool trigger_by_profit = (BreakEvenProfitThreshold > 0.0 && current_profit >= BreakEvenProfitThreshold);

   if(!trigger_by_atr && !trigger_by_profit)
      return;

   double stop_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double offset_price = MathMax(BreakEvenOffsetPips * g_pip_size, stop_level_points * _Point);
   if(offset_price <= 0)
      offset_price = _Point;

   double new_sl = (position_type == POSITION_TYPE_BUY) ? entry_price + offset_price : entry_price - offset_price;

   bool needs_update = false;
   if(position_type == POSITION_TYPE_BUY)
   {
      if(current_sl <= 0 || current_sl < new_sl - _Point / 2.0)
         needs_update = true;
   }
   else
   {
      if(current_sl <= 0 || current_sl > new_sl + _Point / 2.0)
         needs_update = true;
   }

   if(!needs_update)
      return;

   if(trade.PositionModify(_Symbol, new_sl, current_tp))
   {
      string details = StringFormat("type=%s entry=%.5f current=%.5f new_sl=%.5f tp=%.5f trigger=%.2fATR",
                                   position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                   entry_price,
                                   current_price,
                                   new_sl,
                                   current_tp,
                                   BreakEvenTriggerATR);
      if(trigger_by_profit)
         details += StringFormat(", profit=%.2f>=%.2f", current_profit, BreakEvenProfitThreshold);
      StateLog("BREAK_EVEN", details);
      Print("BREAK-EVEN aktiviert: ", _Symbol, " ", (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            " SL→", DoubleToString(new_sl, _Digits));
   }
   else
   {
      int err = GetLastError();
      string err_msg = StringFormat("type=%s entry=%.5f current=%.5f attempted_sl=%.5f tp=%.5f trigger=%.2fATR error=%d",
                                   position_type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                   entry_price,
                                   current_price,
                                   new_sl,
                                   current_tp,
                                   BreakEvenTriggerATR,
                                   err);
      if(trigger_by_profit)
         err_msg += StringFormat(", profit=%.2f>=%.2f", current_profit, BreakEvenProfitThreshold);
      StateLog("BREAK_EVEN_FAIL", err_msg);
      Print("BREAK-EVEN FEHLGESCHLAGEN: ", _Symbol, " ", (position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            " SL", DoubleToString(new_sl, _Digits), " -> Error ", err);
      ResetLastError();
   }
}

// ===== DECISION TREE EVALUATION ENGINE =====
// Evaluates simplified decision tree based on 5-6 features
int EvaluateDecisionTree(double stochastic, double adx, double atr, double weibull_prob, double poisson_prob, double volume) {
   // Use recursive tree traversal if tree is loaded
   if(tree_node_count > 0) {
      int tree_signal = EvaluateGoldTreeRecursive(stochastic, adx, atr, weibull_prob, poisson_prob, volume, 0);
      DebugLog("EvaluateDecisionTree: Tree Signal=" + IntegerToString(tree_signal) + " (TreeNodes=" + IntegerToString(tree_node_count) + ")");
      return tree_signal;
   }
   
   // FALLBACK: Simplified 4-Stage Pipeline wenn keine Tree Rules geladen
   DebugLog("EvaluateDecisionTree: Using fallback logic - no tree rules loaded");
   
   // Stage 1: BreakRevert Analysis
   bool breakrevert_buy = (weibull_prob > 0.0) && (poisson_prob > 0.0);
   bool breakrevert_sell = (weibull_prob < -0.5) || (poisson_prob < -0.5);
   
   // Stage 2: ADX Filter (trend strength)
   bool adx_strong = (adx > -0.5);  // Normalized ADX > 25 approximately
   
   // Stage 3: Stochastic Filter (timing)
   bool stoch_buy_zone = (stochastic < -0.5);   // Normalized Stochastic < 30
   bool stoch_sell_zone = (stochastic > 0.5);   // Normalized Stochastic > 70
   
   // Stage 4: Volume Filter (optional - simplified)
   bool volume_ok = (volume > 0.0);  // Basic volume check
   
   // Decision Tree Logic (simplified but ML-inspired)
   if(breakrevert_buy && adx_strong && stoch_buy_zone && volume_ok) {
      return 1;  // BUY signal
   }
   else if(breakrevert_sell && adx_strong && stoch_sell_zone && volume_ok) {
      return 2;  // SELL signal
   }
   else if(stochastic > 0.8) {
      return 2;  // Strong overbought -> SELL
   }
   else if(stochastic < -0.8) {
      return 1;  // Strong oversold -> BUY
   }
   
   return 0;  // No signal (HOLD)
}

// ===== RECURSIVE TREE TRAVERSAL ENGINE =====
// Core recursive function for AI decision tree evaluation
int EvaluateGoldTreeRecursive(double stochastic, double adx, double atr, double weibull_prob, double poisson_prob, double volume, int node_index = 0) {
   // Validation
   if(node_index >= tree_node_count || node_index < 0) {
      DebugLog("EvaluateGoldTree: Invalid node index " + IntegerToString(node_index));
      return 0;
   }
   
   GoldRuleNode node = decision_tree[node_index];
   
   // Leaf node - return signal
   if(node.is_leaf) {
      DebugLog("EvaluateGoldTree: Leaf reached - Signal=" + IntegerToString(node.signal));
      return node.signal;
   }
   
   // Feature evaluation - get current feature value
   double feature_value = 0.0;
   if(node.feature == "stochastic") feature_value = stochastic;
   else if(node.feature == "adx") feature_value = adx;
   else if(node.feature == "atr") feature_value = atr;
   else if(node.feature == "weibull_prob") feature_value = weibull_prob;
   else if(node.feature == "poisson_prob") feature_value = poisson_prob;
   else if(node.feature == "volume") feature_value = volume;
   else if(node.feature == "Volume") feature_value = volume;  // Case-sensitivity fix
   else {
      DebugLog("EvaluateGoldTree: Unknown feature " + node.feature);
      return 0;
   }
   
   // Condition evaluation
   bool condition_met = node.is_less_equal ? (feature_value <= node.threshold) : (feature_value > node.threshold);
   
   DebugLog("EvaluateGoldTree: " + node.feature + (node.is_less_equal ? " <= " : " > ") + 
           DoubleToString(node.threshold, 6) + " (" + DoubleToString(feature_value, 6) + ") = " + 
           (condition_met ? "True" : "False"));
   
   int next_node = condition_met ? node.left_child : node.right_child;
   if(next_node >= 0 && next_node < tree_node_count) {
      return EvaluateGoldTreeRecursive(stochastic, adx, atr, weibull_prob, poisson_prob, volume, next_node);
   }

   DebugLog("EvaluateGoldTree: Keine Kinder für Knoten " + IntegerToString(node_index) + 
            " (" + node.feature + ") -> Signal=0");
   return 0; // No valid path found
}

// ===== DECISION TREE EVALUATION - REAL ML INTEGRATION =====
int GetRulesSignal() {
   if(rule_count == 0) {
      DebugLog("GetRulesSignal: Keine Rules geladen, Signal=0");
      return 0;
   }
   
   // Get all required features for 4-Stage Pipeline
   double stochastic_k[], atr[], adx_main[];
   long volume[];
   ArraySetAsSeries(stochastic_k, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx_main, true);
   ArraySetAsSeries(volume, true);
   
   if(CopyBuffer(stochastic_handle, 0, 0, 2, stochastic_k) < 2 ||
      CopyBuffer(atr_handle, 0, 0, 2, atr) < 2 ||
      CopyBuffer(adx_handle, 0, 0, 2, adx_main) < 2 ||
      CopyTickVolume(_Symbol, Period(), 0, 2, volume) < 2) {
      DebugLog("GetRulesSignal: Indikatoren nicht verfügbar");
      return 0;
   }
   
   // Calculate 4-Stage Pipeline Features (simplified)
   double feature_stochastic = stochastic_k[1];
   double feature_adx = adx_main[1];
   double feature_atr = atr[1];
   double feature_volume = (double)volume[1];
   
   // BreakRevert probabilities (simplified approximation)
   double close = iClose(_Symbol, Period(), 1);
   double close_prev = iClose(_Symbol, Period(), 2);
   if(close == 0 || close_prev == 0) return 0;
   
   double price_change = MathAbs(close - close_prev);
   double feature_weibull_prob = MathMin(1.0, price_change / (feature_atr * 2.0));
   double feature_poisson_prob = MathMin(1.0, feature_volume / 10000.0);
   
   // REMOVED: Alle Feature-Normalisierungen entfernt!
   // Rules enthalten bereits normalisierte Werte vom Train-KI-Bot
   // Goldjunge gibt RAW Werte an Rules → Rules entscheiden 1:1

   // feature_stochastic = (feature_stochastic - 50.0) / 30.0;  // REMOVED: Doppelte Normalisierung
   // feature_adx = (feature_adx - 30.0) / 20.0;                // REMOVED: Doppelte Normalisierung
   // feature_atr = (feature_atr - 0.001) / 0.002;              // REMOVED: Doppelte Normalisierung
   // feature_weibull_prob = (feature_weibull_prob - 0.5) / 0.3; // REMOVED: Doppelte Normalisierung
   // feature_poisson_prob = (feature_poisson_prob - 0.5) / 0.3; // REMOVED: Doppelte Normalisierung
   
   // TEMP DEBUG: Log all input features before DecisionTree (nur bei EnableDebug)
   if(EnableDebug) {
      Print("TEMP DEBUG GetRulesSignal - Features Input:");
      Print("  Stoch: ", DoubleToString(feature_stochastic, 3), " (raw: ", DoubleToString(stochastic_k[1], 1), ")");
      Print("  ADX: ", DoubleToString(feature_adx, 3), " (raw: ", DoubleToString(adx_main[1], 1), ")");
      Print("  ATR: ", DoubleToString(feature_atr, 3), " (raw: ", DoubleToString(atr[1], 5), ")");
      Print("  WeibullProb: ", DoubleToString(feature_weibull_prob, 3));
      Print("  PoissonProb: ", DoubleToString(feature_poisson_prob, 3));
      Print("  Volume: ", DoubleToString(feature_volume, 0), " (raw: ", IntegerToString(volume[1]), ")");
   }

   // ATR NORMALISIERUNG GEFIXT - zurück zu normaler ATR-Nutzung
   int tree_result = EvaluateDecisionTree(feature_stochastic, feature_adx, feature_atr,
                                         feature_weibull_prob, feature_poisson_prob, feature_volume);

   if(EnableDebug) {
      Print("TEMP DEBUG GetRulesSignal - TreeResult: ", IntegerToString(tree_result));
   }
   
   // Convert tree result to signal (0=no signal, 1=buy, 2=sell)
   int rules_signal = 0;
   if(tree_result == 1) rules_signal = 1;      // BUY
   else if(tree_result == 2) rules_signal = -1; // SELL

   // DEBUG für Rules Signal Diagnose (nur bei EnableDebug)
   if(EnableDebug && rules_signal == 0) {
      DebugLog("GetRulesSignal: TreeResult=" + IntegerToString(tree_result) + " -> RulesSignal=0 (TreeNodes=" + IntegerToString(tree_node_count) + ")");
   }

   if(EnableDebug && rules_signal != 0) {
      DebugLog("GetRulesSignal: DecisionTree Signal=" + IntegerToString(rules_signal) + 
               ", WinRate=" + DoubleToString(global_win_rate, 1) + "%" +
               ", Stoch=" + DoubleToString(feature_stochastic, 3) +
               ", ADX=" + DoubleToString(feature_adx, 3) +
               ", ATR=" + DoubleToString(feature_atr, 3) +
               ", WeibullProb=" + DoubleToString(feature_weibull_prob, 3) +
               ", PoissonProb=" + DoubleToString(feature_poisson_prob, 3));
   }
   
   return rules_signal;
}

// ===== FINALE SIGNAL-LOGIK - GOLDJUNGE SIGNAL-SOURCE SYSTEM =====
int GetFinalSignal(int rule_signal, int logic_signal, int news_signal, double rule_win_rate, string adx_strength) {

   // Logic-only bleibt deaktiviert – wir wollen immer Rules + News sehen
   if(SignalSource == SIGNAL_LOGIC_ONLY) {
      DebugLog("SIGNAL_LOGIC_ONLY: deaktiviert – kein Handel nur mit Logic");
      return 0;
   }

   // Falls optimierte Parameter geladen wurden, entspricht das Rules-Signal der Logic
   int primary_signal = g_optimized_params.parameters_loaded ? logic_signal : rule_signal;

   if(primary_signal == 0) {
      DebugLog("KEIN SIGNAL: Rules/Logic liefern kein Signal (News=" + IntegerToString(news_signal) + ", Logic=" + IntegerToString(logic_signal) + ")");
      return 0;
   }

   if(TestModeNewsObjectionOnly) {
      // Im Testmodus akzeptieren wir neutrale News, blocken aber harte Gegensignale
      if(news_signal != 0 && news_signal != primary_signal) {
         DebugLog("KEIN SIGNAL (TESTMODE): News widersprechen (Primary=" +
                  IntegerToString(primary_signal) + ", News=" + IntegerToString(news_signal) + ")");
         return 0;
      }
   } else {
      if(news_signal != primary_signal) {
         string reason = (news_signal == 0) ? "News fehlen" : "News widersprechen";
         DebugLog("KEIN SIGNAL: " + reason + " (Primary=" + IntegerToString(primary_signal) + ", News=" + IntegerToString(news_signal) + ")");
         return 0;
      }
   }

   if(SignalSource != SIGNAL_RULES_NEWS && logic_signal != 0 && logic_signal != primary_signal) {
      DebugLog("KEIN SIGNAL: Logic widerspricht Rules (Logic=" + IntegerToString(logic_signal) + ", Rules=" + IntegerToString(primary_signal) + ")");
      return 0;
   }

   DebugLog("SIGNAL BESTÄTIGT: Direction=" + IntegerToString(primary_signal) +
            ", News=" + IntegerToString(news_signal) +
            ", Logic=" + IntegerToString(logic_signal) +
            ", WinRate=" + DoubleToString(rule_win_rate, 1) +
            ", ADX=" + adx_strength + ")");
   return primary_signal;
}

// ===== NEUE HILFSFUNKTIONEN FÜR ÜBERARBEITETE BERICHTE =====

// Signalregel-Status ermitteln (Prio: BreakRevert → ADX → Volume → Stochastic → News/Rules Konflikt)
string GetSignalregelStatus(int raw_logic_signal, int news_signal, int rule_signal, double stochastic_k, double volume, double adx) {
   
   // ROHEN BreakRevert Status ermitteln (vor Filtern!)
   // Dazu müssen wir die BreakRevert-Logik ohne Filter ausführen
   double weibull_prob = m_weibull_values.Total() > 0 ? m_weibull_values.At(m_weibull_values.Total() - 1) : 0.5;
   double poisson_prob = m_poisson_values.Total() > 0 ? m_poisson_values.At(m_poisson_values.Total() - 1) : 0.5;
   
   double h1_min = m_close_prices_h1.Total() > 0 ? m_close_prices_h1[0] : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 1; i < m_close_prices_h1.Total(); i++) {
      if(m_close_prices_h1[i] < h1_min) h1_min = m_close_prices_h1[i];
   }
   double h1_max = m_close_prices_h1.Total() > 0 ? m_close_prices_h1[0] : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 1; i < m_close_prices_h1.Total(); i++) {
      if(m_close_prices_h1[i] > h1_max) h1_max = m_close_prices_h1[i];
   }
   double h1_volatility = h1_max - h1_min;
   double h1_trend = m_close_prices_h1.Total() >= 2 ? m_close_prices_h1.At(m_close_prices_h1.Total() - 1) - m_close_prices_h1.At(0) : 0;
   
   // BREAKOUT vs MEAN REVERSION bestimmen
   bool breakout_signal = weibull_prob > Mean_Reversion_Threshold && 
                         poisson_prob > Breakout_Threshold &&
                         h1_volatility > 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   bool mean_reversion_signal = weibull_prob < Mean_Reversion_Threshold && 
                               MathAbs(h1_trend) < 20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // ORIGINAL BREAKREVERT-LOGIK (ohne Filter)
   int raw_breakrevert_signal = 0;
   string signal_type = "";
   
   // Original Logic: Breakout → BUY, Mean Reversion → SELL
   if(breakout_signal) {
      raw_breakrevert_signal = 1;  // BREAKOUT → BUY (Original)
      signal_type = "BREAKOUT BUY";
   } else if(mean_reversion_signal) {
      raw_breakrevert_signal = -1; // MEAN REVERSION → SELL (Original)
      signal_type = "MEAN REVERSION SELL";
   }
   
   // Basis-Anzeige auch wenn kein Signal
   string breakrevert_display = "";
   if(raw_breakrevert_signal == 1) {
      breakrevert_display = "BUY (" + signal_type + ")";
   } else if(raw_breakrevert_signal == -1) {
      breakrevert_display = "SELL (" + signal_type + ")";
   } else {
      breakrevert_display = "KEIN Signal";
   }
   
   // Aktuelle Threshold-Werte ermitteln (optimiert oder Input)
   double debug_adx_min = g_optimized_params.parameters_loaded ? g_optimized_params.adx_min : ADX_Min;
   double debug_stoch_buy_max = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_buy_max : Quality_Stoch_Buy_Max;
   double debug_stoch_sell_min = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_sell_min : Quality_Stoch_Sell_Min;
   double debug_volume_min = g_optimized_params.parameters_loaded ? g_optimized_params.volume_min : Quality_Volume_Min;
   
   // Filter-Status berechnen
   string adx_status = adx >= debug_adx_min ? "+" : "-";
   string volume_status = volume >= debug_volume_min ? "+" : "-";
   string stoch_status = "";
   
   if(raw_breakrevert_signal == 1) { // BUY Signal
      stoch_status = "+"; // Immer + für BUY-Signal
   } else if(raw_breakrevert_signal == -1) { // SELL Signal
      stoch_status = "-"; // Immer - für SELL-Signal
   } else {
      stoch_status = "~"; // Kein Signal = neutral
   }

   string news_expectation = "";
   if(news_signal == 1) {
      news_expectation = " [News→BUY]";
   } else if(news_signal == -1) {
      news_expectation = " [News→SELL]";
   }
   
   // Signalregel zusammenbauen
   string result = "BreakRevert " + breakrevert_display + " → ADX " + DoubleToString(adx, 1) + ">" + DoubleToString(debug_adx_min, 1) + " " + adx_status;
   
   if(raw_breakrevert_signal == 1) { // BUY
      result += " → Stoch " + DoubleToString(stochastic_k, 1) + "<" + DoubleToString(debug_stoch_buy_max, 1) + " " + stoch_status + news_expectation;
   } else if(raw_breakrevert_signal == -1) { // SELL
      result += " → Stoch " + DoubleToString(stochastic_k, 1) + ">" + DoubleToString(debug_stoch_sell_min, 1) + " " + stoch_status + news_expectation;
   } else {
      result += " → Stoch " + DoubleToString(stochastic_k, 1) + " " + stoch_status + news_expectation;
   }
   
   result += " → Volume " + DoubleToString(volume, 0) + ">" + DoubleToString(debug_volume_min, 0) + " " + volume_status;
   
   // News-Status anhängen
   if(news_signal != 0 && raw_breakrevert_signal != 0) {
      if(news_signal == raw_breakrevert_signal) {
         string news_direction = raw_breakrevert_signal == 1 ? "BUY" : "SELL";
         result += " → News " + news_direction + " Boost";
      } else {
         result += " → News Konflikt!";
      }
   }
   
   return result;
}

// TP/SL Info ermitteln
string GetTPSLInfo(double tp_atr, string sl_type, double sl_dist) {
   string tp_source = (global_tp_atr > 0) ? "Rules" : "Bot";
   string sl_source = (StringLen(global_sl_type) > 0) ? "Rules" : "Bot";
   
   string tp_info = "TP: " + DoubleToString(tp_atr, 1) + "xATR (" + tp_source + ")";
   string sl_info = "SL: ";
   if(sl_type == "extrem14") {
      sl_info += "extrem14+" + DoubleToString(sl_dist, 1) + "xATR (" + sl_source + ")";
   } else {
      sl_info += DoubleToString(sl_dist, 1) + "xATR (" + sl_source + ")";
   }
   
   return tp_info + ", " + sl_info;
}

// Hilfsfunktion zum Anhängen von Gründen in kompakten Fehlermeldungen
void AppendReason(string &text, string reason) {
   if(StringLen(reason) == 0) return;
   if(StringLen(text) > 0) text += ", ";
   text += reason;
}

// News-Signal kompakt formatieren
string FormatNewsSignalLine(int news_signal) {
   string direction = news_signal == 1 ? "BUY" : news_signal == -1 ? "SELL" : "NEUTRAL";
   string load_status = news_proved ? "OK" : "FEHLT";
   string fallback_tag = "";
   if(StringFind(last_news_status, "Fallback") >= 0) {
      fallback_tag = "Fallback";
   }

   string tps_info = "";
   int tps_idx = StringFind(last_news_status, "TPS=");
   if(tps_idx >= 0) {
      string rest = StringSubstr(last_news_status, tps_idx + 4);
      int percent_idx = StringFind(rest, "%");
      if(percent_idx >= 0) {
         tps_info = StringSubstr(rest, 0, percent_idx + 1);
         StringTrimLeft(tps_info);
         StringTrimRight(tps_info);
      }
   }

   string result = direction + " [" + load_status;
   if(StringLen(tps_info) > 0) result += ", " + tps_info;
   if(StringLen(fallback_tag) > 0) result += ", " + fallback_tag;
   result += "]";
   return result;
}

// Fehlende Bedingungen für einen Trade sammeln
string BuildMissingConditions(int final_signal,
                              int raw_logic_signal,
                              int news_signal,
                              int rule_signal,
                              double adx_current,
                              double stoch_current,
                              double volume_current,
                              double adx_min,
                              double stoch_buy_max,
                              double stoch_sell_min,
                              double volume_min,
                              bool news_loaded,
                              bool rules_integration_enabled,
                              ENUM_SIGNAL_SOURCE signal_source)
{
   if(final_signal != 0) return "";

   string reasons = "";

   // Logic Signal Check - nur wenn SignalSource Logic erwartet
   bool needs_logic = (signal_source == SIGNAL_ALL || signal_source == SIGNAL_LOGIC_NEWS);
   if(needs_logic && raw_logic_signal == 0) {
      AppendReason(reasons, "Logic Signal");
   }

   // News Check - nur wenn SignalSource News erwartet
   bool needs_news = (signal_source == SIGNAL_ALL || signal_source == SIGNAL_RULES_NEWS || signal_source == SIGNAL_LOGIC_NEWS);
   if(needs_news) {
      if(!news_loaded) {
         AppendReason(reasons, "News Import");
      } else if(needs_logic && raw_logic_signal != 0 && news_signal == -raw_logic_signal) {
         AppendReason(reasons, "News Konflikt");
      }
   }

   // Rules Check - nur wenn SignalSource Rules erwartet
   bool needs_rules = (signal_source == SIGNAL_ALL || signal_source == SIGNAL_RULES_NEWS);
   if(needs_rules) {
      if(rule_count == 0) {
         AppendReason(reasons, "Rules Import");
      } else if(rules_integration_enabled && rule_signal == 0 && raw_logic_signal != 0) {
         AppendReason(reasons, "Rules neutral");
      }
   }

   if(adx_current < adx_min) {
      AppendReason(reasons, "ADX<" + DoubleToString(adx_min, 1));
   }

   if(raw_logic_signal == 1 && stoch_current >= stoch_buy_max) {
      AppendReason(reasons, "Stoch<" + DoubleToString(stoch_buy_max, 1));
   }
   if(raw_logic_signal == -1 && stoch_current <= stoch_sell_min) {
      AppendReason(reasons, "Stoch>" + DoubleToString(stoch_sell_min, 1));
   }

   if(volume_current < volume_min) {
      AppendReason(reasons, "Vol<" + DoubleToString(volume_min, 0));
   }

   return reasons;
}

// Korrekte Risiko-Berechnung
double CalculateRiskAmount() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return balance * RiskPercent / 100;
}

// Bot Status ermitteln (OK/Warnung/Fehler/Debug/Trade Off)
string GetBotStatus() {
   string status_parts[];
   int count = 0;
   
   if(!EnableTrading && !global_trade_active) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "Trade Off";
      count++;
   }
   
   if(!is_h1_timeframe) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "Falsche Zeitchart, Bitte H1 verwenden!";
      count++;
   }
   
   if(EnableDebug) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "Debug";
      count++;
   }
   
   if(StringFind(last_rules_status, "Fehler") >= 0 || StringFind(last_rules_status, "nicht gefunden") >= 0 || rule_count == 0) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "Rules Fehler";
      count++;
   }
   
   if(StringFind(last_news_status, "Fallback") >= 0) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "News Fallback";
      count++;
   }
   
   if(!GapProtection) {
      ArrayResize(status_parts, count + 1);
      status_parts[count] = "Gap Protection OFF";
      count++;
   }
   
   // Check if there's enough money for current lot size
   double required_margin = 0;
   // Lot für Margin-Check berechnen
   double current_lot = GetFinalLotSize();
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, current_lot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), required_margin)) {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(required_margin > free_margin) {
         ArrayResize(status_parts, count + 1);
         status_parts[count] = "KEIN GELD! Lot " + DoubleToString(current_lot, 2) + " braucht " + DoubleToString(required_margin, 0) + " " + account_currency;
         count++;
      }
   }
   
   if(count == 0) return "OK";
   
   string result = status_parts[0];
   for(int i = 1; i < count; i++) {
      result += " & " + status_parts[i];
   }
   return result;
}

// ===== ÜBERARBEITETE EXPORT-FUNKTION (KORREKT! - RAY'S FIX) =====
void ExportASCIIOnlyCSV(ENUM_TIMEFRAMES tf) {
   string symbol = _Symbol;
   string tf_str;
   if(tf == PERIOD_M1) tf_str = "M1";
   else if(tf == PERIOD_M5) tf_str = "M5";
   else if(tf == PERIOD_M15) tf_str = "M15";
   else if(tf == PERIOD_M30) tf_str = "M30";
   else if(tf == PERIOD_H1) tf_str = "H1";
   else tf_str = "H4";
   
   string file_name = symbol + "_" + tf_str + "_extend.csv";
   
   Print("===== ASCII-ONLY EXPORT START: ", file_name, " =====");
   
   // ===== DATUM UND BARS-ANZAHL KORREKT BERECHNEN =====
   datetime start_date = StringToDatetime(HistoryStartDate);
   int bars_to_export = CalculateBarsToExport(symbol, tf, start_date, MaxBarsToExport);
   
   if(bars_to_export <= 0) {
      Print("FEHLER: Keine Bars zum Export für ", symbol, " ", tf_str);
      return;
   }
   
   Print("Exportiere ", bars_to_export, " Bars für ", symbol, " ", tf_str);
   
   // ===== FILE HANDLING =====
   int file_handle = FileOpen(file_name, FILE_WRITE | FILE_TXT);
   if(file_handle == INVALID_HANDLE) {
      Print("FEHLER: ASCII FileOpen fehlgeschlagen für ", file_name, ", Error: ", GetLastError());
      return;
   }
   
   Print("ASCII FileOpen erfolgreich für ", file_name);
   
   // ===== DATEN ARRAYS =====
   datetime time[];
   double open[], high[], low[], close[];
   long volume[];
   
   // Arrays als Zeitreihe setzen (neueste zuerst)
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   
   // ===== DATEN KOPIEREN (KORREKTE ANZAHL!) =====
   int copied_time = CopyTime(symbol, tf, 0, bars_to_export, time);
   int copied_open = CopyOpen(symbol, tf, 0, bars_to_export, open);
   int copied_high = CopyHigh(symbol, tf, 0, bars_to_export, high);
   int copied_low = CopyLow(symbol, tf, 0, bars_to_export, low);
   int copied_close = CopyClose(symbol, tf, 0, bars_to_export, close);
   int copied_volume = CopyTickVolume(symbol, tf, 0, bars_to_export, volume);
   
   // Erfolg prüfen
   if(copied_time <= 0 || copied_open <= 0 || copied_high <= 0 || 
      copied_low <= 0 || copied_close <= 0 || copied_volume <= 0) {
      Print("FEHLER: Daten kopieren fehlgeschlagen:");
      Print("- Time: ", copied_time, " (erwartet: ", bars_to_export, ")");
      Print("- Open: ", copied_open, " (erwartet: ", bars_to_export, ")");
      Print("- High: ", copied_high, " (erwartet: ", bars_to_export, ")");
      Print("- Low: ", copied_low, " (erwartet: ", bars_to_export, ")");
      Print("- Close: ", copied_close, " (erwartet: ", bars_to_export, ")");
      Print("- Volume: ", copied_volume, " (erwartet: ", bars_to_export, ")");
      FileClose(file_handle);
      return;
   }
   
   // Tatsächlich kopierte Anzahl nehmen (minimum aller arrays)
   int actual_bars = MathMin(copied_time, copied_open);
   actual_bars = MathMin(actual_bars, copied_high);
   actual_bars = MathMin(actual_bars, copied_low);
   actual_bars = MathMin(actual_bars, copied_close);
   actual_bars = MathMin(actual_bars, copied_volume);
   
   Print("Erfolgreich kopiert: ", actual_bars, " Bars von ", bars_to_export, " angeforderten");
   
   // ===== ASCII HEADER SCHREIBEN =====
   string header = "time;open;high;low;close;volume";
   FileWrite(file_handle, header);
   Print("ASCII Header geschrieben: ", header);
   
   // ===== DATEN SCHREIBEN (ALLE BARS!) =====
   int price_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int successful_writes = 0;
   
   // Vom ältesten zum neuesten (Array umkehren weil ArraySetAsSeries=true)
   for(int i = actual_bars - 1; i >= 0; i--) {
      // Zeit als YYYY.MM.DD HH:MM
      string time_str = TimeToString(time[i], TIME_DATE | TIME_MINUTES);
      
      // Preise normalisiert
      string open_str = DoubleToString(open[i], price_digits);
      string high_str = DoubleToString(high[i], price_digits);
      string low_str = DoubleToString(low[i], price_digits);
      string close_str = DoubleToString(close[i], price_digits);
      string volume_str = IntegerToString(volume[i]);
      
      // Datenvalidierung
      if(open[i] <= 0 || high[i] <= 0 || low[i] <= 0 || close[i] <= 0) {
         Print("WARNUNG: Ungültige Preisdaten bei Index ", i, " (", time_str, "), überspringe");
         continue;
      }
      
      if(high[i] < low[i] || high[i] < open[i] || high[i] < close[i] || 
         low[i] > open[i] || low[i] > close[i]) {
         Print("WARNUNG: Inkonsistente OHLC-Daten bei Index ", i, " (", time_str, "), überspringe");
         continue;
      }
      
      // ASCII LINE schreiben
      string line = time_str + ";" + open_str + ";" + high_str + ";" + low_str + ";" + close_str + ";" + volume_str;
      FileWrite(file_handle, line);
      successful_writes++;
   }
   
   FileClose(file_handle);
   
   // ===== EXPORT-STATISTIKEN =====
   Print("===== EXPORT ERFOLGREICH ABGESCHLOSSEN =====");
   Print("Datei: ", file_name);
   Print("Pfad: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", file_name);
   Print("Zeilen geschrieben: ", successful_writes, " (+ 1 Header)");
   Print("Zeitraum: ", TimeToString(time[actual_bars-1], TIME_DATE), " bis ", TimeToString(time[0], TIME_DATE));
   Print("Format: Reines ASCII CSV (Semikolon-getrennt)");
   Print("Kompatibel: Train-KI-Bot Python Script");
   
   // Datei-Info
   string full_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + file_name;
   Print("Dateigröße: ~", (successful_writes * 50), " Bytes (geschätzt)");
   Print("Status: READY für Python Import!");
   Print("==============================================");
}

// ===== MULTI-TIMEFRAME EXPORT (KORRIGIERT) =====
void ExportMultiTimeframes() {
   ENUM_TIMEFRAMES export_tfs[] = {PERIOD_M1, PERIOD_M15, PERIOD_H1};
   string tf_names[] = {"M1", "M15", "H1"};
   
   Print("===== VOLLSTÄNDIGER MULTI-TIMEFRAME EXPORT START =====");
   Print("Start-Datum: ", HistoryStartDate);
   Print("Max Bars: ", MaxBarsToExport);
   Print("Symbol: ", _Symbol);
   
   datetime start_time = GetTickCount();
   
   for(int i = 0; i < ArraySize(export_tfs); i++) {
      Print("--- Exportiere ", _Symbol, " ", tf_names[i], " ---");
      ExportASCIIOnlyCSV(export_tfs[i]);
      Print("--- ", tf_names[i], " Export abgeschlossen ---");
   }
   
   datetime end_time = GetTickCount();
   int export_duration = (int)(end_time - start_time);
   
   Print("===== MULTI-TIMEFRAME EXPORT ABGESCHLOSSEN =====");
   Print("Dauer: ", export_duration, " ms");
   Print("Dateien erstellt: ", ArraySize(export_tfs));
   Print("Status: ALLE CSV-DATEIEN READY für Train-KI-Bot!");
   Print("================================================");
}

// Initialisierung
int OnInit() {
   Print("===== GOLDJUNGE v3.1 Initialisierung - SYMBOL-SPECIFIC OPTIMIZATION =====");
   ENUM_TIMEFRAMES tf = Period();

   // 🚀 NEUE FUNKTION: Lade optimierte Parameter
   LoadOptimizedParameters();

   history_sync_from = StringToTime(HistoryStartDate);
   if(history_sync_from <= 0)
      history_sync_from = TimeCurrent() - 86400 * 365; // Default: 1 Jahr Verlauf

   // H1 Timeframe Check
   is_h1_timeframe = (tf == PERIOD_H1);
   if(!is_h1_timeframe) {
      timeframe_warning = "Falsche Zeitchart, Bitte H1 verwenden!";
      Print("WARNUNG: ", timeframe_warning, " (aktuell: ", EnumToString(tf), ")");
   } else {
      timeframe_warning = "";
      Print("Timeframe OK: H1 für Trading bestätigt");
   }
   
   // Alle Timeframes werden unterstützt, aber nur H1 für Trading
   if(tf != PERIOD_M1 && tf != PERIOD_M5 && tf != PERIOD_M15 && tf != PERIOD_M30 && tf != PERIOD_H1 && tf != PERIOD_H4) {
      Print("Fehler: Nur Timeframes M1-H4 unterstützt!");
      return(INIT_FAILED);
   }
   
   stochastic_handle = iStochastic(_Symbol, tf, Stochastic_K_Period, Stochastic_D_Period, Stochastic_Slowing, MODE_SMA, STO_LOWHIGH);
   atr_handle = iATR(_Symbol, tf, ATR_Period);
   adx_handle = iADX(_Symbol, tf, ADX_Period);
   
   if(stochastic_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE || adx_handle == INVALID_HANDLE) {
      Print("Fehler: Indikatoren konnten nicht erstellt werden!");
      return(INIT_FAILED);
   }
   
   if(!SymbolSelect(_Symbol, true)) {
      Print("Fehler: Symbol ", _Symbol, " nicht im Market Watch!");
      return(INIT_FAILED);
   }
   
   InitializeSymbolParameters();
   trade.SetDeviationInPoints(OrderDeviationPoints);
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atr_handle, 0, 0, 14, atr) < 14) {
      Print("Fehler: ATR-Daten konnten nicht geladen werden!");
      return(INIT_FAILED);
   }
   
   news_check_interval_seconds = NewsCheckInterval * 60;
   
   LoadRules(tf);

   if(TpSwingMode)
      LoadSwingState();
   else
      ResetSwingState();
   
   // === NEWS-CLOSING KONFIGURATION ===
   news_closing_enabled = NewsClosingEnabled;
   Print("News-Closing System: ", (news_closing_enabled ? "AKTIVIERT" : "DEAKTIVIERT"));
   
   // Lot-System ist initialisiert
   
   // ===== VOLLSTÄNDIGER MULTI-TIMEFRAME EXPORT BEI INIT =====
   Print("Starte VOLLSTÄNDIGEN Multi-Timeframe Export bei Initialisierung...");
   ExportMultiTimeframes(); // IMMER M1+M15+H1 (VOLLSTÄNDIG!)
   ExportASCIIOnlyCSV(tf); // + aktuelles Timeframe (VOLLSTÄNDIG!)
   last_export = TimeLocal();
   last_rules_import = TimeLocal();
   // last_export_date = TimeLocal();  // DEAKTIVIERT - Export-Blockade entfernt!
   last_import_date = TimeLocal();  // Markiere Init-Import als "heute erledigt"
   
   // Quality Filter Statistiken zurücksetzen
   quality_signals_total = 0;
   quality_signals_passed = 0;
   quality_filter_1_fails = 0;
   quality_filter_2_fails = 0;
   quality_filter_3_fails = 0;
   quality_filter_4_fails = 0;
   quality_bonus_confirms = 0;
   
   if(!EventSetTimer(30)) {  // 30 Sekunden für bessere Export-Chancen
      Print("❌ FEHLER: Timer konnte nicht initialisiert werden!");
      return(INIT_FAILED);
   }
   Print("✅ GOLDJUNGE: Timer erfolgreich auf 60 Sekunden gesetzt!");
   
   m_close_prices_m1.Delta(0.0001);
   m_close_prices_m15.Delta(0.0001);
   m_close_prices_h1.Delta(0.0001);
   m_weibull_values.Delta(0.0001);
   m_poisson_values.Delta(0.0001);
   m_exponential_values.Delta(0.0001);
   
   m_close_prices_m1.Reserve(Lookback_Period * 2);
   m_close_prices_m15.Reserve(Lookback_Period * 2);
   m_close_prices_h1.Reserve(Lookback_Period * 2);
   m_weibull_values.Reserve(Lookback_Period * 2);
   m_poisson_values.Reserve(Lookback_Period * 2);
   m_exponential_values.Reserve(Lookback_Period * 2);
   
   Print("🚀 SHARROW TRADING SYSTEM v1.0 BETA - AI-Powered Strategy with News Integration");
   string asset_type = GetAssetType(_Symbol);
   Print("- Symbol: ", _Symbol, " (", asset_type, "), PipSize: ", DoubleToString(g_pip_size, 8));
   // Asset-Type automatisch bestimmen für Log
   string auto_news_type = GetAssetType(_Symbol);
   Print("- Lot: ", DoubleToString(GetFinalLotSize(), 4), ", NewsType: ", auto_news_type, ", NewsFile: ", g_news_file);
   Print("- Quality Filter: ADX>", DoubleToString(ADX_Min, 0), " (stark>", DoubleToString(ADX_Strong_Min, 0), "), Stoch Buy<", DoubleToString(Quality_Stoch_Buy_Max, 0), ", Sell>", DoubleToString(Quality_Stoch_Sell_Min, 0), ", Vol>", DoubleToString(Quality_Volume_Min, 0));
   Print("- Rules System: ", (RulesIntegration ? "VOLLSTÄNDIG AKTIV (3 Regeln)" : "TEILWEISE AKTIV (nur TP/SL/Lot)"), " (rules_", _Symbol, ".txt)");
   Print("- BreakRevert: Breakout>", DoubleToString(Breakout_Threshold, 2), ", MeanReversion<", DoubleToString(Mean_Reversion_Threshold, 2));
   Print("- Trading: NUR auf H1 erlaubt, aktuell: ", is_h1_timeframe ? "OK" : "WARNUNG");
   Print("- Gap Protection: ", GapProtection ? "OK (aktiv)" : "WARNUNG (deaktiviert)", ", Stop: ", StopHoursBeforeClose, "h vor Schluss, Min Gap: ", MinGapHours, "h");
   Print("- Export: VOLLSTÄNDIGE HISTORISCHE DATEN (", DoubleToString(MaxBarsToExport, 0), " Bars max, ab ", HistoryStartDate, ")");
   Print("===== Initialisierung abgeschlossen =====");
   if(g_optimized_params.parameters_loaded) {
      Print("🎯 Using OPTIMIZED parameters for ", _Symbol);
   } else {
      Print("⚠️ Using INPUT parameters as fallback for ", _Symbol);
   }
   return(INIT_SUCCEEDED);
}

// Timer (VOLLSTÄNDIGER Export, kein Import mehr bei Timeframe-Wechsel)
void OnTimer() {
   if(EnableDebug) Print("🔍 GOLDJUNGE TIMER CALLED at ", TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   ENUM_TIMEFRAMES tf = Period();
   datetime now = TimeLocal();  // RECHNERZEIT verwenden!
   MqlDateTime time_struct;
   TimeToStruct(now, time_struct);
   if(EnableDebug) Print("🔍 DEBUG GOLDJUNGE: Verwende RECHNERZEIT - ", time_struct.hour, ":", StringFormat("%02d", time_struct.min));
   
   int day_of_week = time_struct.day_of_week;
   // FIX: Korrekte Berechnung - Montag=0, Dienstag=1, ... Sonntag=6
   int days_since_monday = (day_of_week == 0) ? 6 : (day_of_week - 1);

   // ===== EXPORT LOGIC - SMART RHYTHM ANALYZER =====
   bool export_triggered = false;
   if(EnableDebug) Print("🔍 DEBUG GOLDJUNGE: Timer reached export logic at ", TimeToString(now, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   if(EnableDebug) Print("🔍 DEBUG GOLDJUNGE: Checking export - Interval: ", (int)ExportInterval, ", Hour: ", (int)ExportHour, ", Minute: ", (int)ExportMinute);
   
   // Monatlicher Export-Tag hat Priorität
   if(ExportMonthDay != MONTH_DAY_OFF && time_struct.day == ExportMonthDay && 
      IsValidDay(time_struct.mon, time_struct.day, time_struct.year) &&
      MathAbs(time_struct.hour * 60 + time_struct.min - (ExportHour * 60 + ExportMinute)) <= 5) {
      export_triggered = true;
   } 
   // Smart Rhythm Check für Intervalle
   else if(ExportMonthDay == MONTH_DAY_OFF && ExportInterval != INTERVAL_OFF &&
           IsRhythmTriggerToday(ExportInterval, days_since_monday) &&
           MathAbs(time_struct.hour * 60 + time_struct.min - (ExportHour * 60 + ExportMinute)) <= 5) {
      export_triggered = true;
   }
   
   // EXPORT-PROTECTION: Einmal pro Tag (sinnvolle Blockade wieder aktiviert)
   string today_date = TimeToString(now, TIME_DATE);
   string last_export_date_str = TimeToString(last_export_date, TIME_DATE);
   bool export_already_done_today = (today_date == last_export_date_str);
   
   if(EnableDebug) {
       Print("🔍 DEBUG GOLDJUNGE: Export triggered: ", export_triggered ? "YES" : "NO");
       Print("🔍 DEBUG GOLDJUNGE: Today: ", today_date, ", LastExport: ", last_export_date_str, ", AlreadyDone: ", export_already_done_today ? "YES" : "NO");
       // Export Debug Info
       bool rhythm_trigger = IsRhythmTriggerToday(ExportInterval, days_since_monday);
       int current_time_minutes = time_struct.hour * 60 + time_struct.min;
       int export_time_minutes = ExportHour * 60 + ExportMinute;
       int time_diff = MathAbs(current_time_minutes - export_time_minutes);
       Print("🔍 DEBUG EXPORT: Interval=", (int)ExportInterval, ", RhythmToday=", rhythm_trigger, ", TimeDiff=", time_diff, "min (need <=5)");
   }
   
   if(export_triggered && !export_already_done_today) {
      int next_in_days = FindNextRhythmTrigger(ExportInterval, days_since_monday);
      Print("🎯 Smart Rhythm: Export-Tag erkannt! Nächster Trigger in ", next_in_days, " Tagen");
      Print("✅ Export-Timer ausgelöst für ", today_date, " um ", time_struct.hour, ":", StringFormat("%02d", time_struct.min));
      Print("🚀 Starte VOLLSTÄNDIGEN Multi-Timeframe Export...");
      ExportMultiTimeframes(); // IMMER M1+M15+H1 (VOLLSTÄNDIG!)
      ExportASCIIOnlyCSV(tf); // + aktuelles Timeframe (VOLLSTÄNDIG!)
      last_export = now;
      last_export_date = now; // Blockiere weitere Exports heute
      Print("✅ Export abgeschlossen - nächster Export nach Zeitplan!");
   } else if(export_triggered && export_already_done_today) {
       if(EnableDebug) Print("⏭️ Export heute bereits erledigt - überspringe");
   }

   // ===== IMPORT LOGIC - SMART RHYTHM ANALYZER =====
   bool import_triggered = false;
   
   // Monatlicher Import-Tag hat Priorität
   if(ImportMonthDay != MONTH_DAY_OFF && time_struct.day == ImportMonthDay && 
      IsValidDay(time_struct.mon, time_struct.day, time_struct.year) &&
      MathAbs(time_struct.hour * 60 + time_struct.min - (ImportHour * 60 + ImportMinute)) <= 5) {
      import_triggered = true;
   } 
   // Smart Rhythm Check für Intervalle
   else if(ImportMonthDay == MONTH_DAY_OFF && ImportInterval != INTERVAL_OFF &&
           IsRhythmTriggerToday(ImportInterval, days_since_monday) &&
           MathAbs(time_struct.hour * 60 + time_struct.min - (ImportHour * 60 + ImportMinute)) <= 5) {
      import_triggered = true;
   }
   
   // NEUE LOGIK: Prüfe ob Import heute schon gemacht wurde
   string last_import_date_str = TimeToString(last_import_date, TIME_DATE);
   bool import_already_done_today = (today_date == last_import_date_str);
   
   if(import_triggered && !import_already_done_today) {
      int next_in_days = FindNextRhythmTrigger(ImportInterval, days_since_monday);
      Print("🎯 Smart Rhythm: Import-Tag erkannt! Nächster Trigger in ", next_in_days, " Tagen");
      Print("✅ Import-Timer ausgelöst für ", today_date, " um ", time_struct.hour, ":", StringFormat("%02d", time_struct.min));
      Print("📥 Lade neue Rules...");
      LoadRules(tf);
      last_rules_import = now;
      last_import_date = now; // Markiere als "heute erledigt"
      Print("✅ Import abgeschlossen und als erledigt markiert für ", today_date);
   } else if(import_triggered && import_already_done_today) {
      if(EnableDebug) Print("⏭️ Import heute bereits erledigt (", last_import_date_str, ") - überspringe");
   }
   
   // ===== RHYTHM DEBUG INFO (nur beim ersten Timer-Lauf) =====
   static bool rhythm_info_shown = false;
   if(!rhythm_info_shown) {
      string day_names[] = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"};
      Print("🎵 SMART RHYTHM ANALYZER gestartet:");
      // SICHER: Array-Zugriff prüfen
      int safe_day_index = days_since_monday % 7;  // 0-6 garantiert
      if(safe_day_index < 0) safe_day_index = 0;
      Print("📅 Heute: ", day_names[safe_day_index], " (Tag ", days_since_monday, " seit Montag, Index: ", safe_day_index, ")");
      
      // Export Rhythm Info
      if(ExportInterval != INTERVAL_OFF) {
         int export_trigger_days[];
         int export_count = GetTriggerDaysForInterval(ExportInterval, export_trigger_days);
         string export_pattern = "";
         for(int i = 0; i < export_count; i++) {
            if(i > 0) export_pattern += ", ";
            int safe_export_day = export_trigger_days[i] % 7;
            if(safe_export_day < 0) safe_export_day = 0;
            export_pattern += day_names[safe_export_day];
         }
         int next_export_days = FindNextRhythmTrigger(ExportInterval, days_since_monday);
         Print("📤 Export Pattern: [", export_pattern, "] → Nächster in ", next_export_days, " Tagen");
      }
      
      // Import Rhythm Info
      if(ImportInterval != INTERVAL_OFF) {
         int import_trigger_days[];
         int import_count = GetTriggerDaysForInterval(ImportInterval, import_trigger_days);
         string import_pattern = "";
         for(int i = 0; i < import_count; i++) {
            if(i > 0) import_pattern += ", ";
            import_pattern += day_names[import_trigger_days[i]];
         }
         int next_import_days = FindNextRhythmTrigger(ImportInterval, days_since_monday);
         Print("📥 Import Pattern: [", import_pattern, "] → Nächster in ", next_import_days, " Tagen");
      }
      
      rhythm_info_shown = true;
   }

   // ===== NEWS IMPORT LOGIC - ZEITGESTEUERT MIT +5 MIN OFFSET =====
   bool news_import_triggered = false;
   
   // News-Import: Alle Intervalle + 5 Minuten Offset 
   int target_minutes = -1;
   if(NewsCheckInterval == 15) {
       // 15-Min Intervall: xx:05, xx:20, xx:35, xx:50
       if(time_struct.min >= 5 && time_struct.min <= 10) target_minutes = 5;
       else if(time_struct.min >= 20 && time_struct.min <= 25) target_minutes = 20;
       else if(time_struct.min >= 35 && time_struct.min <= 40) target_minutes = 35;
       else if(time_struct.min >= 50 && time_struct.min <= 55) target_minutes = 50;
   } else if(NewsCheckInterval == 30) {
       // 30-Min Intervall: xx:05, xx:35  
       if(time_struct.min >= 5 && time_struct.min <= 10) target_minutes = 5;
       else if(time_struct.min >= 35 && time_struct.min <= 40) target_minutes = 35;
   } else if(NewsCheckInterval == 45) {
       // 45-Min Intervall: xx:05 (alle 45 Min ab :05)
       if(time_struct.min >= 5 && time_struct.min <= 10) target_minutes = 5;
   } else if(NewsCheckInterval == 60) {
       // 60-Min Intervall: xx:05 (jede Stunde um :05)
       if(time_struct.min >= 5 && time_struct.min <= 10) target_minutes = 5;
   } else if(NewsCheckInterval == 90) {
       // 90-Min Intervall: xx:05 (alle 90 Min ab :05) - nur ungerade Stunden
       if(time_struct.min >= 5 && time_struct.min <= 10 && (time_struct.hour % 2) == 1) target_minutes = 5;
   } else if(NewsCheckInterval == 120) {
       // 120-Min Intervall: xx:05 (alle 2 Stunden ab :05) - nur gerade Stunden
       if(time_struct.min >= 5 && time_struct.min <= 10 && (time_struct.hour % 2) == 0) target_minutes = 5;
   } else {
       // Fallback: Altes Timer-System für andere Intervalle
       if(TimeCurrent() >= news_timer_start + news_check_interval_seconds) {
           news_import_triggered = true;
       }
   }
   
   if(target_minutes >= 0) {
       int time_diff = MathAbs(time_struct.min - target_minutes);
       if(time_diff <= 5) news_import_triggered = true;
   }
   
   // News-Import-Blockade: Einmal pro Stunde
   string current_hour_str = TimeToString(now, TIME_DATE) + "_" + IntegerToString(time_struct.hour);
   static string last_news_import_hour = "";
   bool news_already_done_this_hour = (current_hour_str == last_news_import_hour);
   
   if(EnableDebug && news_import_triggered) {
       Print("🔍 DEBUG NEWS: Import triggered at ", time_struct.hour, ":", StringFormat("%02d", time_struct.min), 
             ", Target=", target_minutes, ", AlreadyDone=", news_already_done_this_hour ? "YES" : "NO");
   }
   
   if(news_import_triggered && !news_already_done_this_hour) {
       Print("📰 News-Timer ausgelöst um ", time_struct.hour, ":", StringFormat("%02d", time_struct.min), " (+5min Offset)");
       Print("🔄 Lade neue News-Dateien...");
       // Reset News-Cache um neuen Import zu forcieren
       news_proved = false;
       last_news_signal = 0;
       news_timer_start = TimeCurrent();
       last_news_import_hour = current_hour_str;
       Print("✅ News-Cache zurückgesetzt - nächster News-Import in ", NewsCheckInterval, " Minuten");
   }
}

// ===== WEEKEND GAP PROTECTION FUNCTIONS =====
bool IsMarketSafeForNewTrades() {
   if(!GapProtection) return true;  // Gap-Schutz deaktiviert
   
   datetime current_time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   datetime session_start, session_end;
   bool session_found = false;
   
   // Aktuelle Wochentag-Session finden
   ENUM_DAY_OF_WEEK current_day = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   if(SymbolInfoSessionTrade(_Symbol, current_day, 0, session_start, session_end)) {
      session_found = true;
   }
   
   if(!session_found) {
      // Fallback: Markt-Status prüfen
      return SymbolInfoInteger(_Symbol, SYMBOL_SESSION_DEALS) > 0;
   }
   
   // Zeit bis Marktschluss heute
   long seconds_to_close = session_end - current_time;
   int hours_to_close = (int)(seconds_to_close / 3600);
   
   // Nächste Session finden (normalerweise nächster Tag oder nach Weekend)
   datetime next_session_start = 0, next_session_end = 0;
   for(int day = 1; day <= 7; day++) {
      ENUM_DAY_OF_WEEK next_day = (ENUM_DAY_OF_WEEK)((current_day + day) % 7);
      if(SymbolInfoSessionTrade(_Symbol, next_day, 0, next_session_start, next_session_end)) {
         break;
      }
   }
   
   if(next_session_start > 0) {
      // Gap-Dauer bis zur nächsten Öffnung
      long gap_seconds = next_session_start - session_end;
      int gap_hours = (int)(gap_seconds / 3600);
      
      // Weekend/Holiday Gap erkannt?
      if(gap_hours > MinGapHours && hours_to_close <= StopHoursBeforeClose && hours_to_close > 0) {
         Print("GAP PROTECTION: Trading gestoppt! Marktschluss in ", hours_to_close, "h, Gap: ", gap_hours, "h");
         return false;
      }
   }
   
   return true;  // Sicher zu traden
}

// ===== HAUPTLOGIK - GOLDJUNGE v3.0 =====
void OnTick() {
   // === TRADEACTIVE CHECK - VOLLAUTOMATISCHE KONTROLLE ===
   if(!global_trade_active) {
      // Trading deaktiviert - Ressourcen schonen, keine Berichte, völlig inaktiv
      return;
   }
   
   // === WEEKEND GAP PROTECTION ===
   if(GapProtection && !IsMarketSafeForNewTrades()) {
      // Keine neuen Trades vor Marktschluss - Gap-Schutz aktiv
      return;
   }
   
   // === NEWS-FLIP DETECTION - Überwachung laufender Trades ===
   CloseTradeOnNewsFlip();
   SyncLastDeal();
   
   ENUM_TIMEFRAMES tf = Period();
   string tf_str = tf == PERIOD_M1 ? "M1" : tf == PERIOD_M5 ? "M5" : tf == PERIOD_M15 ? "M15" : tf == PERIOD_M30 ? "M30" : tf == PERIOD_H1 ? "H1" : "H4";
   
   double stochastic_k[], atr[], adx[];
   long volume[];
   ArraySetAsSeries(stochastic_k, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(volume, true);
   
   if(CopyBuffer(stochastic_handle, 0, 0, 2, stochastic_k) < 2 ||
      CopyBuffer(atr_handle, 0, 0, 2, atr) < 2 ||
      CopyBuffer(adx_handle, 0, 0, 2, adx) < 2 ||
      CopyTickVolume(_Symbol, tf, 0, 2, volume) < 2) {
      Print("Fehler: Indikatoren konnten nicht geladen werden!");
      return;
   }
   
   double adx_current   = adx[1];
   double stoch_current = stochastic_k[1];
   double volume_current = (double)volume[1];

   HandleBreakEven(atr[1]);
   HandleTpSwing();

   double close = iClose(_Symbol, tf, 1);
   if(close == 0) return;
   
   // ===== SIGNAL-BERECHNUNG =====
   int raw_logic_signal = GetLogicSignal();  // Bereits mit ADX/Stoch/Vol-Verifikation!
   int news_signal = GetNewsSignal();
   int rule_signal = GetRulesSignal();
   if(g_optimized_params.parameters_loaded)
      rule_signal = raw_logic_signal;
   double rule_win_rate = global_win_rate;
   
   // ===== ADX STRENGTH BESTIMMEN =====
   string adx_strength = adx_current >= ADX_Strong_Min ? "strong" : adx_current >= ADX_Min ? "weak" : "very weak";
   
   // ===== FINALE ENTSCHEIDUNG - 3-REGEL-SYSTEM =====
   int final_signal = GetFinalSignal(rule_signal, raw_logic_signal, news_signal, rule_win_rate, adx_strength);
   
   // ===== TP/SL BERECHNUNG =====
   double tp_atr = (global_tp_atr > 0) ? global_tp_atr : GetTPMultiplier(FixedTP);
   double sl_dist = 0.0;
   string sl_type = (StringLen(global_sl_type) > 0) ? global_sl_type : (StringFind(GetSLVariant(FixedSL), "extrem14") >= 0 ? "extrem14" : "atr");
   
   if(StringLen(global_sl_type) > 0) {
      sl_dist = global_sl_dist;
   } else {
      string sl_variant = GetSLVariant(FixedSL);
      if(StringFind(sl_variant, "extrem14") >= 0) {
         sl_dist = StringToDouble(StringSubstr(sl_variant, StringFind(sl_variant, "+") + 1, StringLen(sl_variant) - StringFind(sl_variant, "+") - 5));
      } else {
         sl_dist = StringToDouble(StringSubstr(sl_variant, 0, StringLen(sl_variant) - 4));
      }
   }
   
   // Lot-Größe berechnen
   double lot = GetFinalLotSize();
   double sl_price = 0.0;
   double tp_price = 0.0;
   double sl_dist_val = 0.0;
   
   if(final_signal != 0) {
      double low_14 = iLow(_Symbol, tf, iLowest(_Symbol, tf, MODE_LOW, 14, 1));
      double high_14 = iHigh(_Symbol, tf, iHighest(_Symbol, tf, MODE_HIGH, 14, 1));
      
      if(sl_type == "extrem14") {
         sl_price = final_signal == 1 ? low_14 - sl_dist * atr[1] : high_14 + sl_dist * atr[1];
      } else {
         sl_price = final_signal == 1 ? close - sl_dist * atr[1] : close + sl_dist * atr[1];
      }
      
      sl_dist_val = final_signal == 1 ? close - sl_price : sl_price - close;
      // TP-Berechnung mit optionalem Live-Spread-Puffer
      if(UseSpreadAdjustment) {
         double live_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         tp_price = final_signal == 1 ? 
                    close + tp_atr * atr[1] + live_spread :  // BUY: TP weiter weg
                    close - tp_atr * atr[1] - live_spread;   // SELL: TP weiter weg
         if(EnableDebug) 
            DebugLog("TP mit Spread: Live-Spread=" + DoubleToString(live_spread/_Point, 1) + " Pips, TP=" + DoubleToString(tp_price, _Digits));
      } else {
         tp_price = final_signal == 1 ? 
                    close + tp_atr * atr[1] :                // BUY: Ohne Spread
                    close - tp_atr * atr[1];                 // SELL: Ohne Spread
         if(EnableDebug) 
            DebugLog("TP ohne Spread: TP=" + DoubleToString(tp_price, _Digits));
      }
      
      // ===== DYNAMISCHE STOPS LEVEL VALIDATION =====
      ValidateStops(sl_price, tp_price, final_signal);
      
      if(sl_dist_val > 0) {
         double sl_pips = MathMax(MinSLPips, sl_dist_val / g_pip_size);
         
         // Lot-Größe ist bereits berechnet
      } else {
         Print("Kein Trade: Ungültige SL-Distanz");
         return;
      }
   }
   
   // ===== ÜBERARBEITETE BERICHTE - NEUE STRUKTUR =====

   double threshold_adx = g_optimized_params.parameters_loaded ? g_optimized_params.adx_min : ADX_Min;
   double threshold_stoch_buy = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_buy_max : Quality_Stoch_Buy_Max;
   double threshold_stoch_sell = g_optimized_params.parameters_loaded ? g_optimized_params.stoch_sell_min : Quality_Stoch_Sell_Min;
   double threshold_volume = g_optimized_params.parameters_loaded ? g_optimized_params.volume_min : Quality_Volume_Min;

   // 1. Bot Status (mit Asset-Type & TP/SL)
   string news_type = GetAssetType(_Symbol);
   string lot_source = global_lot_size > 0 ? "Rules Lot" : FixedLot > 0 ? "Fester Lot" : "Risiko Lot";
   double actual_lot_value = lot * g_margin_per_lot;

   // 2. Import Status (News & Rules)
   string import_status_news = StringFind(last_news_status, "erfolgreich") >= 0 ?
      "News OK " + TimeToString(news_timer_start, TIME_DATE | TIME_MINUTES) :
      (news_proved ? "News OK" : "News Fallback/Fehlt") + " " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);

   string import_status_rules = "";
   if(StringFind(last_rules_status, "geladen") >= 0) {
      import_status_rules = "Rules OK " + TimeToString(last_rules_import, TIME_DATE | TIME_MINUTES) + " (WinRate=" + DoubleToString(global_win_rate, 1) + "%)";
   } else {
      import_status_rules = "Rules Fehler " + TimeToString(last_rules_import, TIME_DATE | TIME_MINUTES);
   }

   // 3. Export Status
   string export_status = "Export OK " + TimeToString(last_export, TIME_DATE | TIME_MINUTES) + " (Historie ab " + HistoryStartDate + ")";

   int original_final_signal = final_signal;

   // 4. Trade Status / Gründe (Basis)
   string trade_reason = "";
   if(final_signal != 0) {
      trade_reason = (rule_signal != 0) ? "Rules OK" : "Logic OK";
      if(news_signal == final_signal) {
         trade_reason += " + News Boost";
      }
   } else {
      trade_reason = "Keine Regel erfüllt";
   }

   string missing_components = BuildMissingConditions(final_signal,
                                                     raw_logic_signal,
                                                     news_signal,
                                                     rule_signal,
                                                     adx_current,
                                                     stoch_current,
                                                     volume_current,
                                                     threshold_adx,
                                                     threshold_stoch_buy,
                                                     threshold_stoch_sell,
                                                     threshold_volume,
                                                     news_proved,
                                                     RulesIntegration,
                                                     SignalSource);

   string cooldown_reason = "";
   if(original_final_signal != 0 && IsCooldownActive(cooldown_reason)) {
      final_signal = 0;
      trade_reason = cooldown_reason;
      if(StringLen(missing_components) > 0)
         missing_components += ", ";
      missing_components += cooldown_reason;
   }

   // 4. Trade Status / Gründe (final)
   string trade_signal = final_signal == 1 ? "BUY" : final_signal == -1 ? "SELL" : "KEIN";
   string trade_grund = trade_reason;
   if(final_signal == 0 && StringLen(missing_components) > 0) {
      trade_grund = "Fehlt: " + missing_components;
   }

   // 5. Signalregel & detaillierte Anzeige
   string signalregel = GetSignalregelStatus(raw_logic_signal, news_signal, rule_signal, stoch_current, volume_current, adx_current);

   // 6. Signal Status (Rules, Logic, News)
   string signal_rules = rule_signal == 1 ? "BUY" : rule_signal == -1 ? "SELL" : "KEIN";
   string signal_logic = raw_logic_signal == 1 ? "BUY" : raw_logic_signal == -1 ? "SELL" : "KEIN";
   string signal_news = news_signal == 1 ? "BUY" : news_signal == -1 ? "SELL" : "KEIN";

   // 7. TP/SL Info
   string tpsl_info = GetTPSLInfo(tp_atr, sl_type, sl_dist);

   // 8. Bot Status (OK/Warnung/Fehler/Debug/Trade Off)
   string final_bot_status = GetBotStatus();

   string signals_line = "News " + FormatNewsSignalLine(news_signal) + " | " + signalregel;

   Print("===== GOLDJUNGE v5.0 BERICHT =====");
   string bot_line = "Bot: " + _Symbol + " " + tf_str + " | Lot " + DoubleToString(lot, 2) + " (" + lot_source + ", " + DoubleToString(actual_lot_value, 0) + " " + account_currency + ") | " + tpsl_info + " | " + news_type;
   if(account_too_small) bot_line += " | KONTO ZU KLEIN";
   Print(bot_line);
   Print("Import: " + import_status_news + " | " + import_status_rules);
   Print("Export: " + export_status);
   string trade_line = "Trade: " + trade_signal;
   if(final_signal != 0)
   {
      trade_line += " | Kurs " + DoubleToString(close, _Digits) +
                    " | TP " + DoubleToString(tp_price, _Digits) +
                    " | SL " + DoubleToString(sl_price, _Digits);
   }
   if(StringLen(trade_grund) > 0) trade_line += " - " + trade_grund;
   Print(trade_line);

   if(PositionSelect(_Symbol))
   {
      int pos_type = (int)PositionGetInteger(POSITION_TYPE);
      string pos_side = pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL";
      double pos_entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double pos_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double pos_tp = PositionGetDouble(POSITION_TP);
      double pos_sl = PositionGetDouble(POSITION_SL);
      double pos_profit = PositionGetDouble(POSITION_PROFIT);

      string sl_flag = "";
      if(EnableBreakEven)
      {
         double stop_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double be_threshold = MathMax(BreakEvenOffsetPips * g_pip_size, stop_level_points * _Point) + 5 * _Point;
         double sl_diff = MathAbs(pos_sl - pos_entry);
         if((pos_type == POSITION_TYPE_BUY && pos_sl >= pos_entry && sl_diff <= be_threshold) ||
            (pos_type == POSITION_TYPE_SELL && pos_sl <= pos_entry && sl_diff <= be_threshold))
         {
            sl_flag = " (BE)";
         }
      }

      string position_line = StringFormat("Position: %s @%s | Kurs %s | TP %s | SL %s%s | Profit %.2f",
                                          pos_side,
                                          DoubleToString(pos_entry, _Digits),
                                          DoubleToString(pos_price, _Digits),
                                          DoubleToString(pos_tp, _Digits),
                                          DoubleToString(pos_sl, _Digits),
                                          sl_flag,
                                          pos_profit);
      Print(position_line);
   }
   Print("Signale: " + signals_line);
   Print("Signal Status: Rules=" + signal_rules + ", Logic=" + signal_logic + ", News=" + signal_news);
   Print("Status: " + final_bot_status);
   
   // ===== DEBUG BERICHT (NUR WENN EnableDebug = true) =====
   if(EnableDebug) {
      Print("===== DEBUG DETAILS =====");
      Print("DEBUG Raw Signals: BreakRevert ", IntegerToString(raw_logic_signal), 
            ", Rules ", IntegerToString(rule_signal), ", News ", IntegerToString(news_signal));
      // 🚀 Debug mit optimierten Parametern
      string param_source = g_optimized_params.parameters_loaded ? "OPT" : "INPUT";
      
      Print("DEBUG Quality Check: ADX ", DoubleToString(adx_current, 1), " (min ", DoubleToString(threshold_adx, 1), 
            "), Stoch ", DoubleToString(stoch_current, 1), ", Vol ", IntegerToString((int)volume_current), " (min ", DoubleToString(threshold_volume, 0), ") [", param_source, "]");
      Print("DEBUG Trade Calc: Lot Value ", DoubleToString(actual_lot_value, 2), 
            " " + account_currency + ", SL Pips ", DoubleToString(sl_dist_val / g_pip_size, 1));
      Print("DEBUG Broker Limits: Min Lot ", DoubleToString(g_min_lot, 4), ", Max Lot ", DoubleToString(g_max_lot, 2), 
            ", Step ", DoubleToString(g_volume_step, 4));
      Print("DEBUG Files: News ", g_news_file, ", Rules rules_", _Symbol, ".txt", 
            ", Last Import ", TimeToString(last_rules_import, TIME_DATE | TIME_MINUTES));
      Print("DEBUG Prices: Current ", DoubleToString(close, 2), ", TP ", DoubleToString(tp_price, 2), ", SL ", DoubleToString(sl_price, 2));
      Print("DEBUG BreakRevert: Weibull ", DoubleToString(m_weibull_values.Total() > 0 ? m_weibull_values.At(m_weibull_values.Total() - 1) : 0, 3), 
            ", Poisson ", DoubleToString(m_poisson_values.Total() > 0 ? m_poisson_values.At(m_poisson_values.Total() - 1) : 0, 3));
      Print("DEBUG Thresholds: Breakout>", DoubleToString(Breakout_Threshold, 2), ", MeanReversion<", DoubleToString(Mean_Reversion_Threshold, 2));
      Print("DEBUG Memory: M1 Data ", IntegerToString(m_close_prices_m1.Total()), ", M15 Data ", IntegerToString(m_close_prices_m15.Total()), 
            ", H1 Data ", IntegerToString(m_close_prices_h1.Total()));
      Print("DEBUG Timeframe: aktuell=", tf_str, ", H1 Trading=", is_h1_timeframe ? "JA" : "NEIN");
      Print("DEBUG CSV Export: VOLLSTÄNDIGE HISTORISCHE DATEN (", MaxBarsToExport, " Bars max, ab ", HistoryStartDate, ")");
      Print("===== DEBUG END =====");
   }
   Print("===== BERICHT ENDE =====");
   
   // ===== H1 TRADING ONLY CHECK =====
   // Wenn kein finales Signal zustande kam, logge die genauen Gründe (Quality + Status) und beende
   if(final_signal == 0)
   {
      if(EnableDebug) {
         // Versuche, die zuletzt berechneten Quality-Werte mit den Schwellen auszugeben
         // (Variablen wie adx, stochastic_k, volume sowie debug_* wurden zuvor im Bericht berechnet)
         Print("NO-TRADE REPORT: final_signal=0");
         Print("  RulesStatus= ", last_rules_status);
         Print("  NewsStatus = ", last_news_status);
         // Quality-Gates (falls Werte im Scope sind)
         Print("  Quality   : ADX=", DoubleToString(adx_current, 1), " (min ", DoubleToString(threshold_adx, 1), ")",
               ", Stoch=", DoubleToString(stoch_current, 1),
               " (buy<", DoubleToString(threshold_stoch_buy, 1), "/sell>", DoubleToString(threshold_stoch_sell, 1), ")",
               ", Vol=", IntegerToString((int)volume_current), " (min ", IntegerToString((int)threshold_volume), ")");
         Print("  Gates     : H1=", (is_h1_timeframe?"YES":"NO"), ", EnableTrading=", (EnableTrading?"YES":"NO"),
               ", TradeActive=", (global_trade_active?"YES":"NO"));
      }
      return;
   }

   // Bereits offene Position auf Symbol? Kein weiterer Trade – sauber protokollieren
   if(PositionSelect(_Symbol))
   {
      if(EnableDebug) {
         Print("NO-TRADE REPORT: Position bereits offen auf ", _Symbol, " – kein weiterer Entry");
      }
      return;
   }
   
   if(!is_h1_timeframe) {
      Print("TRADING BLOCKIERT: ", timeframe_warning);
      return;
   }

   if((EnableTrading || global_trade_active)) {
      if(IsNightStopActive()) {
         if(EnableDebug)
            Print("NIGHT-STOP AKTIV: Blockiere neue Trades zwischen 22:00 und 06:00 Serverzeit");
         StateLog("NIGHT_STOP", "Keine Trades zwischen 22:00 und 06:00 Serverzeit");
         return;
      }

      // KRITISCHER SICHERHEITSCHECK: Konto zu klein für Symbol?
      if(account_too_small) {
         Print("TRADING BLOCKIERT: Konto zu klein für ", _Symbol, " - Min-Lot würde Risiko-Budget um >50% übersteigen!");
         return;
      }
      
      double market_price = (final_signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(market_price <= 0.0)
         market_price = close;

      // ===== TRADE DEBUG (nur wenn EnableDebug aktiv) =====
      if(EnableDebug) {
         Print("===== TRADE DEBUG (H1 ONLY) =====");
         Print("Final Signal: ", final_signal);
         Print("Calculated Lot: ", DoubleToString(lot, 6));
         Print("TP Price: ", DoubleToString(tp_price, 5));
         Print("SL Price: ", DoubleToString(sl_price, 5));
         Print("Current Price (bar close): ", DoubleToString(close, 5));
         Print("Execution Price (live): ", DoubleToString(market_price, 5));
         Print("BreakRevert Signal: ", raw_logic_signal != 0 ? "YES" : "NO");
         Print("Signal Source: ", rule_signal != 0 ? "Rules" : "BreakRevert");
         Print("H1 Trading Check: ", is_h1_timeframe ? "PASSED" : "BLOCKED");

         // Lot ist bereits validiert und normalisiert
         Print("Final Lot: ", DoubleToString(lot, 6));

         // ===== ORDER CONTEXT DEBUG (Stops/Spread/Margin/Session) =====
         long   stops_level   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         long   freeze_level  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
         double point         = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double spread_pts    = (ask - bid) / (point > 0 ? point : 1.0);
         double sl_dist_pts   = MathAbs((market_price - sl_price) / (point > 0 ? point : 1.0));
         double tp_dist_pts   = MathAbs((tp_price - market_price) / (point > 0 ? point : 1.0));
         double free_margin   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         double req_margin    = 0.0;
         bool   m_ok          = OrderCalcMargin(final_signal==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                               _Symbol, lot, market_price, req_margin);
         // Session check (heutiger Wochentag)
         MqlDateTime nowdt; TimeToStruct(TimeCurrent(), nowdt);
         datetime sess_start=0, sess_end=0; bool in_session=false;
         in_session = SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)nowdt.day_of_week, 0, sess_start, sess_end);

         Print("ORDER-CONTEXT: SpreadPts=", DoubleToString(spread_pts, 1),
               ", StopsLevel=", (int)stops_level, ", FreezeLevel=", (int)freeze_level,
               ", SLdist=", DoubleToString(sl_dist_pts, 1),
               ", TPdist=", DoubleToString(tp_dist_pts, 1));
         Print("MARGIN: Free=", DoubleToString(free_margin, 2),
               ", Required=", DoubleToString(req_margin, 2), " (ok=", (m_ok?"YES":"NO"), ")");
         Print("SESSION: InSession=", (in_session?"YES":"NO"));
         Print("========================");
      }
      
      if(final_signal == 1) {
         double tp_for_order = TpSwingMode ? 0.0 : tp_price;
         if(trade.Buy(lot, _Symbol, market_price, sl_price, tp_for_order, "Goldjunge v3.0 BUY (H1)")) {
         Print("GOLDJUNGE BUY ausgeführt: ", _Symbol, " ", tf_str, ", Lot=", DoubleToString(lot, 4), 
               ", TP=", DoubleToString(tp_price, 5), ", SL=", DoubleToString(sl_price, 5),
               TpSwingMode ? " (Swing Mode aktiv)" : "");
         Print("ORDER OK: Retcode=", (int)trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")",
               ", Order=", (long)trade.ResultOrder(), ", Deal=", (long)trade.ResultDeal());

         // === NEWS-SENTIMENT BEIM TRADE-START SPEICHERN ===
         trade_entry_sentiment = GetNewsSignal();
         trade_entry_time = TimeCurrent();
         Print("NEWS-SENTIMENT gespeichert: ", 
               (trade_entry_sentiment == 1 ? "BULLISH" : trade_entry_sentiment == -1 ? "BEARISH" : "NEUTRAL"),
               " für BUY-Trade");
         if(TpSwingMode)
         {
            double executed_price = trade.ResultPrice() > 0 ? trade.ResultPrice() : market_price;
            InitializeSwingState(POSITION_TYPE_BUY, executed_price, tp_price);
         }
         StateLog("ORDER_SEND", StringFormat("BUY lot=%.4f price=%.5f tp=%.5f sl=%.5f reason=%s",
                                             lot,
                                             market_price,
                                             tp_price,
                                             sl_price,
                                             trade_reason));
      } else {
            int error_code = GetLastError();
            if(EnableDebug) {
               Print("ORDER FAIL BUY: Retcode=", (int)trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")",
                     ", LastError=", error_code,
                     ", Lot=", DoubleToString(lot, 4),
                     ", Price=", DoubleToString(market_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                     ", SL=", DoubleToString(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                     ", TP=", DoubleToString(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
               Print("KEIN RETRY: Lot ", DoubleToString(lot, 4), " wird EXAKT eingehalten!");
               if(error_code == 134 || error_code == 131) {
                  Print("Grund: NICHT GENUG GELD für Lot ", DoubleToString(lot, 4));
               }
            }
         }
      } else {
         double tp_for_order = TpSwingMode ? 0.0 : tp_price;
         if(trade.Sell(lot, _Symbol, market_price, sl_price, tp_for_order, "Goldjunge v3.0 SELL (H1)")) {
         Print("GOLDJUNGE SELL ausgeführt: ", _Symbol, " ", tf_str, ", Lot=", DoubleToString(lot, 4), 
               ", TP=", DoubleToString(tp_price, 5), ", SL=", DoubleToString(sl_price, 5),
               TpSwingMode ? " (Swing Mode aktiv)" : "");
         Print("ORDER OK: Retcode=", (int)trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")",
               ", Order=", (long)trade.ResultOrder(), ", Deal=", (long)trade.ResultDeal());

         // === NEWS-SENTIMENT BEIM TRADE-START SPEICHERN ===
         trade_entry_sentiment = GetNewsSignal();
         trade_entry_time = TimeCurrent();
         Print("NEWS-SENTIMENT gespeichert: ", 
               (trade_entry_sentiment == 1 ? "BULLISH" : trade_entry_sentiment == -1 ? "BEARISH" : "NEUTRAL"),
               " für SELL-Trade");
         if(TpSwingMode)
         {
            double executed_price = trade.ResultPrice() > 0 ? trade.ResultPrice() : market_price;
            InitializeSwingState(POSITION_TYPE_SELL, executed_price, tp_price);
         }
         StateLog("ORDER_SEND", StringFormat("SELL lot=%.4f price=%.5f tp=%.5f sl=%.5f reason=%s",
                                              lot,
                                              market_price,
                                              tp_price,
                                              sl_price,
                                              trade_reason));
      } else {
            int error_code = GetLastError();
            if(EnableDebug) {
               Print("ORDER FAIL SELL: Retcode=", (int)trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")",
                     ", LastError=", error_code,
                     ", Lot=", DoubleToString(lot, 4),
                     ", Price=", DoubleToString(market_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                     ", SL=", DoubleToString(sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                     ", TP=", DoubleToString(tp_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
               Print("KEIN RETRY: Lot ", DoubleToString(lot, 4), " wird EXAKT eingehalten!");
               if(error_code == 134 || error_code == 131) {
                  Print("Grund: NICHT GENUG GELD für Lot ", DoubleToString(lot, 4));
               }
            }
         }
      }
   }
}

// Deinitialisierung
void OnDeinit(const int reason) {
   IndicatorRelease(stochastic_handle);
   IndicatorRelease(atr_handle);
   IndicatorRelease(adx_handle);
   EventKillTimer();
   
   // Quality Filter Statistiken ausgeben (Counter für interne Verwendung)
   if(quality_signals_total > 0) {
      Print("===== GOLDJUNGE v3.0 FINAL STATISTICS (DEBUG) =====");
      Print("Quality Filter Performance (Internal Counters):");
      Print("- Total BreakRevert Signals: ", IntegerToString(quality_signals_total));
      Print("- Passed Quality Filter: ", IntegerToString(quality_signals_passed), " (", DoubleToString((double)quality_signals_passed/quality_signals_total*100, 1), "%)");
      Print("- Failed ADX: ", IntegerToString(quality_filter_1_fails));
      Print("- Failed Stochastic: ", IntegerToString(quality_filter_2_fails));
      Print("- Failed Volume: ", IntegerToString(quality_filter_3_fails));
      Print("- Failed News Conflict: ", IntegerToString(quality_filter_4_fails));
      Print("- News Boost Confirms: ", IntegerToString(quality_bonus_confirms));
      Print("===== Bot gestoppt, VOLLSTÄNDIGER Export Fix funktioniert! =====");
   } else {
      Print("===== GOLDJUNGE v3.0 gestoppt =====");
   }
}
