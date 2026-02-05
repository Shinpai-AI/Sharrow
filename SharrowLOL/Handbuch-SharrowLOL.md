# Handbuch – SharrowLOL (kurz & klar)

Ziel: Bot auf MT5 starten, Rules eintragen, laufen lassen. Ohne Gelaber.

---

## 1) Start‑Check (kurz)
- **MT5 installiert** (Windows oder Wine/Win‑VM)
- **Brokerkonto** (z.B. NAGA) läuft
- **Symbol passt zum Broker** (z.B. XAUUSD, NAS100, US30 …)
- **Zeitzone:** alle Events in **Berliner Zeit (CET/CEST)**

---

## 2) Bot einsetzen (MT5)
1. MT5 öffnen
2. Chart öffnen (Symbol, z.B. XAUUSD)
3. **Timeframe auf H1** stellen (oder den im Bot eingestellten Timeframe)
4. Bot `SharrowLOL` auf den Chart ziehen
5. **AutoTrading aktivieren**

**Empfohlen:**
- **Freitag 22:00 Uhr bis Sonntag 23:00 Uhr** = perfekte Ruhe zum Einrichten/Sync

---

## 3) Rules‑Datei (Pflicht)
Die Datei heißt:
```
Rules-Master.txt
```
und muss in dieses MT5‑Verzeichnis:
```
/home/shinpai/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files
```

### Cloud‑Workflow (empfohlen)
- Rules‑Datei in Cloud‑Ordner pflegen
- VPS synchronisiert automatisch
- Symlink von Cloud‑Datei → `MQL5/Files`

So musst du **nur eine Datei pflegen**.

---

## 4) Rules‑Format (WICHTIG)
**Eine Zeile = ein Event**

Basis:
```
SYMBOL;YYYY-MM-DD HH:MM
```

Erweitert (mit Parametern):
```
SYMBOL;YYYY-MM-DD HH:MM;key=value;key=value;...
```

### Unterstützte Parameter
**Pre‑Event**
- `pre_trigger` = % ATR
- `pre_watch` = Dauer (z.B. `10m`, `600s`)
- `close_before` = wie lange vor Event schließen (z.B. `60s`)
- `pre_tp_atr`
- `pre_sl_atr`

**Event**
- `event_trigger` = % ATR
- `event_watch` = Dauer (z.B. `30s`)
- `event_tp_atr`
- `event_sl_atr`

### Beispiel (voll)
```
XAUUSD;2026-02-08 14:30;pre_trigger=45;pre_watch=10m;close_before=60s;pre_tp_atr=0.3;pre_sl_atr=0.5;event_trigger=10;event_watch=30s;event_tp_atr=1.0;event_sl_atr=1.0
```

### Einheiten (idiotensicher)
- **Trigger** immer in **%**
- **Watch / Close** immer mit **s / m / h** (Sek, Min, Std)
- **TP/SL** immer in **ATR**

Beispiele:
- `pre_watch=5m`
- `event_watch=30s`
- `close_before=60s`

---

## 5) Verhalten (ganz kurz)
- **Pre‑Event** kann eine Position öffnen
- **Pre‑Trade** wird **automatisch geschlossen** vor dem Event (`close_before`)
- **Event‑Trade** startet separat zur Event‑Zeit

---

## 6) Defaults (wenn du nichts angibst)
- `event_trigger` = Bot‑Setting `InpTriggerATRPercent`
- `event_watch` = Bot‑Setting `InpEventWatchSeconds`
- `event_tp_atr` / `event_sl_atr` = Bot‑Settings `InpTrailingTP_ATR / InpTrailingSL_ATR`
- `pre_trigger` = 40
- `pre_watch` = 10m
- `close_before` = 60s
- `pre_tp_atr` = 0.3
- `pre_sl_atr` = 0.5

---

## 7) Tipps
- Nur **klare Events** eintragen (hohe Impact‑Daten)
- Ein Symbol pro Zeile
- Datum/Uhrzeit immer exakt UTC Zeit

