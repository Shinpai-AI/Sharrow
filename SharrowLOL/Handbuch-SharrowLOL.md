# SharrowLOL Handbuch

> **Version:** 3.0 | **Stand:** 06.02.2026 | **Autor:** Shinpai-AI

---

## 1. Start-Check

| Voraussetzung | Details                                        |
|---------------|------------------------------------------------|
| MT5           | Installiert (Windows oder Wine/Win-VM)         |
| Broker        | Konto aktiv (z.B. NAGA)                        |
| Symbol        | Passend zum Broker (XAUUSD, NAS100, US30, ...) |
| Timeframe     | H1 (oder im Bot eingestellter TF)              |
| **Zeitzone**  | **Alle Events in UTC (Broker-Zeit!)**          |

---

## 2. Bot einsetzen (MT5)

1. MT5 öffnen
2. Chart öffnen (gewünschtes Symbol)
3. Bot **SharrowLOL** auf den Chart ziehen
4. **AutoTrading aktivieren**

> **Tipp:** Freitag 22:00 – Sonntag 23:00 Uhr = perfekte Ruhe zum Einrichten/Sync

---

## 3. Rules-Datei (Pflicht)

**Datei:** `Rules-Master.txt`
**Pfad:** `/home/shinpai/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files`

### Cloud-Workflow (empfohlen)

1. Rules in Cloud-Ordner pflegen
2. VPS sync't automatisch
3. Symlink Cloud-Datei → `MQL5/Files`

**Ergebnis:** Nur eine Datei pflegen!

---

## 4. Rules-Format

> **Eine Zeile = ein Event**

### Basis-Format

```
SYMBOL;YYYY-MM-DD HH:MM
```

### Erweitertes Format

```
SYMBOL;YYYY-MM-DD HH:MM;key=value;key=value;...
```

---

## 5. Parameter-Referenz

### Pre-Event Parameter

| Parameter      | Beschreibung                 | Beispiel       |
|----------------|------------------------------|----------------|
| `pre_time`     | Vorlauf vor Event            | `30m`, `1800s` |
| `pre_duration` | Trigger-Dauer ab Pre-Start   | `15m`          |
| `pre_trigger`  | % ATR für Trigger            | `100`          |
| `pre_tp_atr`   | Take-Profit in ATR           | `1.5`          |
| `pre_sl_atr`   | Stop-Loss in ATR             | `2.0`          |
| `pre_close`    | Sekunden vor Event schließen | `60s`          |

### Event Parameter

| Parameter               | Beschreibung                   | Beispiel |
|-------------------------|--------------------------------|----------|
| `event_duration`        | Trigger-Dauer ab Event-Start   | `30s`    |
| `event_trigger`         | % ATR für Trigger              | `15`     |
| `event_tp_atr`          | Take-Profit in ATR             | `0.8`    |
| `event_sl_atr`          | Stop-Loss in ATR               | `1.2`    |
| `event_exit_watch`      | Sharrow-Exit Überwachungsdauer | `10s`    |
| `event_exit_atr`        | ATR-Schwelle für Exit          | `0.5`    |
| `event_exit_min_profit` | Min-Profit für Exit (EUR)      | `0.01`   |

### Einheiten

| Typ           | Format            | Beispiele          |
|---------------|-------------------|--------------------|
| Trigger       | `%`               | `100`, `15`        |
| Zeit/Duration | `s`, `m`, `h`     | `30m`, `60s`, `1h` |
| TP/SL         | ATR-Multiplikator | `1.5`, `2.0`       |
| Exit-Profit   | EUR               | `0.01`, `0.1`      |

---

## 6. Vollständiges Beispiel

```
CHFJPY;2026-02-06 17:45;pre_time=30m;pre_duration=15m;pre_trigger=100;pre_tp_atr=1.5;pre_sl_atr=2.0;pre_close=60s;event_duration=30s;event_trigger=15;event_tp_atr=0.8;event_sl_atr=1.2;event_exit_watch=10s;event_exit_atr=0.5;event_exit_min_profit=0.01
```

---

## 7. Bot-Verhalten

### Pre-Event Phase

1. **Start:** `event_time - pre_time`
2. **Trigger:** Nur innerhalb `pre_duration`
3. **Auto-Close:** Position schließt `pre_close` Sekunden vor Event

### Event Phase

1. **Start:** Ab `event_time`
2. **Trigger:** Innerhalb `event_duration`
3. **Sharrow-Exit:**
   - Prüft Favor-Move innerhalb `event_exit_watch`
   - Wenn Move < `event_exit_atr × ATR` → wartet auf `event_exit_min_profit` & schließt

---

## 8. Fehlerbehandlung

| Situation           | Reaktion                                      |
|---------------------|-----------------------------------------------|
| Parameter fehlt     | Rule wird übersprungen + Warnung              |
| Keine validen Rules | Bot stoppt + **FATAL-Warnung**                |
| Rule geladen        | Detailliertes Log (Symbol, Zeit, alle Params) |

> **Wichtig:** Alle Parameter sind Pflicht – keine Defaults für kritische Werte!

---

## 9. Tipps & Best Practices

### Events finden

- Mit 2-3 KIs abgleichen (Claude, Grok, etc.)
- Nur bei **Konfirmation von allen** eintragen
- Fokus: Hohe Impact-Daten (News, Earnings)

### Parameter-Empfehlungen

| Parameter          | Empfehlung                                              |
|--------------------|---------------------------------------------------------|
| **Pre-Time**       | So früh wie möglich (30-45min → 45m nehmen)             |
| **Pre-Duration**   | Max 75% von Pre-Time (30m → max 22.5m)                  |
| **Event-Duration** | Max 30s (hart) – je nach Volatilität                    |
| **Pre TP/SL**      | Großzügig: 1-2 ATR (TP kleiner wegen Trailing, SL weit) |
| **Event TP/SL**    | 0.5-2 ATR – an Volatilität anpassen                     |
| **Min-Profit**     | Max 1 EUR, besser 0.01-0.1 EUR                          |

### Goldene Regeln

- Ein Symbol pro Zeile
- Datum/Uhrzeit **exakt in Broker-Zeit (UTC)**
- Immer alle Pflicht-Parameter angeben

---

*Erstellt: 06.02.2026 | SharrowLOL v3.0 | Shinpai-AI*
