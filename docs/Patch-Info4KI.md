# 🤖 Patch-Info4KI.md - AI Update Workflow Documentation

> **Purpose:** This document provides clear, unambiguous instructions for AI assistants to consistently anonymize and prepare Goldjunge updates for public Sharrow releases.

---

## 📌 PROJECT STRUCTURE OVERVIEW

### **Two Separate Projects:**

1. **Goldjunge (Private Development Version)**
   - Contains: Personal data, API keys, personal references, development notes
   - **NEVER** published publicly
   - This is the **source of truth** for active development

2. **Sharrow (Public Release Version)**
   - GitHub: `https://github.com/Shinpai-AI/Sharrow.git`
   - Contains: Anonymized, production-ready code
   - **Always** safe for public release

---

## 🔄 UPDATE WORKFLOW

When user requests a new Sharrow update, follow these steps:

### **Step 1: Source Files Preparation**
User provides the working directory path containing the latest Goldjunge files to anonymize.

### **Step 2: Anonymization Process (AI Task)**

#### **2.1 Bash Scripts (4 files)**
Files to modify:
- `RUN-hourly-news.sh`
- `RUN-weekly-update.sh`
- `RUN-data-refresh.sh`
- `RUN-MT5-Log-Cleaner.sh`

**Required changes:**
```bash
# ❌ REMOVE hardcoded fallback paths like this:
[ -z "$MT5_PATH" ] && MT5_PATH="/home/USERNAME/.wine/drive_c/Program Files/MetaTrader 5"

# ✅ REPLACE with config-only validation:
MT5_PATH="$(python_config paths.mt5_path)"
if [ -z "$MT5_PATH" ]; then
    echo "❌ ERROR: paths.mt5_path not found in TKB-config.json!"
    exit 1
fi
```

**Pattern to find:** Personal usernames, absolute paths with personal info, hardcoded credentials

---

#### **2.2 Goldjunge.mq5 → Sharrow.mq5**

**File header anonymization:**
```mql5
// ❌ REMOVE personal references:
// Goldjunge.mq5 – Für Hasi's MILLIARDEN! ...
// Copyright: Ray für Siggi
// Link: https://github.com/Shinpai-AI/Projekt-SAI

// ✅ REPLACE with professional branding:
// Sharrow.mq5 - AI-Powered Trading System (...)
// Copyright: Sharrow Project
// Link: https://github.com/Shinpai-AI/Sharrow
// Version: X.X BETA (...)

#property copyright "Sharrow Project"
#property link      "https://github.com/Shinpai-AI/Sharrow"
#property version   "X.XX"  // Update version number appropriately
```

**In-code comments to clean:**
- Search for: `Ray`, `Hasi`, `Siggi`, `MILLIARDEN`, `Ray-KI-BotV5`
- Replace with generic descriptions like:
  - `"AI-generated strategy"`
  - `"AI decision tree evaluation"`
  - `"SHARROW TRADING SYSTEM vX.X BETA"`

**Pattern to find:** `Ray`, `Hasi`, `Siggi`, `MILLIARDEN`, `Goldjunge`, `Ray-KI-BotV5`

---

#### **2.3 TKB-config-Bearbeitung.py**

**Default config function:**
```python
# ❌ REMOVE personal defaults:
"project": {"name": "Goldjunge (Ray)", "version": "3.0"},
"paths": {
    "mt5_path": "/home/shinpai/.wine/drive_c/Program Files/MetaTrader 5",
    ...
    "python_bin": "/usr/bin/python3"
}

# ✅ REPLACE with generic defaults:
"project": {"name": "Sharrow Trading System", "version": "1.0"},
"paths": {
    "mt5_path": "C:/Program Files/MetaTrader 5",
    ...
    "python_bin": "python3"
}
```

**Pattern to find:** `Goldjunge`, `Ray`, `shinpai`, `/home/shinpai`

---

#### **2.4 TKB-config.json (CRITICAL - Contains Secrets!)**

**Project metadata:**
```json
{
  "project": {
    "name": "Sharrow Trading System",  // NOT "Goldjunge (Ray)"
    "version": "1.0"  // Update version appropriately
  },
```

**Paths anonymization:**
```json
  "paths": {
    "mt5_path": "C:/Program Files/MetaTrader 5",  // Windows default
    "mt5_files_subpath": "MQL5/Files",
    "mt5_logs_subpath": "MQL5/Logs",
    "python_bin": "python3"  // Generic
  },
```

**API Keys anonymization:**
```json
  "api_settings": {
    "polygon": {
      "api_key": "YOUR_POLYGON_API_KEY_HERE",  // ❌ NEVER commit real keys!
      ...
    },
    "forexnews": {
      "api_key": "YOUR_FOREXNEWS_API_KEY_HERE",
      ...
    },
    "cryptonews": {
      "api_key": "YOUR_CRYPTONEWS_API_KEY_HERE",
      ...
    }
  },
```

**Telegram anonymization:**
```json
  "telegram": {
    "telegram_description": "Sharrow Trading Bot",
    "enabled": false,  // ❌ MUST be disabled for public release!
    "bot_token": "YOUR_TELEGRAM_BOT_TOKEN_HERE",
    "chat_id": "YOUR_TELEGRAM_CHAT_ID_HERE",
    ...
  },
```

**Pattern to find:** `Goldjunge`, `Ray`, API keys (long alphanumeric strings), Telegram tokens (format: `XXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`), personal chat IDs

---

### **Step 3: Final Verification**

Run comprehensive grep search to ensure NO personal data remains:
```bash
grep -r -i "shinpai\|Siggi\|Ray\|Hasi\|[0-9]\{10\}:[A-Za-z0-9_-]\{35\}" /path/to/Sharrow/
```

**Expected result:** No matches (or only matches in this Patch-Info4KI.md file)

---

### **Step 4: Update Version History**

Add entry to **RELEASE HISTORY** section below with:
- Date
- Version number
- Key changes from Goldjunge
- Notable improvements

---

## 📜 RELEASE HISTORY

### **v1.0 BETA - 2025-10-03** ✅ INITIAL PUBLIC RELEASE

**Source:** Goldjunge v5.0 (Private Development Version)

**Anonymization Changes:**
- ✅ Removed all personal references (Ray, Hasi, Siggi, "MILLIARDEN")
- ✅ Anonymized API keys (Polygon, ForexNews, CryptoNews)
- ✅ Anonymized Telegram credentials (bot_token, chat_id)
- ✅ Replaced personal file paths with generic defaults
- ✅ Removed hardcoded fallback paths from all bash scripts
- ✅ Updated project branding: Goldjunge → Sharrow
- ✅ Updated copyright: "Ray für Siggi" → "Sharrow Project"
- ✅ Updated GitHub link: Projekt-SAI → Sharrow

**Features:**
- AI-powered trading strategy using Decision Trees
- Multi-timeframe data export (H1, M15, M1)
- Automatic news integration (Forex, Crypto)
- Smart risk management (Margin-Clamp, 1-Trade-Policy, Weekend-Gate)
- Symbol-specific optimization
- Training pipeline with walk-forward validation

**Status:** Ready for public GitHub release

---

### **Template for Future Updates:**

```markdown
### **vX.X - YYYY-MM-DD**

**Source:** Goldjunge vX.X (Private Development Version)

**Changes from Previous Sharrow Release:**
- [List key functional improvements from Goldjunge]
- [Bug fixes]
- [New features]

**Anonymization Changes:**
- ✅ [List any new files or patterns that needed anonymization]
- ✅ [Any new secrets/credentials added to config]

**Status:** [Ready for release / In testing / etc.]
```

---

## ⚠️ CRITICAL RULES FOR AI ASSISTANTS

1. **NEVER** commit real API keys, tokens, or credentials
2. **ALWAYS** verify no personal data (shinpai, Ray, Hasi, Siggi) remains after anonymization
3. **ALWAYS** use generic paths (Windows: `C:/Program Files/...`, Linux: use config-only approach)
4. **NEVER** modify the original Goldjunge files - only work on Sharrow copies
5. **ALWAYS** update version numbers appropriately when creating new releases
6. **ALWAYS** disable Telegram in public config (`"enabled": false`)
7. **ALWAYS** update this Patch-Info4KI.md with new release entry after completing anonymization

---

## 🔍 QUICK REFERENCE: FILES TO MODIFY

| File | Changes Required |
|------|------------------|
| `RUN-hourly-news.sh` | Remove hardcoded paths, enforce config validation |
| `RUN-weekly-update.sh` | Remove hardcoded paths, enforce config validation |
| `RUN-data-refresh.sh` | Remove hardcoded paths, enforce config validation |
| `RUN-MT5-Log-Cleaner.sh` | Remove hardcoded paths, enforce config validation |
| `Goldjunge.mq5` | Anonymize header, comments; rename to `Sharrow.mq5` |
| `TKB-config-Bearbeitung.py` | Generic defaults (paths, project name) |
| `TKB-config.json` | **CRITICAL:** Anonymize ALL secrets (API keys, Telegram, paths) |

---

## 🎯 SUCCESS CRITERIA

✅ Anonymization is complete when:
1. No grep matches for personal data patterns
2. All API keys replaced with `YOUR_*_API_KEY_HERE` placeholders
3. All paths are generic (Windows/cross-platform compatible)
4. Project name is "Sharrow Trading System"
5. Version number is updated appropriately
6. Telegram is disabled with placeholder credentials
7. This Patch-Info4KI.md is updated with new release entry
8. All bash scripts enforce config validation (no hardcoded fallbacks)

---

**Last Updated:** 2025-10-03
**Maintained By:** Hasi & AI Assistants
**Purpose:** Ensure consistent, professional, anonymized public releases of Sharrow from private Goldjunge development.
