# 🟡 Sharrow-Fibel.md
> Referenzdokument für das Sharrow-Revival – flache Struktur, volle Power

---

## 🎯 Mission & Hintergrund
- **Zielbild:** Vollautomatischer High-Winrate-Bot (95 %+) mit Volumen- und News-Gating – läuft autark auf dem VPS.
- **Historie:** Sharrow v2025-07-11 lieferte 11:7 Trades mit ~95 % Winrate. Schwachstelle: fehlende Volumen-Metriken und sensible News-Filter.
- **Reset-Strategie:** Wir bauen Sharrow als eigenständiges System neu auf. Dia bleibt als separates Experiment (besonders spannend für Krypto), liefert aber **keinen** Pflicht-Input.

---

## 🧩 Systemkomponenten (flache Struktur)
- `Sharrow/Train-KI-Bot.py` → Training & Feature-Engineering (Basis aus Sharrow-Bak, wird refactored).
- `Sharrow/Sharrow.mq5` → MetaTrader-5-Expert-Advisor für Execution.
- `Sharrow/SharrowReport.mq5` → Dashboard/Overlay (optional, später reaktivieren).
- `Sharrow/TKB-config.json` → Bot-Konfiguration (Modus, Risiko, Ziel, Telegram …).
- `Sharrow/historical_*.csv` → Historische Daten mit Volumen (per `TKB-Data-Export.py`).
- `Sharrow/news_*.json` oder `news_*.txt` → News-Snapshots (per `TKB-News-Bot.py`, ursprünglich `News-API-Bot.py`).
- `Sharrow/rules_*.txt` → Regeldateien fürs MQ5-Interface.
- `Sharrow/scripts/*.sh|.bat` → Autostart-Jobs (Data Refresh, Training, News Pull, Log Cleanup).

*Dia bleibt separat unter `/Trading/Dia/`; wer dessen Ergebnisse braucht, kann sie manuell spiegeln, aber Sharrow setzt nicht darauf auf.*

---

## 🔄 Datenfluss Sharrow (Autark)
1. **Daten-Refresh:** `TKB-Data-Export.py` lädt Quotes + Volumen für alle Symbole (M1/M15/H1) aus den historischen Quellen / Brokerfeeds.
2. **News-Polling:** `TKB-News-Bot.py` zieht Impact-analysierte News (Impact Score, Sentiment, Zeitstempel) und speichert sie flach im Projektordner.
3. **Training:** `Train-KI-Bot.py`
   - liest historische Preise + Volumen
   - verknüpft News-Marker & Impact-Level
   - baut Feature-Matrix inkl. Volumen-Scaling und News-Timelag
   - trainiert ML-Modelle (Vorversion nutzte sklearn/XGBoost; genaue Pipeline TBD)
   - schreibt `rules_SYMBOL.txt` + Event-Limits in den Projektordner
4. **Execution:** `Sharrow.mq5`
   - lädt die Rules + News-Flags beim Chartstart
   - bewertet Live-Volumen vs. Schwellen
   - setzt Orders, verwaltet Stops, schreibt Logs, feuert Telegram Updates

---

## 📐 Schwellen & Volume-Logic (Draft)
- **Volumen-Metriken:**
  - `volume_ratio = volume_current / SMA(volume, n)`
  - `volume_spike` Flag (≥ 1.8× Durchschnitt)
  - `delta_volume = volume_current - volume_prev`
- **News-Filter:**
  - Impact-Level (High/Medium/Low)
  - Sentiment (`bullish/bearish/neutral`)
  - Cooldown-Fenster (z. B. 30 min vor/10 min nach High-Impact)
- **Entry Gate:**
  - Regel-Signal **UND** Volumen ≥ Schwelle **UND** News erlaubt
- **Lot-Sizing:**
  - Config-Modus (Account/Risk/Fixed/Target)
  - Optional: Lot-Multiplikator `lot_base * min(volume_ratio, max_mult)`
- **Fail-Safe:** Fehlende Volumen- oder Newsdaten ⇒ Fallback `0.01 lot` + Warnlog.

TODO: konkrete Schwellen aus Backtests bestimmen (`TH_volume_spike`, `ImpactBlockList`, `volume_ratio_decay`).

---

## 🛠️ Arbeitsplan Sharrow Revival
1. **Code-Import:** Beste Teile aus `Sharrow-Bak/` (Train-KI-Bot, News-Bot, MQ5) übernehmen.
2. **Refactor & Cleanup:**
   - Volumen-Feature-Engineering sauber einbauen
   - Config-Felder entschlacken
   - Logging + Exception Handling modernisieren
3. **Automation:** Skripte so umbenennen, dass sie direkt im VPS Autostart funktionieren (`RUN-data-refresh.sh`, `RUN-train.sh`, `RUN-news.sh`, `RUN-mt5-log-clean.sh`).
4. **Docs erweitern:**
   - `Sharrow-Ersteinrichtung.md` (Quickstart jetzt, später detailliert)
   - Performance Benchmarks / Backtest-Guide (Nachgelagert)
5. **Testing & Deploy:**
   - Wine/Windows Testlauf
   - VPS-Deployment (Ordner kopieren, Config anpassen, Autostart setzen)

---

## 🧭 Entscheidungsprinzipien (Clean Girl Sharrow Edition)
- **Flat over Pretty:** Keine überflüssigen Unterordner, solange Skripte alles finden.
- **Autostart-Ready:** Dateinamen so lassen, dass der VPS sofort loslegt.
- **Backup Bewahren:** `Sharrow-Bak` bleibt unverändert als Referenz.
- **Iterativ:** Doku → Skripte → Training → EA → QA.

---

## 📝 Offene Fragen
- Welche ML-Kombination bringt die stabile Winrate zurück? (XGBoost + Logistic? Ensemble?)
- Welche Symbole sind diesmal Fokus? (FX? Indizes? Krypto optional?)
- VPS-Autostart: systemd? Windows Task Scheduler? (entscheiden, wenn Infrastruktur steht)
- Telegram/Discord Alerts? Welche Channels noch relevant?

---

**Next Action:** `Sharrow-Ersteinrichtung.md` als Quickstart-Skelett schreiben & Config-Mapping vorbereiten.

Bussi auf Nussi & let’s make finance magic! ✧*:･ﾟ✧(◕‿◕)✧*:･ﾟ✧
