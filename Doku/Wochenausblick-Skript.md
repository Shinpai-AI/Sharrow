# 📊 Sharrow Wochenausblick - Forex Market Analysis System

**Version:** 3-STUFEN-SYSTEM v3.0 (HYBRID + trade_active Intelligence)
**Status:** Production-Ready ✅
**Kritikalität:** 🔴 **HÖCHSTE PRIORITÄT** - Ohne Wochenausblick = Verlustreiche Trades!
**Entwickler:** Shinpai-AI (Hannes Kell)

---

## 🎯 WAS IST DER WOCHENAUSBLICK?

Der Wochenausblick ist ein **AI-gestütztes Forex-Analyse-System**, das die kommende Handelswoche analysiert und **3 kritische Entscheidungen** trifft:

**🚦 3-STUFEN-SYSTEM:**
- **🟢 STUFE 1: SWING-Mode** → Optimale Bedingungen, Trends laufen lassen (trade_active=true, swing=true)
- **⚠️ STUFE 2: ATR-Mode** → Defensive Trades, schnelle Exits (trade_active=true, swing=false)
- **🔴 STUFE 3: PAUSE** → Markt-Chaos, kein Trading (trade_active=false)

**Das Ziel:** Sharrow läuft nicht blind, sondern **passt sich dem Markt an UND weiß, wann NICHT zu traden ist!**

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

### **SCHRITT 3: 3-STUFEN-ENTSCHEIDUNG**

**⚡ SHARROW'S DNA VERSTEHEN:**

**✅ Sharrow liebt:**
- Ruhige, stabile Märkte
- Klare Trends (up oder down, egal!)
- Moderate Volatilität
- 95% Winrate in optimalen Bedingungen!

**❌ Sharrow hasst:**
- Central Bank Meeting Days (choppy markets!)
- FOMO-Markets (ultra schnelle Reversals!)
- False Breakouts (Signal → sofort Reversal → Stop-Loss!)
- Event-driven Chaos (unpredictable!)

---

### **🚦 DIE 3 STUFEN - Systematische Entscheidung**

#### **🟢 STUFE 1: SWING! (Optimale Bedingungen)**

**WANN:**
- ✅ Ruhige Woche, klare Trends
- ✅ Keine Major Central Bank Events
- ✅ Stabile bis moderate Volatilität
- ✅ Gute technische Setups (Breakouts, starke Support/Resistance)

**TRADING-CONFIG:**
- **trade_active = true**
- **swing = true** (in config)
- **TP NICHT anfassen!** (Läuft mit Trailing Stop!)
- Exit: Trailing Stop automatisch
- Ziel: Runner laufen lassen, große Gewinne mitnehmen

---

#### **⚠️ STUFE 2: ATR! (Defensive Trading)**

**WANN:**
- ⚠️ Moderate High-Impact Events (CPI, NFP, etc. - NICHT Central Bank Meetings!)
- ⚠️ Dünne Liquidität (z.B. Year-End, Feiertage)
- ⚠️ Range-bound markets (keine klaren Trends)
- ⚠️ Moderate aber handelbare Volatilität

**TRADING-CONFIG:**
- **trade_active = true**
- **swing = false** (in config)
- **TP anpassen** (im tp_setting Bereich):
  - Geringe Volatilität + ruhiger Markt → TP = 1 ATR
  - Hohe Volatilität + ruhiger Markt → TP = 2 ATR (max!)
- Exit: Schnell raus bei fixen TP-Zielen
- Ziel: Kapitalsicherung, kleine sichere Gewinne

---

#### **🔴 STUFE 3: PAUSE! (Sharrow's Todfeinde aktiv!)**

**WANN:**
- 🚨 **Central Bank Meeting Sandwich!** (z.B. FOMC → ECB → BOJ innerhalb 1 Woche!)
- 🚨 **Central Bank Meeting Day selbst!** (Tag des Rate-Decisions!)
- 🚨 **Ultra choppy, FOMO-Markets** (false breakouts überall!)
- 🚨 **Unpredictable event-driven chaos**

**TRADING-CONFIG:**
- **trade_active = false** ← **KEIN TRADING!**
- Begründung: Sharrow interpretiert Signale falsch → Stop-Loss Massaker!

**Real-World Beispiel:**
Ein Trader erlebte während eines ECB-Meeting-Tages 15+ Stop-Loss hits (CHFJPY, AUDUSD, CADCHF). Pattern: Trade öffnet → sofort Reversal → SL → neuer Trade → wieder SL! Verlust: ~€4.50 statt potentiellem +€2-3 Gewinn. Lösung: `trade_active=false` für Central Bank Meeting Days!

---

### **SCHRITT 4: Output im 3-STUFEN + HYBRID Format**

Die AI liefert die Analyse im **3-STUFEN-SYSTEM v3.0 Format:**

#### **Format 1: STUFE 3 - PAUSE! (trade_active=false)**

```
🔴 PAUSE! (trade_active=false)

Grund: ECB Meeting (Mi-Do) = Central Bank Chaos!
Pattern: Choppy markets, false breakouts → Sharrow's Todfeind!
Empfehlung: Donnerstag Abend wieder starten (nach Decision).
```

**Bedeutung:** Komplettes Trading pausieren! Keine Trades diese Woche!

---

#### **Format 2: STUFE 2 - ATR + EXCEPTIONS (trade_active=true)**

```
⚠️ ATR! (trade_active=true)

Ausnahmen (SWING ok):
- EUR/GBP: Kein USD-Risk, stable
- AUD/CAD: Commodity-driven, clear trend
```

**Bedeutung:** Alle Symbole auf ATR, außer die genannten → Die auf SWING!

---

#### **Format 3: STUFE 1 - SWING + EXCEPTIONS (trade_active=true)**

```
🟢 SWING! (trade_active=true)

Ausnahmen (ATR!):
- GBP/USD: CPI Release (Di)
- USD/JPY: NFP Risk (Fr)
```

**Bedeutung:** Alle Symbole auf SWING, außer die genannten → Die auf ATR!

---

#### **Format 4: ALLE GLEICH (selten!)**

```
🟢 SWING! (trade_active=true)
Ruhige Woche, klare Trends - optimal für Sharrow!
```

ODER

```
⚠️ ATR! (trade_active=true)
Dünne Liquidität (Year-End), defensive spielen!
```

**Bedeutung:** Alle Symbole bekommen das gleiche Setting!

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

### **3. STUFE 3: PAUSE (trade_active=false)**

**WANN genau:**
- Central Bank Meeting Sandwich (z.B. FOMC → ECB → BOJ innerhalb 1 Woche)
- Central Bank Meeting Day selbst (Tag der Rate-Decision!)
- Ultra choppy, FOMO-Markets (AI erkennt das!)

**UMSETZUNG:**
- In config (ganz oben): **trade_active = false**
- Sharrow macht GAR NICHTS die ganze Woche (oder nur an kritischen Tagen)!
- Nach dem Event: **trade_active = true** wieder aktivieren

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
> Mit Wochenausblick tradet er mit Radar - und weiß wann er NICHT traden soll!" 🎯

---

**🔥 3-STUFEN-SYSTEM v3.0:**
- **STUFE 1 (SWING):** Optimale Bedingungen → Runner laufen lassen!
- **STUFE 2 (ATR):** Defensive spielen → Kleine sichere Gewinne!
- **STUFE 3 (PAUSE):** Central Bank Chaos → KEIN TRADING!

---

*Made with 💚 by Shinpai-AI (Hannes Kell)*
*For profitable, adaptive Forex-Trades!*
*Open Source - Community-Driven - Professional*
