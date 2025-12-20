# 📊 Sharrow Wochenausblick - Forex Market Analysis System

**Version:** HYBRID v2.0
**Status:** Production-Ready ✅
**Kritikalität:** 🔴 **HÖCHSTE PRIORITÄT** - Ohne Wochenausblick = Verlustreiche Trades!
**Entwickler:** Shinpai-AI von Hannes Kell

---

## 🎯 WAS IST DER WOCHENAUSBLICK?

Der Wochenausblick ist ein **AI-gestütztes Forex-Analyse-System**, das die kommende Handelswoche analysiert und für **jedes aktive Währungspaar** eine Entscheidung trifft:

- **🟢 SWING-Mode:** Trends laufen lassen mit Trailing Stop (swing = true)
- **🔴 ATR-Mode:** Defensive trades mit fixen TP-Zielen (swing = false, TP je nach Volatilität)

**Das Ziel:** Sharrow läuft nicht blind, sondern **passt sich dem Markt an!**

---

## ⚠️ WARUM IST DER WOCHENAUSBLICK KRITISCH?

### **DIE GEFAHR: Stumpfes Trading**

Wenn Sharrow **ohne Wochenausblick** läuft:
- ❌ Tradet blind in High-Impact-Events (FOMC, NFP, Zentralbank-Meetings)
- ❌ Nutzt falsche swing/TP-Settings (Swing in Chaos-Phasen = Verluste!)
- ❌ Ignoriert fundamentale Marktveränderungen
- ❌ Hält Runner in Range-Bound-Markets (keine Trends = kein Profit!)

**Ergebnis:** 💸 Verlustreiche Trades garantiert!

### **DIE LÖSUNG: Wöchentliche Markt-Analyse**

Mit Wochenausblick:
- ✅ Symbol-spezifische Anpassung (EUR/USD ≠ GBP/JPY!)
- ✅ Event-basierte Trading-Strategie
- ✅ Trend-Erkennung für optimale TP-Settings
- ✅ Risiko-Minimierung in volatilen Phasen

**Ergebnis:** 🎯 Profitables, adaptives Trading!

---

## 🚨 KRITISCHE VORAUSSETZUNG

### **⚡ ES GEHT NUR MIT KI DIE INTERNET HAT!**

Der Wochenausblick ist **KEIN automatisches Python-Skript!**

**Warum?**
- Braucht Zugriff auf **Forex Factory Calendar** (Live-Daten!)
- Braucht Zugriff auf **Investing.com Economic Calendar**
- Braucht **fundamentale News-Analyse** (Geopolitik, Zentralbank-Statements)
- Braucht **technische Chart-Analyse** (Trends, Support/Resistance)

**Was du brauchst:**
- 🤖 AI-Assistent mit Internet-Zugang (z.B. Claude Code, Shidow, ChatGPT Plus)
- 🌐 Zugriff auf Forex Factory & Investing.com
- ⏱️ 30-45 Minuten Zeit für gründliche Analyse

**OHNE INTERNET = GEHT NICHT!** ⚠️

---

## 📅 WANN MUSS DER WOCHENAUSBLICK GEMACHT WERDEN?

### **⏰ ZEITFENSTER (ZWINGEND!):**

**Von:** Freitag nach Marktschluss (ca. 22:00 Uhr MEZ)
**Bis:** Sonntag 23:00 Uhr (spätestens!)

**Warum dieses Fenster?**
- ✅ Freitag: Handelswoche abgeschlossen → Alle Daten vorhanden
- ✅ Wochenende: Ruhe für gründliche Analyse
- ✅ Sonntag 23 Uhr: Forex-Markt öffnet wieder → Settings müssen fertig sein!

**⚠️ WICHTIG:** Wenn du den Wochenausblick skipst, tradet Sharrow blind in die neue Woche!

---

## 🔧 WIE FUNKTIONIERT DER WOCHENAUSBLICK?

### **SCHRITT 1: Vorbereitung**

1. Öffne deine AI mit Internet-Zugang
2. Lade deine **Sharrow-Config-Datei** (z.B. `TKB-config.json`)
3. Extrahiere alle aktiven Symbole aus `"symbols": { ... }`
   - Anzahl variiert je nach deinem Setup

---

### **SCHRITT 2: Market Research (30-45 Minuten)**

Für **JEDES Währungspaar** einzeln analysieren:

#### **📰 1. Wirtschaftskalender (High-Impact Events)**
- FOMC Meetings (US-Dollar pairs!)
- NFP (Non-Farm Payrolls)
- CPI / PPI (Inflation data)
- Zentralbank-Meetings (ECB, BOE, BOJ, etc.)

**Symbol-spezifisch:**
- EUR/USD → ECB + Fed Events
- GBP/JPY → BOE + BOJ Events
- AUD/NZD → RBA + RBNZ Events

**Datenquellen:**
- https://www.forexfactory.com/calendar
- https://www.investing.com/economic-calendar/

---

#### **📈 2. Technische Analyse**
- Trends bewerten (klare Richtung vs. range-bound)
- Support/Resistance Levels identifizieren
- Breakout-Potenzial checken

**Symbol-spezifisch:**
Jedes Pair einzeln bewerten! EUR/USD kann trendy sein, während GBP/CAD range-bound ist!

---

#### **📊 3. Volatilität**
- ATR-Prognosen
- VIX-Level
- Erwartete Marktbewegungen

**Symbol-spezifisch:**
Welche Pairs haben high/low volatility diese Woche?

---

#### **🌍 4. Fundamentals**
- Geopolitik (Kriege, Wahlen, Handelskonflikte)
- Zentralbank-Statements (hawkish/dovish)
- Wirtschaftsdaten-Erwartungen

**Symbol-spezifisch:**
- USD-Pairs vs. Non-USD-Pairs
- EUR/GBP hat kein USD-Risk!
- Commodity-Pairs (AUD/CAD) haben eigene Drivers!

---

### **SCHRITT 3: Entscheidung pro Symbol**

Für jedes Währungspaar entscheiden:

#### **🔴 ATR-MODE (Defensive Trading)**

**WANN:**
- ❌ Viele High-Impact Events diese Woche
- ❌ Range-bound markets (keine klaren Trends)
- ❌ Hohe/unpredictable Volatilität erwartet
- ❌ Policy uncertainty, geopolitische Spannungen

**TRADING-CONFIG:**
- **swing = false** (in config)
- **TP anpassen** (im tp_setting Bereich):
  - Geringe Volatilität + ruhiger Markt → TP = 1 ATR
  - Hohe Volatilität + ruhiger Markt → TP = 2 ATR (oder höher, aber nicht übertreiben!)
- Exit: Schnell raus bei fixen TP-Zielen
- Ziel: Kapitalsicherung, keine Runner-Risks

---

#### **🟢 SWING-MODE (Trend-Following Trading)**

**WANN:**
- ✅ Klare Trends (strong directional moves)
- ✅ Wenig/keine Major-Events diese Woche
- ✅ Stabile bis moderate Volatilität
- ✅ Gute technische Setups (Breakouts, starke Support/Resistance)

**TRADING-CONFIG:**
- **swing = true** (in config)
- **TP NICHT anfassen!** (Läuft mit Trailing Stop!)
- Exit: Trailing Stop automatisch
- Ziel: Runner laufen lassen, große Gewinne mitnehmen

---

### **SCHRITT 4: Output im HYBRID-Format**

Die AI liefert die Analyse im **HYBRID v2.0 Format:**

#### **Format 1: GENERELL + EXCEPTIONS (Standard!)**

```
SWING! 🟢

Ausnahmen (ATR!):
- GBP/USD: BOE Meeting (Do)
- USD/JPY: BOJ Intervention Risk
```

**Bedeutung:** Alle Symbole auf SWING, außer die genannten → Die auf ATR!

---

#### **Format 2: NUR EXCEPTIONS (bei homogenem Markt)**

```
ATR! ⚠️

Ausnahmen (SWING ok):
- EUR/GBP: Kein USD-Risk, stable
- AUD/CAD: Commodity-driven, clear trend
```

**Bedeutung:** Alle Symbole auf ATR, außer die genannten → Die auf SWING!

---

#### **Format 3: ALLE GLEICH (selten!)**

```
SWING! (Ruhige Woche, klare Trends!)
```

ODER

```
ATR! (FOMC + hohe Volatilität überall!)
```

**Bedeutung:** Alle 21 Symbole bekommen das gleiche Setting!

---

## 🔧 UMSETZUNG IN SHARROW

Nach dem Wochenausblick:

### **1. SWING-Mode Symbole:**
- In config: **swing = true** setzen
- **TP NICHT anfassen!** (Trailing läuft automatisch!)

### **2. ATR-Mode Symbole:**
- In config: **swing = false** setzen
- Im **tp_setting Bereich** TP anpassen:
  - Geringe Volatilität + ruhiger Markt → TP = 1 ATR
  - Hohe Volatilität + ruhiger Markt → TP = 2 ATR (max!)

### **3. NOTFALL: Markt-Katastrophe Woche**

Wenn die KI sagt: "Markt wird unberechenbar!" → **Ganze Woche aussetzen!**
- In config (ganz oben): **trade_active = false**
- Sharrow macht GAR NICHTS die ganze Woche!
- Nächste Woche: **trade_active = true** wieder aktivieren

### **4. NOTFALL: Einzelne Katastrophen-Tage**

Wenn nur 1-2 Tage kritisch (z.B. Mi + Fr):
- **Am Tag ZUVOR** (22-23 Uhr wenn Markt zu):
  - In MT5: **Algo-Handel Häkchen entfernen**
  - Sharrow tradet nicht mehr
- **⚠️ WICHTIG:** Am nächsten Tag **Algo-Handel wieder aktivieren!**
  - Sonst passiert GAR NIX mehr!

### **5. Sharrow neu starten** mit neuen Settings!

---

## 📋 BEISPIEL-WORKFLOW

**Freitag 22:30 Uhr:**
- Markt geschlossen, Zeit für Wochenausblick!

**Samstag 10:00 Uhr:**
- AI mit Internet öffnen
- Command: "Wochenausblick"
- AI analysiert 21 Währungspaare (30-45min)

**Samstag 11:00 Uhr:**
- AI liefert HYBRID-Output:
  ```
  SWING! 🟢

  Ausnahmen (ATR!):
  - EUR/USD: FOMC Meeting (Mi)
  - GBP/USD: BOE Meeting (Do)
  ```

**Samstag 11:15 Uhr:**
- Deine **Sharrow-Config** anpassen:
  - EUR/USD: swing = false, TP = 1 ATR (ATR-Mode, geringe Volatilität)
  - GBP/USD: swing = false, TP = 1 ATR (ATR-Mode, geringe Volatilität)
  - Alle anderen: swing = true, TP nicht anfassen! (SWING-Mode)

**Sonntag 23:00 Uhr:**
- Sharrow läuft mit perfekten Settings in die neue Woche! 🎯

---

## 🎓 FAZIT

### **Der Wochenausblick ist:**
- ✅ Das wichtigste Tool für profitables Sharrow-Trading
- ✅ AI-gestützt, nicht automatisiert
- ✅ Symbol-spezifisch, nicht pauschal
- ✅ Event-basiert, nicht starr

### **Ohne Wochenausblick:**
- ❌ Sharrow tradet blind
- ❌ Falsche swing/TP-Settings
- ❌ Verluste in Chaos-Phasen
- ❌ Verpasste Gewinne in Trend-Phasen

### **Mit Wochenausblick:**
- ✅ Adaptives Trading
- ✅ Risiko-Minimierung
- ✅ Profit-Maximierung
- ✅ Markt-Awareness

---

## 🔗 RESSOURCEN

**Datenquellen:**
- Forex Factory Calendar: https://www.forexfactory.com/calendar
- Investing.com Economic Calendar: https://www.investing.com/economic-calendar/

**Config-Datei:**
- Deine Sharrow-Konfigurationsdatei (meist `TKB-config.json` im Sharrow-Verzeichnis)

**AI-System:**
- Nutze eine AI mit Internet-Zugang (Claude Code, ChatGPT Plus, etc.)
- Command: "Wochenausblick" → AI macht die Markt-Analyse!

---

**⚡ REMEMBER:**
> "Sharrow ist intelligent - aber nicht hellsehend!
> Ohne Wochenausblick tradet er im Blindflug.
> Mit Wochenausblick tradet er mit Radar!" 🎯

---

*Made with 💚 by Shinpai-AI (Hannes Kell)*
*Für profitable, adaptive Forex-Trades!*
