#property copyright "Hannes Kell / Shinpai-AI / Ray-Enhanced"
#property link      "https://shinpai.de"
#property version   "3.03"
#property strict

#include <Trade/Trade.mqh>

struct RuleEntry
  {
   string   symbol;
   datetime event_time;
   bool     rule_processed;

   int      pre_lead_seconds;
   int      pre_monitor_seconds;
   int      pre_trigger_percent;
   double   pre_tp_multiplier;
   double   pre_sl_multiplier;
   int      pre_hard_close_seconds;

   int      event_monitor_seconds;
   int      event_trigger_percent;
   double   event_tp_multiplier;
   double   event_sl_multiplier;
   int      event_exit_monitor_seconds;
   double   event_exit_atr_threshold;
   double   event_exit_min_profit_eur;
  };

input string InpRulesFile            = "Rules-Master.txt"; //Name der Rules Datei

// === EINSATZ ==================================================
input string     ___Einsätze___       = "=== Einsätze ==="; // -----
enum ENUM_STAKE_MODE
 {
   STAKE_PERCENT = 0,   // % vom Konto
   STAKE_FIXED   = 1    // fixer Wert
  };
input ENUM_STAKE_MODE InpStakeMode   = STAKE_PERCENT; // Einsatz Berechnung
input double InpStakePercent         = 100.0;         // Einsatz in % vom Konto (1-100)
input double InpStakeFixed           = 0.0;           // Fixer Einsatz (0-X)

// === BOT PARAMETER ====================================================
input string     ___Bot-Parameter___       = "=== Bot-Parameter ==="; // -----
input ENUM_TIMEFRAMES InpTradeTimeframe = PERIOD_H1;  // Timeframe
input int    InpATRPeriod               = 20;         // ATR Periode (Kerzen)

// === TP/SL - TRAILING =================================================
input string     ___TP/SL-Trailing___       = "=== TP/SL-Trailing ==="; // -----
input bool   InpTrailingEnabled         = true;       // Trailing ON/OFF

// === WEBTICKER ========================================================
input string     ___WebTicker___       = "=== WebTicker ==="; // -----
input bool   InpEnableWebTicker      = false;         // WebTicker aktivieren (ON/OFF)
input string InpStateLogFile         = "Goldjunge-state.log"; // WebTicker Log-Datei
input int    InpSnapshotIntervalMin  = 60;            // Snapshot-Intervall in Minuten

CTrade tradeEngine;

RuleEntry activeRules[];
datetime lastRulesReload     = 0;
bool     hasValidRules       = false;

// POSITION & TRADE STATE
ulong    activeTicket        = 0;
double   entryPrice          = 0.0;
double   tradeVolume         = 0.0;
double   frozenATR           = 0.0;
ENUM_POSITION_TYPE positionDirection = POSITION_TYPE_BUY;
int      currentPhase        = 0;
datetime activeEventTime     = 0;
int      preHardCloseSeconds = 0;
double   tpMultiplier        = 0.0;
double   slMultiplier        = 0.0;

// PRE PHASE STATE
bool     isPreMonitoring     = false;
double   preRefPrice         = 0.0;
datetime preMonitorStart     = 0;
double   preFrozenATR        = 0.0;
int      activePreRuleIdx    = -1;

// EVENT PHASE STATE
bool     isEventMonitoring   = false;
double   eventRefPrice       = 0.0;
datetime eventMonitorStart   = 0;
double   eventFrozenATR      = 0.0;
int      activeEventRuleIdx  = -1;

// SHARROW EXIT (EVENT ONLY)
bool     sharrowActive       = false;
bool     sharrowWaitingProfit= false;
datetime sharrowStartTime    = 0;
double   sharrowMaxFavorMove = 0.0;
double   sharrowAtrThreshold = 0.0;
double   sharrowMinProfit    = 0.0;
int      sharrowMonitorSeconds= 0;

// HELPERS
datetime priceHistoryTimes[];
double   priceHistoryValues[];
int      symbolDigits        = 0;
int      atrIndicatorHandle  = INVALID_HANDLE;

// WEBTICKER
datetime lastSnapshotTime    = 0;
ulong    lastLoggedCloseTicket= 0;

int OnInit()
  {
   symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(InpStakeMode == STAKE_PERCENT && (InpStakePercent <= 0.0 || InpStakePercent > 100.0))
     {
      Print("Ungültiger Stake-Parameter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   atrIndicatorHandle = iATR(_Symbol, InpTradeTimeframe, InpATRPeriod);
   if(atrIndicatorHandle == INVALID_HANDLE)
     {
      Print("ATR-Handle konnte nicht erstellt werden!");
      return INIT_FAILED;
     }

   if(!LoadRules() || ArraySize(activeRules) == 0 || !hasValidRules)
     {
      Print("\n=================================================================");
      Print(" FATAL: KEINE GÜLTIGEN RULES GELADEN!");
      Print(" Bot kann nicht arbeiten – Rules-Master.txt prüfen oder korrigieren.");
      Print("=================================================================\n");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpEnableWebTicker && InpStateLogFile != "")
     {
      WriteWebTickerSnapshot();
      Print("WebTicker aktiviert → Log: ", InpStateLogFile);
     }

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(atrIndicatorHandle != INVALID_HANDLE) IndicatorRelease(atrIndicatorHandle);
   ArrayFree(activeRules);
   ArrayFree(priceHistoryTimes);
   ArrayFree(priceHistoryValues);
  }

void OnTick()
  {
   if(_Period != InpTradeTimeframe)
     {
      static bool warned = false;
      if(!warned)
        {
         PrintFormat("Falscher Timeframe! Erwartet %s, aktuell %s.", EnumToString(InpTradeTimeframe), EnumToString((ENUM_TIMEFRAMES)_Period));
         warned = true;
        }
      return;
     }

   MaybeReloadRules();
   UpdatePriceHistory();

   ManageActiveTrade();
   MonitorForEntries();

   if(InpEnableWebTicker)
     {
      MaybeWriteSnapshot();
      CheckForClosedTrades();
     }
  }

double GetCurrentATR()
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(atrIndicatorHandle, 0, 0, 1, buf) <= 0)
     {
      Print("ATR-Lesen fehlgeschlagen!");
      return 0.0;
     }
   return buf[0];
  }

void MaybeReloadRules()
  {
   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);
   if(tm.day_of_week != 0) return;
   if(tm.hour != 16 && tm.hour != 23) return;
   if(now - lastRulesReload < 3600) return;

   if(LoadRules())
      Print("Rules nach Zeitplan neu geladen.");
  }

bool LoadRules()
  {
   ArrayFree(activeRules);
   hasValidRules = false;

   int fh = FileOpen(InpRulesFile, FILE_READ|FILE_TXT|FILE_ANSI);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("Rules-Datei %s nicht gefunden.", InpRulesFile);
      return false;
     }

   int validCount = 0;
   while(!FileIsEnding(fh))
     {
      string line = FileReadString(fh);
      StringTrimLeft(line); StringTrimRight(line);
      if(line == "" || StringFind(line, "//") == 0) continue;

      string tokens[];
      if(StringSplit(line, ';', tokens) < 2) continue;

      string sym = tokens[0];
      string timeStr = tokens[1];
      datetime evtTime;
      if(!ParseRuleTime(timeStr, evtTime)) continue;

      RuleEntry r;
      r.symbol = sym;
      r.event_time = evtTime;
      r.rule_processed = false;

      r.pre_lead_seconds = -1;
      r.pre_monitor_seconds = -1;
      r.pre_trigger_percent = -1;
      r.pre_tp_multiplier = -1.0;
      r.pre_sl_multiplier = -1.0;
      r.pre_hard_close_seconds = -1;
      r.event_monitor_seconds = -1;
      r.event_trigger_percent = -1;
      r.event_tp_multiplier = -1.0;
      r.event_sl_multiplier = -1.0;
      r.event_exit_monitor_seconds = -1;
      r.event_exit_atr_threshold = -1.0;
      r.event_exit_min_profit_eur = -1.0;

      for(int k = 2; k < ArraySize(tokens); k++)
        {
         string pair = tokens[k];
         StringTrimLeft(pair); StringTrimRight(pair);
         if(pair == "") continue;
         int eqPos = StringFind(pair, "=");
         if(eqPos < 0) continue;
         string kname = StringSubstr(pair, 0, eqPos);
         string vstr  = StringSubstr(pair, eqPos+1);
         StringToLower(kname);
         ApplyRuleParam(r, kname, vstr);
        }

      if(r.pre_lead_seconds <= 0 || r.pre_monitor_seconds <= 0 ||
         r.pre_trigger_percent <= 0 || r.pre_tp_multiplier <= 0 || r.pre_sl_multiplier <= 0 ||
         r.pre_hard_close_seconds < 0 ||
         r.event_monitor_seconds <= 0 || r.event_trigger_percent <= 0 ||
         r.event_tp_multiplier <= 0 || r.event_sl_multiplier <= 0 ||
         r.event_exit_monitor_seconds <= 0 || r.event_exit_atr_threshold <= 0 ||
         r.event_exit_min_profit_eur < 0)
        {
         PrintFormat("INVALID RULE %s @ %s – fehlende/ungültige Parameter! Skipping.", sym, TimeToString(evtTime));
         continue;
        }

      if(r.pre_monitor_seconds > r.pre_lead_seconds)
        PrintFormat("WARN: pre_monitor (%ds) > pre_lead (%ds) für %s", r.pre_monitor_seconds, r.pre_lead_seconds, sym);

      ArrayResize(activeRules, validCount+1);
      activeRules[validCount] = r;
      validCount++;

      PrintFormat("[RULE %d] %s @ %s | pre_lead=%ds (%dm) | pre_monitor=%ds (%dm) | pre_trigger=%d%% | pre_tp=%.2fATR | pre_sl=%.2fATR | pre_close=%ds | event_monitor=%ds (%dm) | event_trigger=%d%% | event_tp=%.2fATR | event_sl=%.2fATR | exit_monitor=%ds | exit_atr=%.2f | min_profit=%.2f",
                  validCount, sym, TimeToString(evtTime),
                  r.pre_lead_seconds, r.pre_lead_seconds/60,
                  r.pre_monitor_seconds, r.pre_monitor_seconds/60,
                  r.pre_trigger_percent, r.pre_tp_multiplier, r.pre_sl_multiplier, r.pre_hard_close_seconds,
                  r.event_monitor_seconds, r.event_monitor_seconds/60,
                  r.event_trigger_percent, r.event_tp_multiplier, r.event_sl_multiplier,
                  r.event_exit_monitor_seconds, r.event_exit_atr_threshold, r.event_exit_min_profit_eur);
     }

   FileClose(fh);
   lastRulesReload = TimeCurrent();

   if(validCount > 0) hasValidRules = true;

   PrintFormat("\n=== %d valide Rules geladen ===\n", validCount);
   return true;
  }

void ApplyRuleParam(RuleEntry &r, string key, string val)
  {
   StringTrimLeft(val); StringTrimRight(val);

   if(key == "pre_time")              r.pre_lead_seconds           = ParseDurationSeconds(val, -1);
   else if(key == "pre_duration")     r.pre_monitor_seconds        = ParseDurationSeconds(val, -1);
   else if(key == "pre_trigger")      r.pre_trigger_percent        = (int)StringToInteger(val);
   else if(key == "pre_tp_atr")       r.pre_tp_multiplier          = StringToDouble(val);
   else if(key == "pre_sl_atr")       r.pre_sl_multiplier          = StringToDouble(val);
   else if(key == "pre_close")        r.pre_hard_close_seconds     = ParseDurationSeconds(val, -1);
   else if(key == "event_duration")   r.event_monitor_seconds      = ParseDurationSeconds(val, -1);
   else if(key == "event_trigger")    r.event_trigger_percent      = (int)StringToInteger(val);
   else if(key == "event_tp_atr")     r.event_tp_multiplier        = StringToDouble(val);
   else if(key == "event_sl_atr")     r.event_sl_multiplier        = StringToDouble(val);
   else if(key == "event_exit_watch") r.event_exit_monitor_seconds = ParseDurationSeconds(val, -1);
   else if(key == "event_exit_atr" || key == "event_exit_threshold") r.event_exit_atr_threshold = StringToDouble(val);
   else if(key == "event_exit_min_profit") r.event_exit_min_profit_eur = StringToDouble(val);
  }

int ParseDurationSeconds(string raw, int fallback)
  {
   string s = raw;
   StringTrimLeft(s); StringTrimRight(s);
   if(StringLen(s) == 0) return fallback;

   int len = StringLen(s);
   string last = StringSubstr(s, len-1, 1);
   string lower_last = last;
   StringToLower(lower_last);
   int mult = 1;
   if(lower_last == "s") { mult = 1; s = StringSubstr(s, 0, len-1); }
   else if(lower_last == "m") { mult = 60; s = StringSubstr(s, 0, len-1); }
   else if(lower_last == "h") { mult = 3600; s = StringSubstr(s, 0, len-1); }

   int val = (int)StringToInteger(s);
   if(val <= 0) return fallback;
   return val * mult;
  }

bool ParseRuleTime(string raw, datetime &result)
  {
   string norm = raw;
   StringTrimLeft(norm); StringTrimRight(norm);
   StringReplace(norm, "/", "-");
   StringReplace(norm, ".", "-");

   string parts[];
   if(StringSplit(norm, ' ', parts) < 2) return false;

   string date_part = parts[0];
   string time_part = parts[1];

   string date_tokens[];
   if(StringSplit(date_part, '-', date_tokens) != 3) return false;

   string time_tokens[];
   int tcount = StringSplit(time_part, ':', time_tokens);
   if(tcount < 2) return false;

   MqlDateTime tm;
   tm.year = (int)StringToInteger(date_tokens[0]);
   tm.mon  = (int)StringToInteger(date_tokens[1]);
   tm.day  = (int)StringToInteger(date_tokens[2]);
   tm.hour = (int)StringToInteger(time_tokens[0]);
   tm.min  = (int)StringToInteger(time_tokens[1]);
   tm.sec  = (tcount >= 3) ? (int)StringToInteger(time_tokens[2]) : 0;

   if(tm.year < 1970 || tm.mon < 1 || tm.day < 1) return false;

   result = StructToTime(tm);
   return result > 0;
  }

void UpdatePriceHistory()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   datetime now = tick.time > 0 ? tick.time : TimeCurrent();
   double mid = (tick.bid + tick.ask) / 2.0;

   int size = ArraySize(priceHistoryTimes);
   ArrayResize(priceHistoryTimes, size + 1);
   ArrayResize(priceHistoryValues, size + 1);
   priceHistoryTimes[size] = now;
   priceHistoryValues[size] = mid;

   int maxWin = 0;
   for(int i = 0; i < ArraySize(activeRules); i++)
     {
      if(activeRules[i].symbol != _Symbol) continue;
      maxWin = MathMax(maxWin, activeRules[i].pre_monitor_seconds);
      maxWin = MathMax(maxWin, activeRules[i].event_monitor_seconds);
     }
   RemoveOldHistory(now - maxWin - 5);
  }

void RemoveOldHistory(datetime minTime)
  {
   int size = ArraySize(priceHistoryTimes);
   int start = 0;
   while(start < size && priceHistoryTimes[start] < minTime) start++;
   if(start <= 0 || start >= size) return;

   int newSize = size - start;
   for(int i = 0; i < newSize; i++)
     {
      priceHistoryTimes[i] = priceHistoryTimes[start + i];
      priceHistoryValues[i] = priceHistoryValues[start + i];
     }
   ArrayResize(priceHistoryTimes, newSize);
   ArrayResize(priceHistoryValues, newSize);
  }

void MonitorForEntries()
  {
   if(!hasValidRules) return;

   datetime now = TimeCurrent();
   double currentMid = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;

   // PRE-MONITORING CHECK
   if(isPreMonitoring && activePreRuleIdx >= 0)
     {
      RuleEntry r = activeRules[activePreRuleIdx];
      datetime preMonitorEnd = preMonitorStart + r.pre_monitor_seconds;
      datetime preHardClose = r.event_time - r.pre_hard_close_seconds;

      if(now >= preHardClose)
        {
         PrintFormat("Pre-Monitoring ENDED (Hard Close) für %s", r.symbol);
         activeRules[activePreRuleIdx].rule_processed = true;
         isPreMonitoring = false;
         activePreRuleIdx = -1;
        }
      else if(!PositionSelect(_Symbol) && now < preMonitorEnd)
        {
         double move = currentMid - preRefPrice;
         double absMove = MathAbs(move);
         double thresh = preFrozenATR * (r.pre_trigger_percent / 100.0);

         PrintFormat("PRE-MONITOR | Ref=%.5f | Now=%.5f | Move=%.5f | Need=%.5f (%.0f%% ATR)",
                     preRefPrice, currentMid, absMove, thresh, (double)r.pre_trigger_percent);

         if(absMove >= thresh)
           {
            ENUM_ORDER_TYPE dir = move >= 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            PrintFormat("PRE-TRIGGER! %s | Move=%.5f >= %.5f", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), absMove, thresh);

            if(OpenTrade(dir, r.event_time, 1, r.pre_tp_multiplier, r.pre_sl_multiplier, r.pre_hard_close_seconds, 0.0, 0.0))
              {
               activeRules[activePreRuleIdx].rule_processed = true;
               isPreMonitoring = false;
               activePreRuleIdx = -1;
              }
           }
        }
     }

   // EVENT-MONITORING CHECK
   if(isEventMonitoring && activeEventRuleIdx >= 0)
     {
      RuleEntry r = activeRules[activeEventRuleIdx];
      datetime eventMonitorEnd = eventMonitorStart + r.event_monitor_seconds;

      if(now >= eventMonitorEnd)
        {
         PrintFormat("Event-Monitoring ENDED (Timeout) für %s", r.symbol);
         activeRules[activeEventRuleIdx].rule_processed = true;
         isEventMonitoring = false;
         activeEventRuleIdx = -1;
        }
      else if(!PositionSelect(_Symbol))
        {
         double move = currentMid - eventRefPrice;
         double absMove = MathAbs(move);
         double thresh = eventFrozenATR * (r.event_trigger_percent / 100.0);

         PrintFormat("EVENT-MONITOR | Ref=%.5f | Now=%.5f | Move=%.5f | Need=%.5f (%.0f%% ATR)",
                     eventRefPrice, currentMid, absMove, thresh, (double)r.event_trigger_percent);

         if(absMove >= thresh)
           {
            ENUM_ORDER_TYPE dir = move >= 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            PrintFormat("EVENT-TRIGGER! %s | Move=%.5f >= %.5f", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), absMove, thresh);

            if(OpenTrade(dir, r.event_time, 2, r.event_tp_multiplier, r.event_sl_multiplier, 0, r.event_exit_atr_threshold, r.event_exit_min_profit_eur))
              {
               activeRules[activeEventRuleIdx].rule_processed = true;
               isEventMonitoring = false;
               activeEventRuleIdx = -1;
              }
           }
        }
     }

   // NEUE MONITORE STARTEN
   for(int i = 0; i < ArraySize(activeRules); i++)
     {
      RuleEntry r = activeRules[i];
      if(r.symbol != _Symbol) continue;
      if(r.rule_processed) continue;

      datetime preStart = r.event_time - r.pre_lead_seconds;
      datetime preMonitorEnd = preStart + r.pre_monitor_seconds;
      datetime preHardClose = r.event_time - r.pre_hard_close_seconds;
      datetime eventStart = r.event_time;
      datetime eventMonitorEnd = r.event_time + r.event_monitor_seconds;

      // PRE START
      if(!isPreMonitoring)
        {
         if(now >= preHardClose)
           {
            PrintFormat("Pre-Fenster VERPASST (Hard Close vorbei) für %s", r.symbol);
            activeRules[i].rule_processed = true;
           }
         else if(now >= preStart && now < preMonitorEnd)
           {
            isPreMonitoring = true;
            preRefPrice = currentMid;
            preMonitorStart = now;
            preFrozenATR = GetCurrentATR();
            if(preFrozenATR <= 0.0)
              {
               Print("Pre-ATR Freeze failed – aborting!");
               isPreMonitoring = false;
               continue;
              }
            activePreRuleIdx = i;

            PrintFormat("PRE-MONITOR START | %s | Ref=%.5f | ATR=%.5f | Trigger=%d%% | Monitor=%ds | HardClose=%ds",
                        r.symbol, preRefPrice, preFrozenATR, r.pre_trigger_percent, r.pre_monitor_seconds, r.pre_hard_close_seconds);
           }
        }

      // EVENT START
      if(!isEventMonitoring)
        {
         if(now >= eventMonitorEnd)
           {
            PrintFormat("Event-Fenster VERPASST für %s", r.symbol);
            activeRules[i].rule_processed = true;
           }
         else if(now >= eventStart)
           {
            isEventMonitoring = true;
            eventRefPrice = currentMid;
            eventMonitorStart = now;
            eventFrozenATR = GetCurrentATR();
            if(eventFrozenATR <= 0.0)
              {
               Print("Event-ATR Freeze failed – aborting!");
               isEventMonitoring = false;
               continue;
              }
            activeEventRuleIdx = i;

            PrintFormat("EVENT-MONITOR START | %s | Ref=%.5f | ATR=%.5f | Trigger=%d%% | Monitor=%ds | ExitMonitor=%ds | ExitThresh=%.2f | MinProfit=%.2f",
                        r.symbol, eventRefPrice, eventFrozenATR, r.event_trigger_percent, r.event_monitor_seconds,
                        r.event_exit_monitor_seconds, r.event_exit_atr_threshold, r.event_exit_min_profit_eur);
           }
        }
     }
  }

bool OpenTrade(ENUM_ORDER_TYPE dir, datetime evtTime, int phase, double tpMult, double slMult, int closeSecs, double exitThresh, double minProfit)
  {
   if(PositionSelect(_Symbol))
     {
      Print("Position bereits offen – skipped.");
      return false;
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return false;

   double stake = InpStakeMode == STAKE_FIXED ? InpStakeFixed : equity * InpStakePercent / 100.0;
   if(stake <= 0.0) return false;

   double price = dir == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) return false;

   double vol = CalculateVolume(dir, stake, price);
   if(vol <= 0.0)
     {
      Print("Volumenberechnung fehlgeschlagen.");
      return false;
     }

   frozenATR = GetCurrentATR();
   if(frozenATR <= 0.0)
     {
      Print("ATR Freeze failed beim Open!");
      return false;
     }

   double sl = 0.0, tp = 0.0;
   if(tradeEngine.PositionOpen(_Symbol, dir, vol, price, sl, tp))
     {
      PrintFormat("Trade OPEN (%s, %.2f Lots) Phase=%d | ATR=%.5f", EnumToString(dir), vol, phase, frozenATR);
      currentPhase = phase;
      activeEventTime = evtTime;
      tpMultiplier = tpMult;
      slMultiplier = slMult;
      if(phase == 1)
         preHardCloseSeconds = closeSecs;
      else if(phase == 2)
        {
         sharrowMonitorSeconds = activeRules[activeEventRuleIdx].event_exit_monitor_seconds;
         sharrowAtrThreshold = exitThresh;
         sharrowMinProfit = minProfit;
         sharrowActive = true;
         sharrowWaitingProfit = false;
         sharrowStartTime = TimeCurrent();
         sharrowMaxFavorMove = 0.0;
        }
      InitializePosition();
      return true;
     }

   PrintFormat("PositionOpen fehlgeschlagen (%d).", GetLastError());
   return false;
  }

double CalculateVolume(ENUM_ORDER_TYPE dir, double stake, double price)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 0.01;

   double marginPerLot = 0.0;
   if(!OrderCalcMargin(dir, _Symbol, 1.0, price, marginPerLot) || marginPerLot <= 0.0)
      return minLot;

   double vol = stake / marginPerLot;
   vol = MathMax(vol, minLot);
   vol = MathMin(vol, maxLot);

   double steps = MathFloor(vol / lotStep);
   vol = steps * lotStep;
   vol = MathMax(vol, minLot);
   vol = MathMin(vol, maxLot);

   int digits = 0;
   double tmp = lotStep;
   while(tmp < 1.0 && digits < 8)
     {
      tmp *= 10.0;
      digits++;
     }

   return NormalizeDouble(vol, digits);
  }

void InitializePosition()
  {
   if(!PositionSelect(_Symbol)) return;
   activeTicket = (ulong)PositionGetInteger(POSITION_TICKET);
   entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   tradeVolume = PositionGetDouble(POSITION_VOLUME);
   positionDirection = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
  }

void ManageActiveTrade()
  {
   if(activeTicket == 0)
     {
      if(PositionSelect(_Symbol))
        {
         activeTicket = (ulong)PositionGetInteger(POSITION_TICKET);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         tradeVolume = PositionGetDouble(POSITION_VOLUME);
         positionDirection = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         if(frozenATR <= 0.0)
           {
            frozenATR = GetCurrentATR();
            PrintFormat("ATR nachträglich frozen: %.5f", frozenATR);
           }
        }
      return;
     }

   if(!PositionSelectByTicket((long)activeTicket))
     {
      ResetTradeState();
      return;
     }

   if(currentPhase == 1 && activeEventTime > 0 && preHardCloseSeconds > 0)
     {
      datetime closeAt = activeEventTime - preHardCloseSeconds;
      if(TimeCurrent() >= closeAt)
        {
         if(tradeEngine.PositionClose(_Symbol))
            Print("Pre-Trade HARD CLOSED vor Event.");
         ResetTradeState();
         return;
        }
     }

   if(currentPhase == 2)
      RunSharrowExit();

   if(InpTrailingEnabled)
      ApplyUnlimitedTrailing();
  }

void ResetTradeState()
  {
   activeTicket = 0;
   entryPrice = 0.0;
   tradeVolume = 0.0;
   frozenATR = 0.0;
   currentPhase = 0;
   activeEventTime = 0;
   preHardCloseSeconds = 0;
   tpMultiplier = 0.0;
   slMultiplier = 0.0;
   sharrowActive = false;
   sharrowWaitingProfit = false;
   sharrowStartTime = 0;
   sharrowMaxFavorMove = 0.0;
   sharrowAtrThreshold = 0.0;
   sharrowMinProfit = 0.0;
   sharrowMonitorSeconds = 0;
  }

void RunSharrowExit()
  {
   if(sharrowMonitorSeconds <= 0 || sharrowAtrThreshold <= 0.0 || frozenATR <= 0.0) return;

   if(!sharrowActive)
     {
      sharrowActive = true;
      sharrowWaitingProfit = false;
      sharrowStartTime = TimeCurrent();
      sharrowMaxFavorMove = 0.0;
     }

   double currPrice = positionDirection == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(currPrice <= 0.0) return;

   double favor = positionDirection == POSITION_TYPE_BUY ? currPrice - entryPrice : entryPrice - currPrice;
   if(favor > sharrowMaxFavorMove) sharrowMaxFavorMove = favor;

   int elapsed = (int)(TimeCurrent() - sharrowStartTime);
   double needed = frozenATR * sharrowAtrThreshold;

   if(elapsed >= sharrowMonitorSeconds && sharrowMaxFavorMove < needed)
      sharrowWaitingProfit = true;

   if(sharrowWaitingProfit)
     {
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit >= sharrowMinProfit)
        {
         if(tradeEngine.PositionClose(_Symbol))
           {
            PrintFormat("SharrowExit CLOSED | Profit=%.2f | MaxFavor=%.5f < Needed=%.5f", profit, sharrowMaxFavorMove, needed);
            ResetTradeState();
           }
        }
     }
   else if(elapsed >= sharrowMonitorSeconds && sharrowMaxFavorMove >= needed)
     {
      sharrowActive = false;
      sharrowWaitingProfit = false;
     }
  }

void ApplyUnlimitedTrailing()
  {
   if(frozenATR <= 0.0) return;

   double currPrice = positionDirection == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(currPrice <= 0.0) return;

   double currSL = PositionGetDouble(POSITION_SL);
   double currTP = PositionGetDouble(POSITION_TP);

   double slDist = frozenATR * slMultiplier;
   double tpDist = frozenATR * tpMultiplier;

   double wantSL, wantTP;
   if(positionDirection == POSITION_TYPE_BUY)
     {
      wantSL = currPrice - slDist;
      wantTP = currPrice + tpDist;
     }
   else
     {
      wantSL = currPrice + slDist;
      wantTP = currPrice - tpDist;
     }

   wantSL = NormalizeDouble(wantSL, symbolDigits);
   wantTP = NormalizeDouble(wantTP, symbolDigits);

   bool needSLUpdate = false;
   if(positionDirection == POSITION_TYPE_BUY)
      needSLUpdate = (wantSL > currSL || currSL == 0.0);
   else
      needSLUpdate = (wantSL < currSL || currSL == 0.0);

   bool needTPUpdate = (MathAbs(wantTP - currTP) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);

   if(!needSLUpdate && !needTPUpdate) return;

   if(!needSLUpdate) wantSL = currSL;

   if(tradeEngine.PositionModify(_Symbol, wantSL, wantTP))
      PrintFormat("Trailing UPDATE | SL=%.5f | TP=%.5f | Price=%.5f | ATR=%.5f", wantSL, wantTP, currPrice, frozenATR);
  }

string FormatISOTimestamp(datetime dt)
  {
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ", tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
  }

string FormatLogTimestamp(datetime dt)
  {
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   return StringFormat("[%04d.%02d.%02d %02d:%02d:%02d]", tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
  }

void WriteWebTickerSnapshot()
  {
   if(!InpEnableWebTicker || InpStateLogFile == "") return;

   datetime now = TimeCurrent();
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatP = eq - bal;

   string json = StringFormat("{\"type\":\"snapshot\",\"timestamp\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"floating\":%.2f}",
                              FormatISOTimestamp(now), bal, eq, floatP);

   string line = FormatLogTimestamp(now) + " [WEB_TICKER] " + json;

   int h = FileOpen(InpStateLogFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h != INVALID_HANDLE)
     {
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
     }

   lastSnapshotTime = now;
  }

void MaybeWriteSnapshot()
  {
   if(!InpEnableWebTicker || InpSnapshotIntervalMin <= 0) return;

   datetime now = TimeCurrent();
   if(now - lastSnapshotTime >= InpSnapshotIntervalMin * 60)
      WriteWebTickerSnapshot();
  }

void CheckForClosedTrades()
  {
   if(!InpEnableWebTicker) return;

   datetime from = TimeCurrent() - 300;
   datetime to = TimeCurrent();

   if(!HistorySelect(from, to)) return;

   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong dealId = HistoryDealGetTicket(i);
      if(dealId == 0 || dealId <= lastLoggedCloseTicket) continue;

      ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealId, DEAL_ENTRY);
      if(entryType != DEAL_ENTRY_OUT) continue;

      string sym = HistoryDealGetString(dealId, DEAL_SYMBOL);
      double vol = HistoryDealGetDouble(dealId, DEAL_VOLUME);
      double prof = HistoryDealGetDouble(dealId, DEAL_PROFIT);
      datetime closeTime = (datetime)HistoryDealGetInteger(dealId, DEAL_TIME);
      ENUM_DEAL_TYPE dType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealId, DEAL_TYPE);
      ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealId, DEAL_REASON);

      ulong posId = (ulong)HistoryDealGetInteger(dealId, DEAL_POSITION_ID);
      datetime openTime = closeTime - 3600;

      if(HistorySelectByPosition(posId))
        {
         int pd = HistoryDealsTotal();
         for(int j = 0; j < pd; j++)
           {
            ulong pdId = HistoryDealGetTicket(j);
            if(pdId == 0) continue;
            if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(pdId, DEAL_ENTRY) == DEAL_ENTRY_IN)
              {
               openTime = (datetime)HistoryDealGetInteger(pdId, DEAL_TIME);
               break;
              }
           }
        }

      string oType = dType == DEAL_TYPE_SELL ? "BUY" : "SELL";
      string exitR = "manual";
      if(reason == DEAL_REASON_SL) exitR = "sl";
      else if(reason == DEAL_REASON_TP) exitR = "tp";

      WriteWebTickerTrade(dealId, sym, vol, prof, oType, openTime, closeTime, exitR);
      lastLoggedCloseTicket = dealId;

      WriteWebTickerSnapshot();
     }
  }

void WriteWebTickerTrade(ulong ticket, string sym, double vol, double prof, string oType, datetime openT, datetime closeT, string reason)
  {
   if(!InpEnableWebTicker || InpStateLogFile == "") return;

   datetime now = TimeCurrent();

   string json = StringFormat("{\"type\":\"trade\",\"ticket\":\"%I64u\",\"symbol\":\"%s\",\"volume\":%.2f,\"profit\":%.2f,\"order_type\":\"%s\",\"opened_at\":\"%s\",\"closed_at\":\"%s\",\"exit_reason\":\"%s\",\"comment\":\"SharrowLOL\"}",
                              ticket, sym, vol, prof, oType, FormatISOTimestamp(openT), FormatISOTimestamp(closeT), reason);

   string line = FormatLogTimestamp(now) + " [WEB_TICKER] " + json;

   int h = FileOpen(InpStateLogFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(h != INVALID_HANDLE)
     {
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
      PrintFormat("WebTicker Trade logged – Ticket %I64u, Profit %.2f", ticket, prof);
     }
  }
