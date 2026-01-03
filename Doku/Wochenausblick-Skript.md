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

## 📅 WELCHE WOCHE WIRD ANALYSIERT?

Die Handelswoche (Mo-Fr), die am kommenden Montag beginnt.

**Beispiel:**
- Heute ist Donnerstag, 02.01.2026
- "Nächste Woche" = Die Woche ab dem nächsten Montag (05.01.-09.01.2026)

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

#### **Format 4: TAGES-SPEZIFISCHE DEAKTIVIERUNG (1-2 problematische Tage)**

**WANN:** Nur 1-2 Tage sind hochriskant, Rest der Woche ist okay!

**VORTEIL:** ML läuft weiter (trade_active = true), nur an bestimmten Tagen Algo-Handel in MT5 manuell ausschalten!

**Beispiel-Output:**

```
SWING! 🟢

Ausnahmen (ATR):
- EUR/USD: ECB Meeting (Do)

⚠️ WICHTIG - ALGO-HANDEL IN MT5 DEAKTIVIEREN:
- Am 24.12.2025 (Mittwoch): Weihnachten, dünner Markt, Gap-Risiko extrem hoch
  → Am 23.12.2025 um 22:00 Uhr in MT5: Algo-Handel Häkchen entfernen!
  → Am 26.12.2025 um 08:00 Uhr in MT5: Algo-Handel wieder aktivieren!

- Vom 31.12.2025 bis 01.01.2026: Neujahr, extreme Volatilität erwartet
  → Am 30.12.2025 um 22:00 Uhr in MT5: Algo-Handel Häkchen entfernen!
  → Am 02.01.2026 um 08:00 Uhr in MT5: Algo-Handel wieder aktivieren!
```

**Bedeutung:**
- ML-Config: **trade_active = true** (ML läuft normal!)
- Swing/ATR Settings normal setzen
- ABER: An genannten Tagen MT5 Algo-Handel MANUELL deaktivieren!
- **⚠️ KRITISCH:** Nach dem Event Algo-Handel WIEDER AKTIVIEREN (sonst läuft GAR NIX mehr!)

---

#### **Format 5: EXTREME WARNUNG (3+ von 5 Tagen problematisch)**

**WANN:** 3 oder mehr Tage der Woche sind hochriskant!

**GEFAHR:** Selbst "sichere" Tage könnten instabil sein durch Spillover-Effekte!

**Beispiel-Output:**

```
⚠️⚠️⚠️ EXTREME WARNUNG! ⚠️⚠️⚠️

3 VON 5 TAGEN SIND HOCHRISKANT DIESE WOCHE!

Problematische Tage:
- Montag 23.12.2025: Pre-Weihnachten (dünner Markt, früher Schluss)
- Dienstag 24.12.2025: Weihnachten (Markt faktisch tot, extreme Spreads)
- Mittwoch 25.12.2025: Weihnachtsfeiertag (viele Börsen geschlossen)

KONKRETE GEFAHREN:
❌ Gap-Risiken extrem hoch (über Feiertage!)
❌ Liquidität minimal (keine großen Player aktiv)
❌ Spread-Erweiterungen bis zu 300% möglich
❌ News-Impact unvorhersehbar (dünner Markt = heftige Moves!)
❌ Stop-Loss Slippage wahrscheinlich

RESTLICHE WOCHE (Do/Fr):
⚠️ Ebenfalls instabil erwartet:
- Nachholeffekte von Weihnachten
- Positionierungen für Neujahr
- Geringe Liquidität hält an

EMPFEHLUNG: ML KOMPLETT DEAKTIVIEREN!
→ In Config setzen: trade_active = false
→ Grund: Selbst Do/Fr wahrscheinlich zu riskant!
→ Nächste Woche (ab 30.12.): trade_active = true wieder aktivieren

Alternative (Risiko-tolerante Trader):
Falls du trotzdem tradest:
- Nur ATR-Mode (swing = false überall!)
- TP maximal 1 ATR (schnell raus!)
- Lot-Size halbieren!
- Stop-Loss enger setzen!
```

**Bedeutung:**
- **EMPFOHLEN:** trade_active = false (ganze Woche Pause!)
- Falls trotzdem getradet wird: Maximales Risiko-Management!
- **3/5-Regel:** Wenn 3+ Tage problematisch → Ganze Woche unsicher!

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

### **3. TAGES-SPEZIFISCHE DEAKTIVIERUNG (Format 4)**

**Wenn nur 1-2 Tage kritisch (z.B. Weihnachten, NFP, FOMC):**

**Workflow:**

1. **ML-Config bleibt aktiv:**
   - In config: **trade_active = true** (ML läuft weiter!)
   - Swing/ATR Settings normal setzen (wie im Wochenausblick)

2. **MT5 Algo-Handel manuell deaktivieren:**
   - **Am Tag ZUVOR** um 22:00 Uhr (wenn Markt schließt):
     - MT5 öffnen
     - **Algo-Handel Häkchen entfernen** (Expert Advisors deaktivieren!)
     - Sharrow tradet NICHT am kritischen Tag

3. **Nach dem Event wieder aktivieren:**
   - **Am nächsten Tag** um 08:00 Uhr (wenn Markt wieder sicher):
     - MT5 öffnen
     - **Algo-Handel Häkchen WIEDER SETZEN!**
     - ⚠️ **KRITISCH:** Wenn du das vergisst, tradet Sharrow GAR NICHT mehr!

**Beispiel (Weihnachten):**
- Wochenausblick sagt: "Am 24.12.2025 MT5 Algo-Handel deaktivieren"
- **23.12.2025 um 22:00 Uhr:** MT5 → Algo-Handel Häkchen weg
- **26.12.2025 um 08:00 Uhr:** MT5 → Algo-Handel Häkchen rein
- **Vorteil:** ML läuft weiter (sammelt Daten!), nur der kritische Tag wird ausgelassen!

---

### **4. EXTREME WARNUNG (Format 5: 3+/5 Tage problematisch)**

**Wenn 3 oder mehr Tage der Woche hochriskant sind:**

**Workflow:**

1. **ML KOMPLETT DEAKTIVIEREN (Empfehlung!):**
   - In config (ganz oben): **trade_active = false**
   - Grund: Selbst "sichere" Tage sind durch Spillover-Effekte riskant!
   - Sharrow macht GAR NICHTS die ganze Woche!

2. **Nächste Woche wieder aktivieren:**
   - Am Sonntag (vor neuer Handelswoche):
   - In config: **trade_active = true** wieder setzen
   - Neuen Wochenausblick machen!

**Beispiel (Weihnachtswoche):**
- Mo/Di/Mi problematisch (Pre-Weihnachten + Weihnachten)
- Do/Fr wahrscheinlich auch instabil (Nachholeffekte)
- **Empfehlung:** Ganze Woche trade_active = false
- **Ab 30.12.:** Neuer Wochenausblick + trade_active = true

**Alternative (NUR für Risiko-tolerante Trader!):**
- trade_active = true ABER:
  - Alle Symbole ATR-Mode (swing = false)
  - TP maximal 1 ATR (schnell raus!)
  - Lot-Size halbieren!
  - Stop-Loss enger!
- **⚠️ NICHT EMPFOHLEN!** Besser Pause machen!

---

### **5. NOTFALL: Markt-Katastrophe (ungeplant)**

Wenn während der Woche etwas Unerwartetes passiert (Krieg, Crash, etc.):
- **SOFORT:** In config: **trade_active = false**
- MT5: **Algo-Handel Häkchen entfernen**
- Offene Positionen manuell checken & ggf. schließen!
- Markt beobachten, bis Situation klar ist

---

### **6. Sharrow neu starten** mit neuen Settings!

---

## 📋 BEISPIEL-WORKFLOWS

### **BEISPIEL 1: Standard-Woche (Format 1)**

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

### **BEISPIEL 2: Tages-spezifische Deaktivierung (Format 4)**

**Freitag 20.12.2025, 22:30 Uhr:**
- Weihnachtswoche steht an, Zeit für Wochenausblick!

**Samstag 21.12.2025, 10:00 Uhr:**
- AI mit Internet öffnen
- Command: "Wochenausblick"
- AI analysiert Weihnachtswoche (30-45min)

**Samstag 21.12.2025, 11:00 Uhr:**
- AI liefert HYBRID-Output mit tages-spezifischer Warnung:
  ```
  ATR! ⚠️ (Weihnachtswoche = generell vorsichtig!)

  ⚠️ WICHTIG - ALGO-HANDEL IN MT5 DEAKTIVIEREN:
  - Am 24.12.2025 (Mittwoch): Weihnachten, dünner Markt, Gap-Risiko extrem hoch
    → Am 23.12.2025 um 22:00 Uhr in MT5: Algo-Handel Häkchen entfernen!
    → Am 26.12.2025 um 08:00 Uhr in MT5: Algo-Handel wieder aktivieren!

  - Am 25.12.2025 (Donnerstag): Weihnachtsfeiertag, viele Börsen geschlossen
    → BEREITS AM 23.12.2025 deaktiviert, bleibt aus bis 26.12.!
  ```

**Samstag 21.12.2025, 11:15 Uhr:**
- Deine **Sharrow-Config** anpassen:
  - **trade_active = true** (ML läuft weiter! ✅)
  - Alle Symbole: swing = false, TP = 1 ATR (ATR-Mode, Weihnachtswoche!)

**Sonntag 22.12.2025, 23:00 Uhr:**
- Sharrow läuft mit ATR-Settings
- **NOTIZ:** Am 23.12. um 22:00 Uhr MT5 Algo-Handel ausschalten!

**Montag 23.12.2025:**
- Mo-Di: Sharrow tradet normal (ATR-Mode)
- **22:00 Uhr:** MT5 öffnen → **Algo-Handel Häkchen ENTFERNEN!**
- Ab jetzt tradet Sharrow NICHT mehr (Mi+Do Pause!)

**Mittwoch 24.12.2025:**
- Weihnachten, Markt dünn, Sharrow pausiert ✅

**Donnerstag 25.12.2025:**
- Weihnachtsfeiertag, viele Börsen zu, Sharrow pausiert ✅

**Freitag 26.12.2025:**
- **08:00 Uhr:** MT5 öffnen → **Algo-Handel Häkchen WIEDER SETZEN!**
- Ab jetzt tradet Sharrow wieder (Fr normal!)

**Ergebnis:**
- ✅ ML lief die ganze Woche (Daten gesammelt!)
- ✅ Nur Mi+Do wurden übersprungen (kritische Tage!)
- ✅ Mo/Di/Fr wurden normal getradet (ATR-Mode, sicher!)

---

### **BEISPIEL 3: Extreme Warnung (Format 5)**

**Freitag 20.12.2025, 22:30 Uhr:**
- Weihnachtswoche, ABER diesmal extreme Volatilität erwartet!

**Samstag 21.12.2025, 11:00 Uhr:**
- AI liefert EXTREME WARNUNG:
  ```
  ⚠️⚠️⚠️ EXTREME WARNUNG! ⚠️⚠️⚠️

  3 VON 5 TAGEN SIND HOCHRISKANT DIESE WOCHE!

  Problematische Tage:
  - Mo 23.12.: Pre-Weihnachten (dünner Markt, früher Schluss)
  - Di 24.12.: Weihnachten (Markt faktisch tot)
  - Mi 25.12.: Weihnachtsfeiertag (viele Börsen geschlossen)

  RESTLICHE WOCHE (Do/Fr):
  ⚠️ Ebenfalls instabil erwartet (Nachholeffekte + Neujahrs-Positionierung)

  EMPFEHLUNG: ML KOMPLETT DEAKTIVIEREN!
  → trade_active = false
  → Ganze Woche Pause!
  ```

**Samstag 21.12.2025, 11:15 Uhr:**
- Deine **Sharrow-Config** anpassen:
  - **trade_active = false** (Ganze Woche aus! ✅)
  - Swing/ATR Settings NICHT ändern (läuft eh nicht!)

**Sonntag 22.12.2025 - Freitag 27.12.2025:**
- Sharrow macht GAR NICHTS diese Woche! ✅
- Entspannen, Weihnachten feiern, kein Trading-Stress! 🎄

**Samstag 28.12.2025:**
- Neuen Wochenausblick für Neujahrswoche machen!
- Falls Neujahrswoche okay: **trade_active = true** wieder setzen!

**Ergebnis:**
- ✅ Kein Risiko eingegangen (ganze Woche zu gefährlich!)
- ✅ Kapital gesichert (keine Weihnachts-Gaps!)
- ✅ Entspannte Feiertage! 💚

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
