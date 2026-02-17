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

---

## 8) Sharrow-Setting.txt (Optional, ab v3.04)

**Zweck:** Bot-Einstellungen persistent speichern, damit sie nach VPS-Neustarts erhalten bleiben. Überschreibt die MT5-Input-Parameter wenn vorhanden.

**Datei:** Sharrow-Setting.txt

**Pfad:** Gleicher Ordner wie Rules-Master.txt (MQL5/Files)

### Verhalten

- Datei **nicht vorhanden** → Kein Problem, Bot nutzt die MT5-Input-Defaults
- Datei **vorhanden und korrekt** → Settings überschreiben die Input-Defaults
- Datei **vorhanden aber gesperrt** → Bot wartet 5s und probiert erneut (max 5 Min)
- Datei **vorhanden aber Inhalt fehlerhaft** → FATAL, Bot stoppt

### Format

Eine Zeile pro Setting, Key=Value. Kommentare mit `//` am Zeilenanfang.

```
// Sharrow-Setting.txt – Bot-Einstellungen
// Nur angegebene Werte werden überschrieben

stake_mode=percent
stake_percent=100.0
stake_fixed=0.0
trailing=true
webticker=false
webticker_log=Goldjunge-state.log
webticker_interval=60
```

### Unterstützte Keys

| Key | Werte | Beschreibung |
|-----|-------|-------------|
| stake_mode | `percent` oder `fixed` | Einsatz-Berechnung |
| stake_percent | 0-100 (z.B. `100.0`) | Einsatz in % vom Konto |
| stake_fixed | Betrag (z.B. `50.0`) | Fixer Einsatz in EUR |
| trailing | `true`/`false`/`on`/`off`/`1`/`0` | Trailing SL/TP an/aus |
| webticker | `true`/`false`/`on`/`off`/`1`/`0` | WebTicker an/aus |
| webticker_log | Dateiname (z.B. `Goldjunge-state.log`) | WebTicker Log-Datei |
| webticker_interval | Minuten (z.B. `60`) | Snapshot-Intervall |

### Tipps

- Nur die Settings eintragen, die vom Default abweichen sollen
- Nicht eingetragene Keys behalten den MT5-Input-Default
- Datei löschen = zurück zu Input-Defaults
- Bei VPS-Betrieb: Settings-Datei per Cloud-Sync oder Symlink einbinden (wie Rules-Master)

---

## 9) Multi-Instanz & File-Locking (ab v3.04)

Wenn mehrere SharrowLOL-Instanzen gleichzeitig starten (z.B. auf verschiedenen Charts), greifen alle auf die gleichen Dateien zu.

### Problem (vor v3.04)

Erste Instanz öffnet die Datei → alle weiteren bekommen "Datei gesperrt" → FATAL.

### Lösung (ab v3.04)

- **FILE_SHARE_READ:** Alle Datei-Zugriffe erlauben paralleles Lesen
- **Retry-Loop:** Wenn eine Datei trotzdem gesperrt ist → 5 Sekunden warten, erneut versuchen
- **Max 60 Versuche** (= 5 Minuten), dann FATAL
- Gilt für Rules-Master.txt UND Sharrow-Setting.txt

### Ablauf bei Multi-Instanz-Start

```
Instanz 1 (AUDUSD): Settings laden ✅ → Rules laden ✅ → Läuft!
Instanz 2 (NAS100):  Settings gesperrt → 5s → Retry ✅ → Rules laden ✅ → Läuft!
Instanz 3 (SPX500):  Settings gesperrt → 5s → Retry ✅ → Rules laden ✅ → Läuft!
```

### Init-Reihenfolge (v3.04)

1. ATR-Handle erstellen
2. Sharrow-Setting.txt laden (optional, mit Retry)
3. Settings validieren (z.B. stake_percent Bereich)
4. Rules-Master.txt laden (Pflicht, mit Retry)
5. WebTicker initialisieren (falls aktiv)
6. Bot bereit
