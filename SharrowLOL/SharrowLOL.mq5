#property copyright "Hannes Kell / Shinpai-AI"
#property link      "https://shinpai.de"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>

struct RuleEntry
  {
   string   symbol;
   datetime event_time;
   bool     processed;
  };

// === ALTE PARAMETER (Einsatz/Volumen) ===
input string InpRulesFile            = "Rules-Master.txt";
input double InpStakePercent         = 100.0;   // Anteil des Kontos als Einsatz (% des Equity)

// === NEUE ATR-BASIERTE PARAMETER ===
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_H1;  // ATR Timeframe
input int    InpATRPeriod            = 20;     // ATR Periode (Kerzen)
input double InpTriggerATRPercent    = 5.0;    // Trigger: Bewegung in % des ATR (in 30 Sek)
input double InpSL_ATRMultiplier     = 2.0;    // SL: X × ATR
input double InpTrailStartATR        = 1.0;    // Trail Start: X × ATR Profit
input double InpTrailGapATR          = 1.0;    // Trail Gap: X × ATR hinter Preis

// === TIMING PARAMETER ===
input int    InpTriggerWindowSeconds = 30;     // Zeitraum zur Messung der Preisbewegung
input int    InpLeadMinutes          = 5;      // Beobachtung startet X Minuten vor Event
input int    InpGraceSeconds         = 30;     // Beobachtung endet X Sekunden nach Event

CTrade g_trade;

RuleEntry g_rules[];
int      g_active_rule_index = -1;
datetime g_last_reload       = 0;

ulong               g_ticket          = 0;
double              g_entry_price     = 0.0;
double              g_volume          = 0.0;
double              g_frozen_atr      = 0.0;   // ATR eingefroren bei Trade-Open
ENUM_POSITION_TYPE  g_type            = POSITION_TYPE_BUY;
bool                g_sl_set          = false;

datetime g_history_times[];
double   g_history_prices[];

int      g_symbol_digits = 0;
int      g_atr_handle    = INVALID_HANDLE;

int OnInit()
  {
   g_symbol_digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   if(InpStakePercent<=0.0)
     {
      Print("SharrowLOL: Einsatz-Parameter ungültig.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // ATR Indikator Handle erstellen
   g_atr_handle = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);
   if(g_atr_handle == INVALID_HANDLE)
     {
      Print("SharrowLOL: ATR Indikator konnte nicht erstellt werden!");
      return INIT_FAILED;
     }

   if(!LoadRules())
      Print("SharrowLOL: Regeln konnten nicht geladen werden – arbeite mit leerem Satz.");

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
   MaybeReloadRules();
   UpdatePriceHistory();

   ManagePosition();
   MonitorRules();
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
      int sep = StringFind(line,";");
      if(sep<0)
         continue;
      string symbol = StringSubstr(line,0,sep);
      string tstr   = StringSubstr(line,sep+1);
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
      entry.processed  = false;

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

   RemoveOldHistory(now - InpTriggerWindowSeconds - 5);
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
   if(g_active_rule_index<0)
      g_active_rule_index = FindActiveRule(now);

   if(g_active_rule_index<0)
      return;

   RuleEntry rule = g_rules[g_active_rule_index];
   datetime start_time = rule.event_time - InpLeadMinutes*60;
   datetime end_time   = rule.event_time + InpGraceSeconds;

   if(now < start_time)
      return;

   if(now > end_time)
     {
      PrintFormat("SharrowLOL: Kein Signal für %s (%s).",rule.symbol,TimeToString(rule.event_time));
      g_rules[g_active_rule_index].processed = true;
      g_active_rule_index = -1;
      return;
     }

   double price_change = 0.0;
   if(!CheckATRTrigger(price_change))
      return;

   ENUM_ORDER_TYPE order_type = (price_change >= 0.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(OpenRuleTrade(order_type, rule.event_time))
     {
      g_rules[g_active_rule_index].processed = true;
      g_active_rule_index = -1;
     }
   else
     {
      Print("SharrowLOL: Trade konnte nicht eröffnet werden, beobachte weiter.");
     }
  }

int FindActiveRule(datetime now)
  {
   int idx    = -1;
   datetime best_time = 0;
   for(int i=0;i<ArraySize(g_rules);i++)
     {
      if(g_rules[i].processed)
         continue;
      if(g_rules[i].symbol != _Symbol)
         continue;
      datetime start = g_rules[i].event_time - InpLeadMinutes*60;
      datetime end   = g_rules[i].event_time + InpGraceSeconds;
      if(now < start || now > end)
         continue;
      if(idx==-1 || g_rules[i].event_time < best_time)
        {
         idx = i;
         best_time = g_rules[i].event_time;
        }
     }
   return idx;
  }

//+------------------------------------------------------------------+
//| ATR-basierter Trigger Check                                       |
//+------------------------------------------------------------------+
bool CheckATRTrigger(double &price_change)
  {
   int size = ArraySize(g_history_times);
   if(size<2)
      return false;

   datetime now = g_history_times[size-1];
   datetime target = now - InpTriggerWindowSeconds;

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
   double trigger_threshold = current_atr * (InpTriggerATRPercent / 100.0);

   PrintFormat("SharrowLOL: ATR=%.5f, Trigger=%.5f, Change=%.5f",
               current_atr, trigger_threshold, abs_change);

   return abs_change >= trigger_threshold;
  }

bool OpenRuleTrade(ENUM_ORDER_TYPE order_type, datetime event_time)
  {
   if(PositionSelect(_Symbol))
     {
      Print("SharrowLOL: Es existiert bereits eine Position auf diesem Symbol.");
      return false;
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0.0)
      return false;

   double stake = equity * InpStakePercent/100.0;
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
      InitializePositionState(order_type,volume);
      ApplyATRStopLoss();
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
   g_sl_set       = false;
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
         g_sl_set       = (PositionGetDouble(POSITION_SL) != 0.0);

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
      g_sl_set       = false;
      return;
     }

   if(!g_sl_set)
      ApplyATRStopLoss();

   ManageATRTrailing();
  }

//+------------------------------------------------------------------+
//| ATR-basierter Stop Loss                                           |
//+------------------------------------------------------------------+
void ApplyATRStopLoss()
  {
   if(g_frozen_atr <= 0.0)
      return;

   double sl_distance = g_frozen_atr * InpSL_ATRMultiplier;

   double sl_price = (g_type==POSITION_TYPE_BUY) ? g_entry_price - sl_distance
                                                 : g_entry_price + sl_distance;
   sl_price = NormalizeDouble(sl_price, g_symbol_digits);

   if(g_trade.PositionModify(_Symbol, sl_price, 0.0))
     {
      g_sl_set = true;
      PrintFormat("SharrowLOL: ATR-SL gesetzt auf %.5f (%.1f × ATR = %.5f)",
                  sl_price, InpSL_ATRMultiplier, sl_distance);
     }
  }

//+------------------------------------------------------------------+
//| ATR-basiertes Trailing                                            |
//+------------------------------------------------------------------+
void ManageATRTrailing()
  {
   if(g_frozen_atr <= 0.0)
      return;

   double current_price = (g_type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                                      : SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // Profit in Preis-Distanz berechnen
   double profit_distance = (g_type==POSITION_TYPE_BUY) ? (current_price - g_entry_price)
                                                        : (g_entry_price - current_price);

   // Trail Start Check: Profit >= X × ATR
   double trail_start_distance = g_frozen_atr * InpTrailStartATR;
   if(profit_distance < trail_start_distance)
      return;

   // Trailing Gap: SL = aktueller Preis - X × ATR
   double trail_gap = g_frozen_atr * InpTrailGapATR;
   double desired_sl = (g_type==POSITION_TYPE_BUY) ? current_price - trail_gap
                                                   : current_price + trail_gap;
   desired_sl = NormalizeDouble(desired_sl, g_symbol_digits);

   double current_sl = PositionGetDouble(POSITION_SL);

   // Nur nachziehen, nie zurücksetzen
   if(g_type==POSITION_TYPE_BUY && desired_sl <= current_sl)
      return;
   if(g_type==POSITION_TYPE_SELL && desired_sl >= current_sl && current_sl != 0.0)
      return;

   if(g_trade.PositionModify(_Symbol, desired_sl, PositionGetDouble(POSITION_TP)))
     {
      PrintFormat("SharrowLOL: ATR-Trail SL auf %.5f (Profit: %.5f, Gap: %.5f)",
                  desired_sl, profit_distance, trail_gap);
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
