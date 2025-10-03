# 🏹 Sharrow Trading System v1.0 BETA

**AI-Powered Forex & Crypto Trading Bot with Smart News Integration**

---

## 🎯 What is Sharrow?

Sharrow is an advanced, AI-driven trading system for MetaTrader 5 that combines:
- **Machine Learning** - Decision tree-based strategy optimization
- **News-Aware Trading** - Real-time news filtering to avoid volatile events
- **Risk Management** - Multi-layered protection (Margin-Clamp, 1-Trade-Policy, Weekend-Gate)
- **Multi-Asset Support** - Forex pairs & Crypto (extensible to commodities)
- **Fully Autonomous** - Self-optimizing training pipeline with walk-forward validation

---

## ✨ Key Features

### 🤖 AI-Powered Strategy
- **Decision Tree Classifier** - Optimized for each symbol individually
- **Statistical Features** - Stochastic, ADX, ATR, Weibull/Poisson probabilities
- **Walk-Forward Validation** - Prevents overfitting with rolling time windows
- **Auto-Retraining** - Weekly update cycle keeps strategy fresh

### 📰 Smart News Integration
- **Multi-API Support** - ForexNewsAPI, CryptoNewsAPI, Polygon.io
- **Asset-Specific Filtering** - Only relevant news for each symbol
- **Sentiment Analysis** - Positive/negative keyword matching
- **Trade Gating** - Blocks trades during high-impact events

### 🛡️ Advanced Risk Management
- **Margin Clamp** - Prevents overleveraging (configurable threshold)
- **1-Trade-Policy** - Only one trade per symbol at a time
- **Weekend Protection** - Auto-closes positions before market close
- **Dynamic Position Sizing** - Risk-based lot calculation

### 📊 Multi-Timeframe Analysis
- **H1 Primary Timeframe** - Core trading logic
- **M15/M1 Export** - Additional data for model training
- **CSV Export** - Clean, standardized format for analysis

---

## 📂 Project Structure

```
Sharrow/
├── docs/                          # Documentation
│   ├── Patch-History.md          # Version changelog
│   ├── Patch-Info4KI.md          # AI assistant workflow guide
│   ├── Goldjunge-Fibel.md        # Original project documentation
│   └── Goldjunge-Ersteinrichtung.md  # Setup guide (German)
│
├── 4Unix/                         # Linux/Mac Version
│   ├── Sharrow.mq5               # MT5 Expert Advisor
│   ├── GoldReport.mq5            # Reporting tool
│   ├── TKB-config.json           # System configuration
│   ├── RUN-*.sh                  # Automation scripts (bash)
│   └── *.py                      # Python tools (training, news, data)
│
├── 4Windows/                      # Windows Version
│   ├── Sharrow.mq5               # MT5 Expert Advisor
│   ├── GoldReport.mq5            # Reporting tool
│   ├── TKB-config.json           # System configuration
│   ├── RUN-*.bat                 # Automation scripts (batch)
│   └── *.py                      # Python tools (training, news, data)
│
└── README.md                      # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **MetaTrader 5** (any broker)
- **Python 3.8+** with packages:
  - `numpy`, `pandas`, `scikit-learn`, `scipy`, `joblib`, `requests`
- **API Keys** (optional, for news integration):
  - [Polygon.io](https://polygon.io/) (free tier available)
  - [ForexNewsAPI.com](https://forexnewsapi.com/)
  - [CryptoNewsAPI.com](https://cryptonews-api.com/)

### Installation

1. **Download Sharrow**
   - For Linux/Mac: Extract `Sharrow-v1.0-Beta-Unix.zip`
   - For Windows: Extract `Sharrow-v1.0-Beta-Windows.zip`

2. **Configure TKB-config.json**
   ```json
   {
     "paths": {
       "mt5_path": "YOUR_MT5_INSTALLATION_PATH",
       "python_bin": "python3"  // or "python" on Windows
     },
     "api_settings": {
       "polygon": {"api_key": "YOUR_POLYGON_KEY"},
       "forexnews": {"api_key": "YOUR_FOREXNEWS_KEY"},
       "cryptonews": {"api_key": "YOUR_CRYPTONEWS_KEY"}
     },
     "telegram": {
       "enabled": true,  // optional
       "bot_token": "YOUR_BOT_TOKEN",
       "chat_id": "YOUR_CHAT_ID"
     }
   }
   ```

3. **Install Python Dependencies**
   ```bash
   # Linux/Mac
   pip3 install numpy pandas scikit-learn scipy joblib requests

   # Windows
   pip install numpy pandas scikit-learn scipy joblib requests
   ```

4. **Place Files in MT5**
   - Copy `Sharrow.mq5` and `GoldReport.mq5` to `MT5_DATA_FOLDER/MQL5/Experts/`
   - Compile in MetaEditor (F7)

5. **Run Initial Training**
   ```bash
   # Linux/Mac
   ./RUN-weekly-update.sh

   # Windows
   RUN-weekly-update.bat
   ```

6. **Attach Sharrow.mq5 to Chart**
   - Open H1 chart for your symbol (e.g., EURUSD)
   - Drag Sharrow.mq5 from Navigator → Expert Advisors
   - Enable Auto-Trading (Ctrl+E)

---

## ⚙️ Configuration Guide

### Essential Settings (TKB-config.json)

#### Paths
- **mt5_path**: Absolute path to your MT5 installation
  - Windows: `C:/Program Files/MetaTrader 5`
  - Linux: `/home/USERNAME/.wine/drive_c/Program Files/MetaTrader 5`
- **python_bin**: Python executable (`python3` or `python`)

#### Account Settings
- **starting_balance**: Initial capital (EUR)
- **risk_percent**: Risk per trade (default: 5%)
- **currency**: Account currency (EUR, USD, etc.)

#### News Integration
- **enabled**: Set to `true` for each API you want to use
- **api_key**: Your API key from the provider
- **rate_limit**: Requests per minute (respect API limits!)

#### Telegram Notifications (Optional)
- Get bot token from [@BotFather](https://t.me/BotFather)
- Get chat_id from [@userinfobot](https://t.me/userinfobot)

---

## 🔄 Automated Workflows

### Hourly News Update
Updates news files for real-time trade gating.

```bash
# Linux/Mac
./RUN-hourly-news.sh

# Windows
RUN-hourly-news.bat
```

**Recommended:** Schedule with cron/Task Scheduler every hour.

---

### Weekly Training Update
Retrains models with latest data, updates trading rules.

```bash
# Linux/Mac
./RUN-weekly-update.sh

# Windows
RUN-weekly-update.bat
```

**Recommended:** Run every Sunday night.

---

### Monthly Data Refresh
Purges old CSVs, downloads fresh historical data.

```bash
# Linux/Mac
./RUN-data-refresh.sh

# Windows
RUN-data-refresh.bat
```

**Recommended:** Run on 1st of each month.

---

## 📊 How It Works

### 1. Data Collection
- MT5 exports H1/M15/M1 historical data as CSV
- Python scripts standardize and validate data
- Polygon.io API fills gaps in historical data (optional)

### 2. Feature Engineering
- **Technical Indicators**: Stochastic, ADX, ATR
- **Statistical Probabilities**: Weibull, Poisson distributions
- **Volume Analysis**: Spike detection, percentile-based filtering

### 3. Model Training
- **Sklearn Decision Tree Classifier** optimized per symbol
- **Walk-Forward Validation** prevents overfitting
- **Hyperparameter Tuning**: TP/SL multipliers, quality filters

### 4. Rule Generation
- Best-performing model exported as text-based decision tree
- Rules saved to `rules/rules_SYMBOL.txt`
- MT5 EA reads rules on startup

### 5. Live Trading
- EA evaluates current market conditions against rules
- News filter checks for high-impact events
- If both gates pass: Execute trade with calculated SL/TP
- Risk manager enforces position limits

---

## 🛡️ Risk Warnings

⚠️ **BETA SOFTWARE** - This is a v1.0 BETA release. Use at your own risk!

- **Demo First**: Always test on demo account before going live
- **Monitor Closely**: Check logs daily for unexpected behavior
- **API Limits**: Respect rate limits to avoid bans
- **News Accuracy**: News APIs may have delays or missing events
- **No Guarantees**: Past performance does not guarantee future results

---

## 📈 Performance Tracking

### Logs & Reports
- **TKB.log** - Training pipeline detailed logs
- **hourly-news.log** - News update operations
- **weekly_update.log** - Training execution logs
- **Sharrow-Info.txt** - MT5 EA runtime logs (in MT5/Files/)

### Telegram Notifications (if enabled)
- Trade execution confirmations
- Daily/weekly performance summaries
- Error alerts

---

## 🤝 Contributing

This project is currently in BETA. Bug reports and feature suggestions welcome via GitHub Issues!

---

## 📜 License

This project is released under the MIT License. See LICENSE file for details.

---

## 🙏 Acknowledgments

- Built on principles of systematic trading and quantitative finance
- News APIs: Polygon.io, ForexNewsAPI, CryptoNewsAPI
- ML Framework: scikit-learn

---

## 📞 Support

### Community Support (Free)
- **Issues**: [GitHub Issues](https://github.com/Shinpai-AI/Sharrow/issues) - Bug reports & feature requests
- **Discussions**: [GitHub Discussions](https://github.com/Shinpai-AI/Sharrow/discussions) - General questions & strategy talk
- **Documentation**: See `docs/` folder - Comprehensive guides

### Official Support
- **Email**: [info@shinpai.de](mailto:info@shinpai.de) - Direct support for setup & troubleshooting
- **📞 Hotline**: *Coming with v2.0 stable release!* - Premium phone support for enterprise users

> **Roadmap**: v2.0 will introduce professional support tiers including priority email, live chat, and dedicated hotline support.

---

**🏹 Sharrow - Trade Smarter, Not Harder**

*Made with data-driven discipline and AI precision.*
