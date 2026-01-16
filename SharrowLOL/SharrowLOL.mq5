#property copyright "Hannes Kell / Shinpai-AI"
#property link      "https://shinpai.de"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

struct RuleEntry
  {
   string   symbol;
   datetime event_time;
   bool     processed;
  };

input string InpRulesFile            = "Rules-Master.txt";
input double InpStakePercent         = 80.0;   // Anteil des Kontos als Einsatz (% des Equity)
input double InpRiskPercent          = 10.0;   // Verlustlimit in % des Einsatzes (SL)
input double InpTakeProfitPercent    = 0.0;    // Fester TP in % des Einsatzes (0 = swing)
input double InpTrailStartPercent    = 3.0;    // Profit in % des Einsatzes für Trailing-Start
input double InpTrailGapPercent      = 2.0;    // Abstand (in %-Punkten) zwischen Profit und SL
input double InpTriggerPercent       = 1.0;    // Preisänderung (in %) innerhalb des Fensters
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
double              g_stake_amount    = 0.0;
ENUM_POSITION_TYPE  g_type            = POSITION_TYPE_BUY;
bool                g_protection_done = false;

datetime g_history_times[];
double   g_history_prices[];

int      g_symbol_digits = 0;

int OnInit()
  {
   g_symbol_digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   if(InpRiskPercent<=0.0 || InpStakePercent<=0.0)
     {
      Print("SharrowLOL: Einsatz- oder Risiko-Parameter ungültig.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!LoadRules())
      Print("SharrowLOL: Regeln konnten nicht geladen werden – arbeite mit leerem Satz.");

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
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

   double change_pct=0.0;
   if(!CheckTrigger(change_pct))
      return;

   ENUM_ORDER_TYPE order_type = (change_pct>=0.0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(OpenRuleTrade(order_type,rule.event_time))
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

bool CheckTrigger(double &change_pct)
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

   change_pct = (price_now - price_then)/price_then * 100.0;
   return MathAbs(change_pct) >= InpTriggerPercent;
  }

bool OpenRuleTrade(ENUM_ORDER_TYPE order_type,datetime event_time)
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

   double sl=0.0,tp=0.0;
   if(g_trade.PositionOpen(_Symbol,order_type,volume,price,sl,tp))
     {
      PrintFormat("SharrowLOL: Trade eröffnet (%s, %.2f Lots) nach Rule %s.",
                  EnumToString(order_type),volume,TimeToString(event_time));
      InitializePositionState(order_type,volume,stake);
      ApplyInitialProtection();
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

void InitializePositionState(ENUM_ORDER_TYPE order_type,double volume,double stake)
  {
   if(!PositionSelect(_Symbol))
      return;
   g_ticket       = (ulong)PositionGetInteger(POSITION_TICKET);
   g_entry_price  = PositionGetDouble(POSITION_PRICE_OPEN);
   g_volume       = volume;
   g_type         = (order_type==ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   g_stake_amount = stake;
   g_protection_done = false;
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
         g_stake_amount = AccountInfoDouble(ACCOUNT_EQUITY)*InpStakePercent/100.0;
         g_protection_done = false;
        }
      return;
     }

   if(!PositionSelectByTicket((long)g_ticket))
     {
      g_ticket          = 0;
      g_entry_price     = 0.0;
      g_volume          = 0.0;
      g_stake_amount    = 0.0;
      g_protection_done = false;
      return;
     }

   if(!g_protection_done)
      ApplyInitialProtection();
   ManageTrailing();
  }

double MoneyToPriceDistance(double amount,double volume)
  {
   if(amount<=0.0 || volume<=0.0)
      return 0.0;
   double tick_value = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tick_value<=0.0)
      tick_value = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick_value<=0.0 || tick_size<=0.0)
      return 0.0;

   double ticks = amount/(tick_value*volume);
   return ticks*tick_size;
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

void ApplyInitialProtection()
  {
   if(g_volume<=0.0 || g_stake_amount<=0.0)
      return;

   double risk_amount = g_stake_amount*InpRiskPercent/100.0;
   double sl_distance = MoneyToPriceDistance(risk_amount,g_volume);
   if(sl_distance<=0.0)
      return;

   double sl_price = (g_type==POSITION_TYPE_BUY) ? g_entry_price - sl_distance
                                                 : g_entry_price + sl_distance;
   sl_price = NormalizeDouble(sl_price,g_symbol_digits);

   double tp_price = 0.0;
   if(InpTakeProfitPercent>0.0)
     {
      double tp_amount = g_stake_amount*InpTakeProfitPercent/100.0;
      double tp_distance = MoneyToPriceDistance(tp_amount,g_volume);
      if(tp_distance>0.0)
        {
         tp_price = (g_type==POSITION_TYPE_BUY) ? g_entry_price + tp_distance
                                                : g_entry_price - tp_distance;
         tp_price = NormalizeDouble(tp_price,g_symbol_digits);
        }
     }

   if(g_trade.PositionModify(_Symbol,sl_price,tp_price))
     {
      g_protection_done = true;
      PrintFormat("SharrowLOL: SL %.5f / TP %.5f gesetzt.",sl_price,tp_price);
     }
  }

void ManageTrailing()
  {
   double profit = PositionGetDouble(POSITION_PROFIT);
   if(g_stake_amount<=0.0)
      return;

   double profit_pct = (profit/g_stake_amount)*100.0;
   if(profit_pct < InpTrailStartPercent)
      return;

   double lock_pct = profit_pct - InpTrailGapPercent;
   if(lock_pct<=0.0)
      return;

   double lock_amount = g_stake_amount*lock_pct/100.0;
   double distance    = MoneyToPriceDistance(lock_amount,g_volume);
   if(distance<=0.0)
      return;

   double desired_sl = (g_type==POSITION_TYPE_BUY) ? g_entry_price + distance
                                                   : g_entry_price - distance;
   desired_sl = NormalizeDouble(desired_sl,g_symbol_digits);

   double current_sl = PositionGetDouble(POSITION_SL);
   if(g_type==POSITION_TYPE_BUY && desired_sl <= current_sl)
      return;
   if(g_type==POSITION_TYPE_SELL && desired_sl >= current_sl && current_sl!=0.0)
      return;

   if(g_trade.PositionModify(_Symbol,desired_sl,PositionGetDouble(POSITION_TP)))
      PrintFormat("SharrowLOL: Trail SL auf %.5f (%.2f%% Profit).",desired_sl,profit_pct);
  }
