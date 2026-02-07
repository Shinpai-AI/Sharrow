# SharrowLOL Handbuch

---

## 1) Start-Check (kurz)

- MT5 installiert (Windows oder Wine/Win-VM)
- Brokerkonto (z.B. NAGA) läuft
- Symbol passt zum Broker (z.B. XAUUSD, NAS100, US30 …)
- Timeframe auf H1 stellen (oder den im Bot eingestellten Timeframe)
- Zeitzone: alle Events in Berliner Zeit (CET/CEST)

---

## 2) Bot einsetzen (MT5)

- MT5 öffnen
- Chart öffnen (Symbol, z.B. XAUUSD)
- Bot SharrowLOL auf den Chart ziehen
- AutoTrading aktivieren

**Empfohlen:**

Freitag 22:00 Uhr bis Sonntag 23:00 Uhr = perfekte Ruhe zum Einrichten/Sync

---

## 3) Rules-Datei (Pflicht)

**Datei:** Rules-Master.txt

**Pfad:** /home/shinpai/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files

### Cloud-Workflow (empfohlen)

- Rules in Cloud-Ordner pflegen
- VPS sync't automatisch
- Symlink Cloud-Datei → MQL5/Files

So: Nur eine Datei pflegen.

---

## 4) Rules-Format (WICHTIG)

Eine Zeile = ein Event

**Basis:**
```
SYMBOL;YYYY-MM-DD HH:MM
```

**Erweitert:**
```
SYMBOL;YYYY-MM-DD HH:MM;key=value;key=value;...
```

### Unterstützte Parameter (ALLE Pflicht – keine Defaults für kritische!)

**Pre-Event**

- pre_time = Vorlauf vor Event (z.B. 30m, 1800s)
- pre_duration = Aktive Trigger-Dauer ab Pre-Start (z.B. 15m)
- pre_trigger = % ATR für Trigger
- pre_tp_atr = TP in ATR
- pre_sl_atr = SL in ATR
- pre_close = Sekunden vor Event schließen (z.B. 60s)

**Event**

- event_duration = Aktive Trigger-Dauer ab Event-Start (z.B. 30s)
- event_trigger = % ATR für Trigger
- event_tp_atr = TP in ATR
- event_sl_atr = SL in ATR
- event_exit_watch = Sharrow-Exit-Überwachungsdauer (z.B. 10s)
- event_exit_atr = ATR-Schwelle für Exit (z.B. 0.5)
- event_exit_min_profit = Min-Profit für Exit (z.B. 0.01)

### Beispiel (voll – alle Pflicht-Params)

```
CHFJPY;2026-02-06 17:45;pre_time=30m;pre_duration=15m;pre_trigger=100;pre_tp_atr=1.5;pre_sl_atr=2.0;pre_close=60s;event_duration=30s;event_trigger=15;event_tp_atr=0.8;event_sl_atr=1.2;event_exit_watch=10s;event_exit_atr=0.5;event_exit_min_profit=0.01
```

### Einheiten

- Trigger = % (z.B. 100)
- Time/Duration/Close = mit s/m/h (z.B. 30m, 60s)
- TP/SL = ATR-Multiplikator (z.B. 1.5)
- Exit-Profit = EUR (z.B. 0.01)

### Log beim Laden

- Jede Rule wird detailliert geloggt (Symbol, Zeit, alle Params)
- Wenn Param fehlt → Rule skipped + Warnung
- Keine validen Rules → Bot stoppt + FATAL-Warnung

---

## 5) Verhalten (ganz kurz)

- Pre-Event beobachtet ab event_time - pre_time, triggert nur innerhalb pre_duration
- Pre-Trade schließt automatisch vor Event (pre_close)
- Event beobachtet ab event_time, triggert innerhalb event_duration
- Sharrow-Exit (Event): Prüft Favor-Move innerhalb event_exit_watch; wenn < event_exit_atr * ATR → wartet auf event_exit_min_profit & schließt

---

## 6) Keine Defaults für kritische Params

- Alle oben aufgelistet müssen in Rules stehen
- Fehlt was? Rule skipped

---

## 7) Tipps (für Events & Params)

- Events finden: Mit 2-3 KIs abgleichen (z.B. Claude, ich, Grok) – nur bei Konfirm von allen eintragen. Hohe Impact-Daten (z.B. News, Earnings).
- Pre-Event: Immer so früh wie möglich (bei 30-45 → 45m; 15-25 → 25m)
- Pre-Duration: Möglich lang, max 75% von Pre-Time (z.B. Pre-Time 30m → max 22.5m Duration)
- Event-Duration: Max 30s (hart) – passend zur Volatilität
- Pre TP/SL: Großzügig (1-2 ATR), TP kleiner (trailing eh), SL weit (schützt, ohne früh raus)
- Event TP/SL: 0.5-2 ATR, passend zu Volatilität (z.B. volatile Symbol → größerer SL)
- Min-Profit: Max 1 EUR, eher 0.01-0.1 EUR (oder 0.01%-0.1% vom Stake – rechnen!)
- Ein Symbol pro Zeile
- Datum/Uhrzeit exakt in Broker-Zeit (UTC)
