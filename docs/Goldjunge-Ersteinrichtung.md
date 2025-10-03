# ⚙️ Goldjunge-Ersteinrichtung.md (Draft)
> Quickstart-Skelett – wird nach Umsetzung der Codebasis Schritt für Schritt erweitert

---

## 0. Voraussetzungen
- MetaTrader 5 (lokal via Wine oder direkt auf dem Windows/VPS-Setup)
- Python 3.10+ mit benötigten Libraries (siehe `requirements.txt` – TODO)
- Zugriff auf Broker-Datenfeed für Export-Skripte
- Telegram Bot + Chat-ID (optional, für Alerts)

---

## 1. Projekt kopieren
1. Gesamten Ordner `Trading/Goldjunge/` auf den Zielrechner/VPS kopieren.
2. Schreibrechte prüfen (Autostart-Skripte müssen Logs erstellen dürfen).
3. Backup behalten (`Goldjunge-Bak/` nicht überschreiben!).

---

## 2. Config anpassen (`TKB-config.json`)
- Risiko-Modus wählen (Account / Fixed / Target).
- Symbolliste & Timeframes definieren.
- Volumen- und News-Schwellen prüfen (`TH_volume_spike`, `impact_blocklist`).
- `paths`-Bereich schlank halten: nur `mt5_path`, `mt5_files_subpath`, `mt5_logs_subpath`, `python_bin` anpassen.
- Telegram-Parameter setzen, falls Alerts gewünscht.

*TODO: Struktur & Defaults dokumentieren, sobald Config finalisiert ist.*

---

## 3. Skripte in Autostart (VPS)
- `RUN-data-refresh.sh` bzw. `.bat` → Historische Daten & Volumen aktualisieren.
- `RUN-news.sh` → News-API abrufen.
- `RUN-train.sh` → ML-Training + Rule-Update.
- `RUN-mt5-log-clean.sh` → Housekeeping.

**Hinweis:** Für systemd/Task Scheduler müssen wir noch Templates bauen (TODO).

---

## 4. MetaTrader 5 vorbereiten
1. `Goldjunge.mq5` und `GoldReport.mq5` nach `MQL5/Experts/` kopieren.
2. `rules_*.txt` & `news_*.txt` in den Watch-Verzeichnis-Pfad legen (TODO: finalen Pfad definieren, z. B. `MQL5/Files/Goldjunge/`).
3. EA auf gewünschtem Chart/Timeframe (z. B. H1) aktivieren.
4. Lot-Anpassung durch Config prüfen (Journal + Telegram beobachten).

---

## 5. Erstes Training & Dry-Run
1. `python Train-KI-Bot.py` manuell ausführen und Logs prüfen.
2. Sicherstellen, dass Rules & News-Dateien aktualisiert wurden.
3. MT5 im Strategy Tester mit den generierten Regeln laufen lassen.
4. Ergebnismatrix mit alten Benchmarks vergleichen (Winrate, Profit, Drawdown).

---

## 6. Go-Live Checkliste (TODO)
- ✅ VPS Autostart läuft
- ✅ Telegram Alerts getestet
- ✅ Log-Rotation aktiv
- ✅ Backup-Plan für Rules/Config
- ✅ Monitoring-Notizen (wann checken, welche KPIs?)

*Diese Sektion wird ergänzt, sobald das neue System final steht.*

---

## Hinweise
- Dieses Dokument ist absichtlich knapp – Priorität liegt auf flacher Struktur & schneller Deployment-Fähigkeit.
- Alle TODOs frühzeitig ergänzen, sobald Implementierung abgeschlossen ist.
- Falls Dia-Module testweise genutzt werden sollen, separat dokumentieren – nicht in den Standard-Setup mischen.

Bussi auf Nussi, wir bringen Goldjunge zurück ins Rampenlicht! ✧*:･ﾟ✧(◕‿◕)✧*:･ﾟ✧
