# 🏹 Sharrow Trading System v1.5 BETA

<p align="center">
  <img src="sharrow-logo.png" alt="Sharrow Logo" width="200" />
</p>

**AI-gestützter Forex & Crypto Trading Bot mit News-Awareness, Walk-Forward Training und strengem Risikomanagement.**

---

## 🎯 Überblick

Sharrow ist die Nachfolger-Version eines internen Forschungsprojekts und vereint:

- **MetaTrader‑5 Expert Advisor (MQL5)** für die Ausführung
- **Python Toolchain** für Training, News-Import und Datenaufbereitung
- **Mehrstufige Risikokontrolle** inklusive Margin-Guard, 1-Trade-Policy & Weekend-Gate
- **News-basierte Trade-Gates** mit Sentiment-Analyse
- **🎰 Casino-Engine (v1.5)** mit erweiterten Signalquellen (Modi F-H) & dynamischer Signal-Logik

Alle personenbezogenen Hinweise wurden entfernt; Branding und Credits zeigen auf **Shinpai-AI (Publisher, Hannes Kell)** und **GPT‑5 (Coder)**.

---

## 📂 Verzeichnisstruktur

```
Sharrow/
├── 4Unix/                      # Paket für Linux/Mac (Bash + Wine Support)
│   ├── Sharrow.mq5             # MT5 Expert Advisor
│   ├── SharrowReport.mq5       # Reporting / Dashboard EA
│   ├── Sharrow-Fibel.md        # Architektur- & Referenzdokument (DE)
│   ├── Sharrow-Casino.md       # 🎰 Casino-Modus Dokumentation (v1.5)
│   ├── Sharrow-Ersteinrichtung.md
│   ├── Train-KI-Bot.py         # ML-Training & Rules-Generator
│   ├── TKB-News-Bot.py         # News-Collector & Sentiment-Filter
│   ├── TKB-Data-Export.py      # Historik-Export & *_extend.csv Merge
│   ├── TKB-config.json         # Zentrales Config-File (Linux/Wine Defaults)
│   ├── RUN-*.sh                # Automation Scripts (Bash)
│   └── RUN-MT5-Log-Cleaner.sh  # Log-Cleanup
│
├── 4Windows/                   # Paket für Windows (Batch)
│   ├── Sharrow.mq5             # MT5 Expert Advisor
│   ├── SharrowReport.mq5
│   ├── Sharrow-Fibel.md
│   ├── Sharrow-Casino.md       # 🎰 Casino-Modus Dokumentation (v1.5)
│   ├── Sharrow-Ersteinrichtung.md
│   ├── Train-KI-Bot.py
│   ├── TKB-News-Bot.py
│   ├── TKB-Data-Export.py
│   ├── TKB-config.json         # Windows Defaults (Pfad, python)
│   └── RUN-*.bat               # Automation Scripts (Batch)
│
├── sharrow-logo.png            # Logo (png)
└── README.md
```

> Detaillierte Entwicklerdankesliste (`CONTRIBUTORS.md`) liegt jeweils in `4Unix/` und `4Windows/`.

---

## ⚙️ Quick Start

### 1. Repository beziehen

```bash
git clone https://github.com/Shinpai-AI/Sharrow.git
cd Sharrow
```

### 2. Konfiguration anpassen (`TKB-config.json`)

Arbeite **innerhalb des passenden OS-Pakets**:

- Linux/Mac → `4Unix/TKB-config.json`
- Windows → `4Windows/TKB-config.json`

```json
{
  "paths": {
    "mt5_path": "C:/Program Files/MetaTrader 5",
    "python_bin": "python"               // "python3" auf Linux/Mac
  },
  "api_settings": {
    "polygon":   {"enabled": false, "api_key": ""},
    "forexnews": {"enabled": false, "api_key": ""},
    "cryptonews":{"enabled": false, "api_key": ""}
  },
  "telegram": {
    "enabled": false,
    "bot_token": "",
    "chat_id": ""
  }
}
```

> API-Keys & Telegram-Daten sind absichtlich leer – bitte eigene Werte setzen.

### 3. Python-Abhängigkeiten installieren

```bash
# Linux/Mac
pip3 install numpy pandas scikit-learn scipy joblib requests

# Windows
pip install numpy pandas scikit-learn scipy joblib requests
```

### 4. Dateien in MT5 einspielen

1. Aus dem jeweiligen OS-Ordner (`4Unix` oder `4Windows`) **Sharrow.mq5** & **SharrowReport.mq5** nach `MQL5/Experts/` kopieren
2. MetaEditor öffnen → beide Dateien (F7) kompilieren
3. Rules/News-Dateien werden durch die Python-Tools erzeugt (siehe Workflow)

### 5. Automation ausführen

```bash
# Linux/Mac (Ordner 4Unix)
cd 4Unix
./RUN-data-refresh.sh
./RUN-news.sh
./RUN-train.sh

# Windows (Ordner 4Windows)
cd 4Windows
RUN-data-refresh.bat
RUN-news.bat
RUN-train.bat
```

> Optional: `RUN-MT5-Log-Cleaner.(sh|bat)` regelmäßig einplanen.

### 6. EA an Chart anhängen

1. MT5 → gewünschtes Symbol auf **H1** öffnen
2. `Sharrow` aus Navigator auf den Chart ziehen
3. AutoTrading aktivieren (Ctrl+E) und Journal überwachen

---

## 🔧 Konfigurationshinweise

### Pfade (`paths`)
- `mt5_path`: Installation von MT5 (Windows oder Wine)
- `mt5_files_subpath` / `mt5_logs_subpath`: Standard `MQL5/Files` & `MQL5/Logs`
- `python_bin`: Pfad zum Interpreter (z. B. `python3`, virtuelle Umgebung etc.)

### Account & Risiko (`account` Block)
- `starting_balance`, `risk_percent`, `currency` definieren das Risikomodell für Lot-Berechnung.
- `min_sl_pips`, `leverage`, `max_loss_percent` steuern zusätzliche Guards.

### News-Integration (`api_settings`)
- `enabled`: Nur aktivieren, wenn Key eingetragen ist.
- `rate_limit` & `request_delay`: Provider-spezifische Limits einhalten.

### Telegram (optional)
- `enabled: true` und Token/Chat-ID setzen, falls Alerts gewünscht sind.
- Ohne Token bleibt das Feature inaktiv.

---

## 🔄 Empfohlene Automatisierung

| Job                  | Ziel                                    | Intervall        |
|----------------------|-----------------------------------------|------------------|
| `RUN-data-refresh`   | Historische CSVs ersetzen, *_extend kopieren | Monatlich (oder manuell) |
| `RUN-news`           | News-Feeds aktualisieren                | Stündlich        |
| `RUN-train`          | Regeln & Modelle neu trainieren         | Wöchentlich      |
| `RUN-MT5-Log-Cleaner`| MT5-Logs bereinigen                     | Nach Bedarf      |

Automatisierung über cron (Linux) oder Task Scheduler (Windows) wird empfohlen.

---

## 🧠 Credits

- **Publisher:** Shinpai-AI / Hannes Kell
- **Coder:** GPT-5 (OpenAI)
- **Stack:** MetaTrader 5 (MQL5), Python 3.x, REST APIs (Polygon.io, ForexNewsAPI, CryptoNewsAPI)

Besonderer Dank gilt der Open-Source-Community und allen Tool-Herstellern, deren Arbeit hier genutzt wird.

---

## ⚠️ Haftungsausschluss

Dieses Projekt stellt keinen Anlage- oder Finanzrat dar. Handel an Finanzmärkten ist riskant – nutze Sharrow verantwortungsbewusst, auf eigene Gefahr und vorzugsweise erst nach Backtests & Demotrading.

---

## 📬 Support & Feedback

- 🗨️ Issues & Feature Requests: [GitHub Issues](https://github.com/Shinpai-AI/Sharrow/issues)
- 🌐 Website: [shinpai.de](https://shinpai.de)
- 📧 Kontakt: info@shinpai.de

Pull Requests sind derzeit geschlossen; Bugreports, Verbesserungsvorschläge und Dokumentationsbeiträge sind jedoch willkommen.

---

**Letztes Update:** November 2025 (v1.5 Casino-Release)

*Made with ❤️ by Shinpai-AI & GPT‑5.*
