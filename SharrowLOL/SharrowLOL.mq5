#property copyright "Hannes Kell / Shinpai-AI"
#property link      "https://shinpai.de"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>

struct RuleEntry
  {
   string   symbol;
   datetime event_time;
   bool     pre_processed;
   bool     event_processed;
   int      pre_trigger_percent;
   int      pre_watch_seconds;
   int      close_before_seconds;
   double   pre_tp_atr;
   double   pre_sl_atr;
   int      event_trigger_percent;
   int      event_watch_seconds;
   double   event_tp_atr;
   double   event_sl_atr;
  };

input string InpRulesFile            = "Rules-Master.txt"; // Rules-Datei

// === EINSATZ & ENTRY ==================================================
enum ENUM_STAKE_MODE
  {
   STAKE_PERCENT = 0,   // % vom Konto
   STAKE_FIXED   = 1    // fixer Wert
  };
input ENUM_STAKE_MODE InpStakeMode   = STAKE_PERCENT; // Einsatz Berechnung
input double InpStakePercent         = 100.0;         // Einsatz in % vom Konto (1-100)
input double InpStakeFixed           = 0.0;           // Fixer Einsatz (0-X)

// === BOT PARAMETER ====================================================
input ENUM_TIMEFRAMES InpTradeTimeframe = PERIOD_H1;  // Timeframe
input int    InpATRPeriod               = 20;         // ATR Periode (Kerzen)
input double InpTriggerATRPercent       = 10.0;       // Einstiegs-Trigger in % bei ATR-Move
input int    InpLeadMinutes             = 0;          // Zeit in Minuten vor dem Event checken
input int    InpEventWatchSeconds       = 30;         // Überwachungzeitraum des Events in Sekunden

// === TP/SL - TRAILING =================================================
input bool   InpTrailingEnabled         = true;       // Trailing ON/OFF
input double InpTrailingTP_ATR          = 1.0;        // TP in ATR vor aktuellem Kurs
input double InpTrailingSL_ATR          = 1.0;        // SL in ATR hinter dem aktuellen Kurs

// === SHARROW EXIT =====================================================
input double InpExitATRThreshold        = 0.5;        // Überwachte ATR (0-X)
input int    InpExitWatchSeconds        = 10;         // Überwachungsdauer in Sekunden (0-X)
input double InpExitMinProfit           = 0.01;       // Mindest Profit in EUR (0-X)

// === WEBTICKER ========================================================
input bool   InpEnableWebTicker      = false;  // WebTicker aktivieren (ON/OFF)
input string InpStateLogFile         = "Goldjunge-state.log";  // WebTicker Log-Datei
input int    InpSnapshotIntervalMin  = 60;     // Snapshot-Intervall in Minuten

CTrade g_trade;

// === RULE DEFAULTS (wenn in Rules-Master nicht gesetzt) ===
const int    DEFAULT_PRE_TRIGGER_PERCENT   = 40;   // z.B. 30-60
const int    DEFAULT_PRE_WATCH_SECONDS     = 600;  // 10m
const int    DEFAULT_CLOSE_BEFORE_SECONDS  = 60;   // 1m vor Event schließen
const double DEFAULT_PRE_TP_ATR            = 0.3;
const double DEFAULT_PRE_SL_ATR            = 0.5;

RuleEntry g_rules[];
int      g_active_rule_index = -1;
datetime g_last_reload       = 0;

ulong               g_ticket          = 0;
double              g_entry_price     = 0.0;
double              g_volume          = 0.0;
double              g_frozen_atr      = 0.0;   // ATR eingefroren bei Trade-Open
ENUM_POSITION_TYPE  g_type            = POSITION_TYPE_BUY;
bool                g_tf_warned       = false;
int                 g_trade_phase     = 0;     // 0=none, 1=pre, 2=event
datetime            g_active_event_time = 0;
int                 g_close_before_seconds = 0;
double              g_trailing_tp_atr = 1.0;
double              g_trailing_sl_atr = 1.0;

// === SHARROW EXIT STATE ===
bool                g_exit_monitor_active = false;
bool                g_exit_waiting_min    = false;
datetime            g_exit_start_time     = 0;
double              g_exit_max_favor_move = 0.0;

datetime g_history_times[];
double   g_history_prices[];

int      g_symbol_digits = 0;
int      g_atr_handle    = INVALID_HANDLE;

// === WEBTICKER STATE ===
datetime g_last_snapshot   = 0;
ulong    g_last_closed_ticket = 0;

int OnInit()
  {
   g_symbol_digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   if(InpStakeMode==STAKE_PERCENT && (InpStakePercent<=0.0 || InpStakePercent>100.0))
     {
      Print("SharrowLOL: Einsatz-Parameter ungültig.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpStakeMode==STAKE_FIXED && InpStakeFixed<0.0)
     {
      Print("SharrowLOL: Fixer Einsatz ungültig.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // ATR Indikator Handle erstellen
   g_atr_handle = iATR(_Symbol, InpTradeTimeframe, InpATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
     {
      Print("SharrowLOL: ATR Indikator konnte nicht erstellt werden!");
      return INIT_FAILED;
     }

   if(!LoadRules())
      Print("SharrowLOL: Regeln konnten nicht geladen werden – arbeite mit leerem Satz.");

   // Initialer WebTicker Snapshot
   if(InpEnableWebTicker && InpStateLogFile != "")
     {
      WriteWebTickerSnapshot();
      Print("SharrowLOL: WebTicker Logging aktiviert -> ", InpStateLogFile);
     }
   else
     {
      Print("SharrowLOL: WebTicker Logging DEAKTIVIERT (InpEnableWebTicker=false)");
     }

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   ArrayFree(g_rules);
   ArrayFree(g_history_times);
   ArrayFree(g_history_prices);
  }

void OnTick()
  {
   if(_Period != InpTradeTimeframe)
     {
      if(!g_tf_warned)
        {
         PrintFormat("SharrowLOL: Falscher Timeframe. Erwartet %s, aktuell %s.",
                     EnumToString(InpTradeTimeframe), EnumToString((ENUM_TIMEFRAMES)_Period));
         g_tf_warned = true;
        }
      return;
     }

   MaybeReloadRules();
   UpdatePriceHistory();

   ManagePosition();
   MonitorRules();

   // WebTicker Logging
   MaybeWriteSnapshot();
   CheckClosedTrades();
  }

//+------------------------------------------------------------------+
//| ATR Wert abrufen                                                  |
//+------------------------------------------------------------------+
double GetCurrentATR()
  {
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);

   if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) <= 0)
     {
      Print("SharrowLOL: ATR konnte nicht gelesen werden!");
      return 0.0;
     }

   return atr_buffer[0];
  }

void MaybeReloadRules()
  {
   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now,tm);
   if(tm.day_of_week!=0)
      return;
   if(tm.hour!=16 && tm.hour!=23)
      return;
   if(now - g_last_reload < 3600)
      return;
   if(LoadRules())
      Print("SharrowLOL: Rules nach Zeitplan neu geladen.");
  }

bool LoadRules()
  {
   ArrayFree(g_rules);
   int handle = FileOpen(InpRulesFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("SharrowLOL: Rules-Datei %s nicht gefunden.",InpRulesFile);
      return false;
     }

   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      PrintFormat("SharrowLOL: Rohzeile \"%s\"",line);
      if(StringLen(line)==0)
         continue;
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line=="")
         continue;
      string parts[];
      int pcount = StringSplit(line,';',parts);
      if(pcount<2)
         continue;
      string symbol = parts[0];
      string tstr   = parts[1];
      datetime dt;
      if(symbol=="")
        {
         PrintFormat("SharrowLOL: Ignoriere Zeile \"%s\" – leeres Symbol.",line);
         continue;
        }
      if(!ParseRuleTime(tstr,dt))
        {
         PrintFormat("SharrowLOL: Ignoriere Zeile \"%s\" – Zeit nicht lesbar.",line);
         continue;
        }

      RuleEntry entry;
      entry.symbol     = symbol;
      entry.event_time = dt;
      ApplyRuleDefaults(entry);

      for(int i=2;i<pcount;i++)
        {
         string kv = parts[i];
         StringTrimLeft(kv);
         StringTrimRight(kv);
         if(kv=="")
            continue;
         int eq = StringFind(kv,"=");
         if(eq<0)
            continue;
         string key = StringSubstr(kv,0,eq);
         string val = StringSubstr(kv,eq+1);
         ApplyRuleParam(entry,key,val);
        }

      int idx = ArraySize(g_rules);
      ArrayResize(g_rules,idx+1);
      g_rules[idx] = entry;
     }

   FileClose(handle);
   g_last_reload = TimeCurrent();

   PrintFormat("SharrowLOL: %d Rules geladen.",ArraySize(g_rules));
  return true;
  }

void UpdatePriceHistory()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;

   datetime now = (tick.time>0) ? tick.time : TimeCurrent();
   double price = (tick.bid+tick.ask)/2.0;

   int size = ArraySize(g_history_times);
   ArrayResize(g_history_times,size+1);
   ArrayResize(g_history_prices,size+1);
   g_history_times[size]  = now;
   g_history_prices[size] = price;

   int max_window = InpEventWatchSeconds;
   for(int i=0;i<ArraySize(g_rules);i++)
     {
      if(g_rules[i].symbol != _Symbol)
         continue;
      if(g_rules[i].pre_watch_seconds > max_window)
         max_window = g_rules[i].pre_watch_seconds;
      if(g_rules[i].event_watch_seconds > max_window)
         max_window = g_rules[i].event_watch_seconds;
     }
   RemoveOldHistory(now - max_window - 5);
  }

void RemoveOldHistory(datetime min_time)
  {
   int size = ArraySize(g_history_times);
   int start = 0;
   while(start<size && g_history_times[start]<min_time)
      start++;
   if(start<=0 || start>=size)
      return;

   int new_size = size-start;
   for(int i=0;i<new_size;i++)
     {
      g_history_times[i]  = g_history_times[start+i];
      g_history_prices[i] = g_history_prices[start+i];
     }
   ArrayResize(g_history_times,new_size);
   ArrayResize(g_history_prices,new_size);
  }

void MonitorRules()
  {
   datetime now = TimeCurrent();
   for(int i=0;i<ArraySize(g_rules);i++)
     {
      if(g_rules[i].symbol != _Symbol)
         continue;
      if(g_rules[i].pre_processed && g_rules[i].event_processed)
         continue;

      RuleEntry rule = g_rules[i];
      int lead_sec = InpLeadMinutes * 60;
      int pre_window = rule.pre_watch_seconds;
      int pre_span = MathMax(lead_sec, pre_window);
      datetime pre_start = rule.event_time - pre_span;
      datetime pre_end   = rule.event_time - rule.close_before_seconds;
      if(pre_end < pre_start)
         pre_end = pre_start;
      datetime event_start = rule.event_time;
      datetime event_end   = rule.event_time + rule.event_watch_seconds;

      // Pre-Event Phase
      if(!rule.pre_processed)
        {
         if(now > pre_end)
           {
            g_rules[i].pre_processed = true;
           }
         else if(now >= pre_start)
           {
            if(!PositionSelect(_Symbol))
              {
               double price_change = 0.0;
               if(CheckATRTrigger(price_change, rule.pre_trigger_percent, rule.pre_watch_seconds))
                 {
                  ENUM_ORDER_TYPE order_type = (price_change >= 0.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                  if(OpenRuleTrade(order_type, rule.event_time, 1, rule.pre_tp_atr, rule.pre_sl_atr, rule.close_before_seconds))
                     g_rules[i].pre_processed = true;
                 }
              }
           }
        }

      // Event Phase
      if(!rule.event_processed)
        {
         if(now > event_end)
           {
            g_rules[i].event_processed = true;
           }
         else if(now >= event_start)
           {
            if(!PositionSelect(_Symbol))
              {
               double price_change = 0.0;
               if(CheckATRTrigger(price_change, rule.event_trigger_percent, rule.event_watch_seconds))
                 {
                  ENUM_ORDER_TYPE order_type = (price_change >= 0.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                  if(OpenRuleTrade(order_type, rule.event_time, 2, rule.event_tp_atr, rule.event_sl_atr, 0))
                     g_rules[i].event_processed = true;
                 }
              }
           }
        }
     }
  }

int FindActiveRule(datetime now)
  {
   return -1;
  }

//+------------------------------------------------------------------+
//| ATR-basierter Trigger Check                                       |
//+------------------------------------------------------------------+
bool CheckATRTrigger(double &price_change, int trigger_percent, int window_seconds)
  {
   int size = ArraySize(g_history_times);
   if(size<2)
      return false;

   datetime now = g_history_times[size-1];
   datetime target = now - window_seconds;

   int idx = -1;
   for(int i=size-2;i>=0;i--)
     {
      if(g_history_times[i]<=target)
        {
         idx = i;
         break;
        }
     }

   if(idx<0)
      return false;

   double price_now  = g_history_prices[size-1];
   double price_then = g_history_prices[idx];
   if(price_then<=0.0)
      return false;

   // Preisänderung berechnen
   price_change = price_now - price_then;
   double abs_change = MathAbs(price_change);

   // ATR abrufen
   double current_atr = GetCurrentATR();
   if(current_atr <= 0.0)
      return false;

   // Trigger: Bewegung >= X% des ATR
   double trigger_threshold = current_atr * (trigger_percent / 100.0);

   PrintFormat("SharrowLOL: ATR=%.5f, Trigger=%.5f, Change=%.5f",
               current_atr, trigger_threshold, abs_change);

   return abs_change >= trigger_threshold;
  }

bool OpenRuleTrade(ENUM_ORDER_TYPE order_type, datetime event_time, int phase, double tp_atr, double sl_atr, int close_before_seconds)
  {
   if(PositionSelect(_Symbol))
     {
      Print("SharrowLOL: Es existiert bereits eine Position auf diesem Symbol.");
      return false;
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0.0)
      return false;

   double stake = 0.0;
   if(InpStakeMode==STAKE_FIXED)
      stake = InpStakeFixed;
   else
      stake = equity * InpStakePercent/100.0;
   if(stake<=0.0)
      return false;

   double price = (order_type==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0.0)
      return false;

   double volume = VolumeForStake(order_type,stake,price);
   if(volume<=0.0)
     {
      Print("SharrowLOL: Volumenberechnung fehlgeschlagen.");
      return false;
     }

   // ATR einfrieren für diesen Trade
   g_frozen_atr = GetCurrentATR();
   if(g_frozen_atr <= 0.0)
     {
      Print("SharrowLOL: ATR konnte nicht eingefroren werden!");
      return false;
     }

   double sl=0.0, tp=0.0;
   if(g_trade.PositionOpen(_Symbol,order_type,volume,price,sl,tp))
     {
      PrintFormat("SharrowLOL: Trade eröffnet (%s, %.2f Lots) nach Rule %s. ATR=%.5f",
                  EnumToString(order_type),volume,TimeToString(event_time),g_frozen_atr);
      g_trade_phase          = phase;
      g_active_event_time    = event_time;
      g_close_before_seconds = close_before_seconds;
      g_trailing_tp_atr      = tp_atr;
      g_trailing_sl_atr      = sl_atr;
      InitializePositionState(order_type,volume);
      if(phase==2)
        {
         g_exit_monitor_active = true;
         g_exit_waiting_min    = false;
         g_exit_start_time     = TimeCurrent();
         g_exit_max_favor_move = 0.0;
        }
      return true;
     }

   int err = GetLastError();
   PrintFormat("SharrowLOL: PositionOpen fehlgeschlagen (%d).",err);
   return false;
  }

double VolumeForStake(ENUM_ORDER_TYPE order_type,double stake,double price)
  {
   double min_lot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0)
      step=0.01;

   double margin_per_lot=0.0;
   if(!OrderCalcMargin(order_type,_Symbol,1.0,price,margin_per_lot) || margin_per_lot<=0.0)
      return min_lot;

   double volume = stake / margin_per_lot;
   if(volume<min_lot)
      volume = min_lot;
   if(volume>max_lot)
      volume = max_lot;

   double steps = MathFloor(volume/step);
   volume = steps*step;
   volume = MathMax(volume,min_lot);
   volume = MathMin(volume,max_lot);

   int vol_digits = 0;
   double tmp_step = step;
   if(tmp_step<=0.0)
      tmp_step = 0.01;
   while(tmp_step < 1.0 && vol_digits < 8)
     {
      tmp_step *= 10.0;
      vol_digits++;
     }

   return NormalizeDouble(volume,vol_digits);
  }

void InitializePositionState(ENUM_ORDER_TYPE order_type, double volume)
  {
   if(!PositionSelect(_Symbol))
      return;
   g_ticket       = (ulong)PositionGetInteger(POSITION_TICKET);
   g_entry_price  = PositionGetDouble(POSITION_PRICE_OPEN);
   g_volume       = volume;
   g_type         = (order_type==ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
  }

void ManagePosition()
  {
   if(g_ticket==0)
     {
      if(PositionSelect(_Symbol))
        {
         g_ticket       = (ulong)PositionGetInteger(POSITION_TICKET);
         g_entry_price  = PositionGetDouble(POSITION_PRICE_OPEN);
         g_volume       = PositionGetDouble(POSITION_VOLUME);
         g_type         = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         g_tf_warned    = false;

         // Falls ATR nicht eingefroren, jetzt holen
         if(g_frozen_atr <= 0.0)
           {
            g_frozen_atr = GetCurrentATR();
            PrintFormat("SharrowLOL: ATR nachträglich eingefroren: %.5f", g_frozen_atr);
           }
        }
      return;
     }

   if(!PositionSelectByTicket((long)g_ticket))
     {
      g_ticket       = 0;
      g_entry_price  = 0.0;
      g_volume       = 0.0;
      g_frozen_atr   = 0.0;
      g_trade_phase          = 0;
      g_active_event_time    = 0;
      g_close_before_seconds = 0;
      g_exit_monitor_active  = false;
      g_exit_waiting_min     = false;
      g_exit_start_time      = 0;
      g_exit_max_favor_move  = 0.0;
      return;
     }

   // Pre-Event: Position vor Event schließen
   if(g_trade_phase==1 && g_active_event_time>0 && g_close_before_seconds>0)
     {
      datetime close_time = g_active_event_time - g_close_before_seconds;
      if(TimeCurrent() >= close_time)
        {
         if(g_trade.PositionClose(_Symbol))
           {
           g_trade_phase          = 0;
           g_active_event_time    = 0;
           g_close_before_seconds = 0;
           g_exit_monitor_active  = false;
           g_exit_waiting_min     = false;
           g_exit_start_time      = 0;
           g_exit_max_favor_move  = 0.0;
           return;
          }
       }
     }

   // Sharrow Exit (nur Event-Phase)
   if(g_trade_phase==2)
      ManageSharrowExit();

   // Trailing-System auswählen
   if(InpTrailingEnabled)
      ManageUnlimitedTrailing();
  }

//+------------------------------------------------------------------+
//| SHARROW EXIT: Event-Trade überwachen                             |
//+------------------------------------------------------------------+
void ManageSharrowExit()
  {
   if(InpExitWatchSeconds <= 0 || InpExitATRThreshold <= 0.0)
      return;
   if(g_frozen_atr <= 0.0)
      return;

   // Monitor starten, wenn noch nicht aktiv
   if(!g_exit_monitor_active)
     {
      g_exit_monitor_active = true;
      g_exit_waiting_min    = false;
      g_exit_start_time     = TimeCurrent();
      g_exit_max_favor_move = 0.0;
     }

   // Aktueller Preis für Favor-Move
   double current_price = (g_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                      : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(current_price <= 0.0)
      return;

   double favor_move = 0.0;
   if(g_type == POSITION_TYPE_BUY)
      favor_move = current_price - g_entry_price;
   else
      favor_move = g_entry_price - current_price;

   if(favor_move > g_exit_max_favor_move)
      g_exit_max_favor_move = favor_move;

   int elapsed = (int)(TimeCurrent() - g_exit_start_time);
   double needed_move = g_frozen_atr * InpExitATRThreshold;

   // Wenn Zeitfenster abgelaufen und Ziel-ATR nicht erreicht -> Exit-Prüfung
   if(elapsed >= InpExitWatchSeconds && g_exit_max_favor_move < needed_move)
     {
      g_exit_waiting_min = true;
     }

   if(g_exit_waiting_min)
     {
      double current_profit = PositionGetDouble(POSITION_PROFIT);
      if(current_profit >= InpExitMinProfit)
        {
         if(g_trade.PositionClose(_Symbol))
           {
            PrintFormat("SharrowLOL: SharrowExit geschlossen (Profit %.2f EUR, MaxMove %.5f, Need %.5f).",
                        current_profit, g_exit_max_favor_move, needed_move);
            g_exit_monitor_active = false;
            g_exit_waiting_min    = false;
            g_exit_start_time     = 0;
            g_exit_max_favor_move = 0.0;
           }
         else
           {
            int err = GetLastError();
            PrintFormat("SharrowLOL: SharrowExit Close FEHLER (%d).", err);
           }
        }
     }
   else
     {
      // Erfolg -> Monitoring beenden
      if(elapsed >= InpExitWatchSeconds && g_exit_max_favor_move >= needed_move)
        {
         g_exit_monitor_active = false;
         g_exit_waiting_min    = false;
        }
     }
  }

//+------------------------------------------------------------------+
//| UNLIMITED-TRAILING: TP und SL wandern mit dem Kurs               |
//+------------------------------------------------------------------+
void ManageUnlimitedTrailing()
  {
   if(g_frozen_atr <= 0.0)
      return;

   double current_price = (g_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                      : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(current_price <= 0.0)
      return;

   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);

   // Berechne gewünschte Werte
   double sl_distance = g_frozen_atr * g_trailing_sl_atr;
   double tp_distance = g_frozen_atr * g_trailing_tp_atr;

   double desired_sl, desired_tp;

   if(g_type == POSITION_TYPE_BUY)
     {
      desired_sl = current_price - sl_distance;
      desired_tp = current_price + tp_distance;
     }
   else // SELL
     {
      desired_sl = current_price + sl_distance;
      desired_tp = current_price - tp_distance;
     }

   desired_sl = NormalizeDouble(desired_sl, g_symbol_digits);
   desired_tp = NormalizeDouble(desired_tp, g_symbol_digits);

   // SL: Nur NACHZIEHEN (nie zurücksetzen!)
   bool sl_update_needed = false;
   if(g_type == POSITION_TYPE_BUY)
     {
      if(desired_sl > current_sl || current_sl == 0.0)
         sl_update_needed = true;
      else
         desired_sl = current_sl; // Behalte alten SL
     }
   else // SELL
     {
      if(desired_sl < current_sl || current_sl == 0.0)
         sl_update_needed = true;
      else
         desired_sl = current_sl; // Behalte alten SL
     }

   // TP: Bewegt sich IMMER mit dem Kurs (beide Richtungen)
   bool tp_update_needed = (MathAbs(desired_tp - current_tp) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);

   // Nur modifizieren wenn nötig (vermeidet unnötige API-Calls)
   if(!sl_update_needed && !tp_update_needed)
      return;

   if(g_trade.PositionModify(_Symbol, desired_sl, desired_tp))
     {
      if(sl_update_needed)
         PrintFormat("SharrowLOL: Unlimited-Trail SL=%.5f TP=%.5f (Preis=%.5f, ATR=%.5f)",
                     desired_sl, desired_tp, current_price, g_frozen_atr);
     }
  }

bool ParseRuleTime(string raw,datetime &result)
  {
   string norm = raw;
   StringTrimLeft(norm);
   StringTrimRight(norm);
   StringReplace(norm,"/","-");
   StringReplace(norm,".","-");
   // Erwartet Format YYYY-MM-DD HH:MM[:SS]
   string parts[];
   int count = StringSplit(norm,' ',parts);
   if(count<2)
      return false;

   string date_part = parts[0];
   string time_part = parts[1];

   string date_tokens[];
   if(StringSplit(date_part,'-',date_tokens)!=3)
      return false;

   string time_tokens[];
   int tcount = StringSplit(time_part,':',time_tokens);
   if(tcount<2)
      return false;

   MqlDateTime tm;
   tm.year  = (int)StringToInteger(date_tokens[0]);
   tm.mon   = (int)StringToInteger(date_tokens[1]);
   tm.day   = (int)StringToInteger(date_tokens[2]);
   tm.hour  = (int)StringToInteger(time_tokens[0]);
   tm.min   = (int)StringToInteger(time_tokens[1]);
   tm.sec   = (tcount>=3) ? (int)StringToInteger(time_tokens[2]) : 0;

   if(tm.year<1970 || tm.mon<1 || tm.day<1)
      return false;

   datetime dt = StructToTime(tm);
   if(dt<=0)
      return false;
   result = dt;
   return true;
  }

int ParseDurationSeconds(string raw, int fallback_seconds)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s)==0)
      return fallback_seconds;

   int len = StringLen(s);
   string last = StringSubstr(s, len-1, 1);
   int mult = 1;
   if(last=="s" || last=="S")
     {
      mult = 1;
      s = StringSubstr(s, 0, len-1);
     }
   else if(last=="m" || last=="M")
     {
      mult = 60;
      s = StringSubstr(s, 0, len-1);
     }
   else if(last=="h" || last=="H")
     {
      mult = 3600;
      s = StringSubstr(s, 0, len-1);
     }

   int val = (int)StringToInteger(s);
   if(val<=0)
      return fallback_seconds;
   return val * mult;
  }

void ApplyRuleDefaults(RuleEntry &entry)
  {
   entry.pre_processed        = false;
   entry.event_processed      = false;
   entry.pre_trigger_percent  = DEFAULT_PRE_TRIGGER_PERCENT;
   entry.pre_watch_seconds    = DEFAULT_PRE_WATCH_SECONDS;
   entry.close_before_seconds = DEFAULT_CLOSE_BEFORE_SECONDS;
   entry.pre_tp_atr           = DEFAULT_PRE_TP_ATR;
   entry.pre_sl_atr           = DEFAULT_PRE_SL_ATR;
   entry.event_trigger_percent= (int)InpTriggerATRPercent;
   entry.event_watch_seconds  = InpEventWatchSeconds;
   entry.event_tp_atr         = InpTrailingTP_ATR;
   entry.event_sl_atr         = InpTrailingSL_ATR;
  }

void ApplyRuleParam(RuleEntry &entry, string key, string val)
  {
   string k = key;
   StringToLower(k);
   StringTrimLeft(k);
   StringTrimRight(k);
   StringTrimLeft(val);
   StringTrimRight(val);

   if(k=="pre_trigger" || k=="pre_trig")
      entry.pre_trigger_percent = (int)StringToInteger(val);
   else if(k=="pre_watch" || k=="pre_window")
      entry.pre_watch_seconds = ParseDurationSeconds(val, entry.pre_watch_seconds);
   else if(k=="close_before")
      entry.close_before_seconds = ParseDurationSeconds(val, entry.close_before_seconds);
   else if(k=="pre_tp_atr")
      entry.pre_tp_atr = StringToDouble(val);
   else if(k=="pre_sl_atr")
      entry.pre_sl_atr = StringToDouble(val);
   else if(k=="event_trigger" || k=="event_trig")
      entry.event_trigger_percent = (int)StringToInteger(val);
   else if(k=="event_watch" || k=="event_window")
      entry.event_watch_seconds = ParseDurationSeconds(val, entry.event_watch_seconds);
   else if(k=="event_tp_atr")
      entry.event_tp_atr = StringToDouble(val);
   else if(k=="event_sl_atr")
      entry.event_sl_atr = StringToDouble(val);
  }

//+------------------------------------------------------------------+
//| WEBTICKER LOGGING FUNKTIONEN                                      |
//+------------------------------------------------------------------+

string FormatISOTimestamp(datetime dt)
  {
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                       tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
  }

string FormatLogTimestamp(datetime dt)
  {
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   return StringFormat("[%04d.%02d.%02d %02d:%02d:%02d]",
                       tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
  }

void WriteWebTickerSnapshot()
  {
   if(!InpEnableWebTicker || InpStateLogFile == "")
      return;

   datetime now = TimeCurrent();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floating = equity - balance;

   string json = StringFormat(
      "{\"type\":\"snapshot\",\"timestamp\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"floating\":%.2f}",
      FormatISOTimestamp(now), balance, equity, floating);

   string line = FormatLogTimestamp(now) + " [WEB_TICKER] " + json;

   int handle = FileOpen(InpStateLogFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
     }

   g_last_snapshot = now;
  }

void WriteWebTickerTrade(ulong ticket, string symbol, double volume, double profit,
                         string order_type, datetime opened_at, datetime closed_at, string exit_reason)
  {
   if(!InpEnableWebTicker || InpStateLogFile == "")
      return;

   datetime now = TimeCurrent();

   string json = StringFormat(
      "{\"type\":\"trade\",\"ticket\":\"%d\",\"symbol\":\"%s\",\"volume\":%.2f,\"profit\":%.2f,\"order_type\":\"%s\",\"opened_at\":\"%s\",\"closed_at\":\"%s\",\"exit_reason\":\"%s\",\"comment\":\"SharrowLOL\"}",
      ticket, symbol, volume, profit, order_type,
      FormatISOTimestamp(opened_at), FormatISOTimestamp(closed_at), exit_reason);

   string line = FormatLogTimestamp(now) + " [WEB_TICKER] " + json;

   int handle = FileOpen(InpStateLogFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
      PrintFormat("SharrowLOL: WebTicker Trade geloggt - Ticket %d, Profit %.2f", ticket, profit);
     }
  }

void MaybeWriteSnapshot()
  {
   if(!InpEnableWebTicker || InpSnapshotIntervalMin <= 0)
      return;

   datetime now = TimeCurrent();
   if(now - g_last_snapshot >= InpSnapshotIntervalMin * 60)
     {
      WriteWebTickerSnapshot();
     }
  }

void CheckClosedTrades()
  {
   if(!InpEnableWebTicker)
      return;

   // Hole die letzten Deals aus der History
   datetime from_time = TimeCurrent() - 300; // Letzte 5 Minuten
   datetime to_time = TimeCurrent();

   if(!HistorySelect(from_time, to_time))
      return;

   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;

      // Nur Exit-Deals (DEAL_ENTRY_OUT)
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT)
         continue;

      // Schon geloggt?
      if(deal_ticket <= g_last_closed_ticket)
         continue;

      string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);

      // Position Ticket für Open-Zeit
      ulong pos_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      datetime opened_at = deal_time - 3600; // Fallback: 1h vorher

      // Versuche echte Open-Zeit zu finden
      if(HistorySelectByPosition(pos_ticket))
        {
         int pos_deals = HistoryDealsTotal();
         for(int j = 0; j < pos_deals; j++)
           {
            ulong pos_deal = HistoryDealGetTicket(j);
            if(pos_deal == 0) continue;
            ENUM_DEAL_ENTRY pos_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(pos_deal, DEAL_ENTRY);
            if(pos_entry == DEAL_ENTRY_IN)
              {
               opened_at = (datetime)HistoryDealGetInteger(pos_deal, DEAL_TIME);
               break;
              }
           }
        }

      // Order Type bestimmen (umgekehrt weil Exit)
      string order_type = (deal_type == DEAL_TYPE_SELL) ? "BUY" : "SELL";

      // Exit Reason
      string exit_reason = "manual";
      if(reason == DEAL_REASON_SL)
         exit_reason = "sl";
      else if(reason == DEAL_REASON_TP)
         exit_reason = "tp";

      WriteWebTickerTrade(deal_ticket, symbol, volume, profit, order_type, opened_at, deal_time, exit_reason);
      g_last_closed_ticket = deal_ticket;

      // Auch Snapshot nach Trade schreiben
      WriteWebTickerSnapshot();
     }
  }
