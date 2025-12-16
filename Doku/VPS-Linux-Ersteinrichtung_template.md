# 🚀 VPS Setup Guide - MetaTrader 5 mit TigerVNC
> **Production Ready v1.0** - Getestet und funktionierend!

---

## 📋 VORAUSSETZUNGEN

### Server:
- VPS mit Ubuntu 24.04 LTS (frisch installiert!)
- Root SSH Zugriff (initial)
- Mindestens 2GB RAM, 20GB Storage
- Öffentliche IP-Adresse

### Lokal:
- SSH Key-Pair generiert (`ssh-keygen -t ed25519`)
- Public Key bereit für Server
- Remmina oder anderer VNC Client
- SSH Client (OpenSSH)

---

## 🔧 PHASE 1: INITIAL CONNECTION

### 1.1 Erste Verbindung als Root
```bash
ssh root@YOUR_VPS_IP
# Initial Password eingeben (vom Hoster erhalten)
```

---

## 👤 PHASE 2: USER SETUP & SSH HARDENING

### 2.1 User erstellen
```bash
# User mit Home-Directory erstellen
useradd -m -s /bin/bash haze
echo "haze:YOUR_PASSWORD" | chpasswd

# SSH Directory für haze
mkdir -p /home/haze/.ssh
chmod 700 /home/haze/.ssh

# SSH Public Key hinzufügen (von lokalem PC kopieren!)
echo "YOUR_SSH_PUBLIC_KEY_HIER_EINFÜGEN" > /home/haze/.ssh/authorized_keys
chmod 600 /home/haze/.ssh/authorized_keys
chown -R haze:haze /home/haze/.ssh

# Sudo-Rechte für haze
echo "haze ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/haze
chmod 440 /etc/sudoers.d/haze
```

**Test SSH Key Login:**
```bash
# In NEUER Shell auf lokalem PC!
ssh -i /path/to/private_key haze@YOUR_VPS_IP "whoami"
# Output sollte sein: haze ✅
```

---

### 2.2 SSH Hardening

**⚠️ KRITISCH - Systemd Socket Fix!**

Ubuntu nutzt `ssh.socket` für Socket Activation - das überschreibt die SSH Config und muss disabled werden!

```bash
# SSH Config ändern
sed -i 's/#Port 22/Port 1208/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# CRITICAL FIX - Systemd Socket deaktivieren!
systemctl stop ssh.socket
systemctl disable ssh.socket
systemctl restart ssh.service

# Port verifizieren (sollte :1208 zeigen, NICHT :22!)
ss -tlnp | grep ssh
```

**Test SSH auf neuem Port:**
```bash
# In NEUER Session (alte NICHT schließen!)
ssh -p 1208 -i /path/to/private_key haze@YOUR_VPS_IP "whoami"
# Output: haze ✅
```

---

### 2.3 Firewall Setup

**⚠️ ERST nach erfolgreichem SSH Port Test aktivieren!**

```bash
# UFW installieren
apt update
apt install ufw -y

# SSH Port erlauben
ufw allow 1208/tcp

# Firewall aktivieren
ufw --force enable

# Status checken
ufw status
```

---

## 🖥️ PHASE 3: DESKTOP ENVIRONMENT (XFCE Full)

### 3.1 XFCE installieren

```bash
# Als haze (oder mit sudo)
apt update
apt install xfce4 xfce4-goodies -y
```

**Installation:**
- Pakete: ~428 Pakete
- Zeit: ~5-10 Minuten
- Größe: ~700MB

**Warum XFCE Full?**
- ✅ Professionelles Aussehen
- ✅ Keine Fehler (im Gegensatz zu MATE-core!)
- ✅ Funktioniert perfekt mit TigerVNC
- ✅ Leichtgewichtig aber vollständig

---

## 🐯 PHASE 4: TIGERVNC SETUP

### 4.1 TigerVNC installieren

```bash
apt install tigervnc-standalone-server tigervnc-common -y
vncserver -version
```

---

### 4.2 VNC Password setzen

```bash
# Als haze
mkdir -p ~/.vnc
echo 'YOUR_VNC_PASSWORD' | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd
```

---

### 4.3 VNC xstartup erstellen

```bash
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF

chmod +x ~/.vnc/xstartup
```

---

### 4.4 VNC Server starten

**Mit 720p Resolution (empfohlen!):**
```bash
vncserver :1 -geometry 1280x720 -localhost no
```

**Alternativen:**
- `1920x1080` - Full HD (kann zu groß sein!)
- `1280x1024` - SXGA (zu hoch für viele Displays!)
- `1280x720` - 720p (EMPFOHLEN - passt überall!)

**Resolution später ändern:**
```bash
vncserver -kill :1
vncserver :1 -geometry 1280x720
```

**VNC läuft jetzt auf:**
- Display: `:1`
- Port: `5901`

---

## 🔌 PHASE 5: VNC CLIENT SETUP (Lokal)

### 5.1 Remmina Setup (empfohlen!)

**Remmina installieren:**
```bash
# Fedora
sudo dnf install remmina -y

# Ubuntu/Debian
sudo apt install remmina -y
```

**Remmina Profil erstellen:**
1. Remmina öffnen → Neues Profil
2. **Protokoll:** VNC
3. **Server:** `localhost:5901`
4. **SSH Tunnel aktivieren!** ✅
   - **SSH Server:** `YOUR_VPS_IP:1208`
   - **SSH Username:** `haze`
   - **SSH Private Key:** `/path/to/private_key`
5. **VNC Password:** `YOUR_VNC_PASSWORD`
6. Speichern & Verbinden!

---

### 5.2 Manueller SSH Tunnel (Alternative)

```bash
# SSH Tunnel erstellen
ssh -p 1208 -i /path/to/private_key -L 5901:localhost:5901 haze@YOUR_VPS_IP

# In neuer Shell: VNC Client zu localhost:5901 verbinden
```

---

## 🍷 PHASE 6: WINE & MT5

### 6.1 Wine installieren

```bash
dpkg --add-architecture i386
apt update
apt install wine wine32 wine64 winetricks -y

# Version checken
wine --version
# Output: wine-9.0 (oder höher)
```

**Installation:**
- Pakete: ~359 Pakete
- Zeit: ~5-10 Minuten
- Größe: ~1.8GB

---

### 6.2 MT5 Download

```bash
mkdir -p ~/Downloads
cd ~/Downloads
wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
```

---

### 6.3 MT5 Installation

**Via VNC Desktop:**
1. VNC verbinden (Remmina!)
2. Terminal öffnen auf VPS Desktop
3. `cd ~/Downloads`
4. `wine mt5setup.exe`
5. Installation GUI folgen

**Standard Installation-Pfad:**
```
~/.wine/drive_c/Program Files/MetaTrader 5/
```

---

## 🤖 PHASE 7: MT5 WATCHDOG SERVICE

### 7.1 Systemd Service erstellen

**⚠️ WICHTIG:** Spaces in Pfad mit `bash -c` escapen!

```bash
sudo tee /etc/systemd/system/mt5-watchdog.service > /dev/null << 'EOF'
[Unit]
Description=MetaTrader 5 Watchdog Service
After=network.target

[Service]
Type=simple
User=haze
Environment="DISPLAY=:1"
Environment="HOME=/home/haze"
WorkingDirectory=/home/haze
ExecStart=/bin/bash -c 'wine "/home/haze/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"'
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

**Warum `bash -c`?**
- ❌ Ohne: Path-Escaping schlägt fehl!
- ✅ Mit: Spaces im Pfad funktionieren!

---

### 7.2 Service aktivieren

```bash
sudo systemctl daemon-reload
sudo systemctl enable mt5-watchdog.service
sudo systemctl start mt5-watchdog.service

# Status checken
sudo systemctl status mt5-watchdog.service
```

**Expected Output:**
```
● mt5-watchdog.service - MetaTrader 5 Watchdog Service
   Loaded: loaded
   Active: active (running)
   PID: [number]
   Tasks: ~50-60
   Memory: ~250-300MB
```

**MT5 Watchdog Features:**
- ✅ Auto-Start bei Server-Reboot
- ✅ Auto-Restart bei MT5 Crash
- ✅ 30 Sekunden Wartezeit zwischen Restarts
- ✅ Logs in journalctl

---

## 📱 PHASE 8: TELEGRAM WEBREQUEST

### 8.1 Telegram URL freischalten

**In MT5:**
1. **Tools** → **Options** → **Expert Advisors**
2. **"Allow WebRequest for listed URL"** aktivieren ✅
3. URL hinzufügen: `https://api.telegram.org`
4. **OK** klicken

---

## 🔐 PHASE 9: 2FA SETUP (Optional aber empfohlen!)

### 9.1 Google Authenticator installieren

```bash
apt install libpam-google-authenticator -y
```

---

### 9.2 Zeit-Synchronisation aktivieren (KRITISCH!)

**⚠️ WICHTIG:** TOTP (Time-based OTP) braucht exakte Zeit-Synchronisation!

```bash
# NTP aktivieren für automatische Zeit-Sync
sudo timedatectl set-ntp true

# Zeit checken (muss mit Handy übereinstimmen!)
date
```

**Warum wichtig?**
- 2FA Codes sind nur 30 Sekunden gültig
- VPS und Handy müssen exakt gleiche Zeit haben
- Sonst funktionieren Codes nicht! ❌

---

### 9.3 PAM konfigurieren

```bash
sudo nano /etc/pam.d/sshd
```

**Am Ende der Datei hinzufügen:**
```
auth required pam_google_authenticator.so
```

**Speichern:** `CTRL+O`, ENTER, `CTRL+X`

---

### 9.4 2FA für User einrichten (als haze!)

**⚠️ Als User "haze" ausführen, NICHT als root!**

```bash
# Als haze einloggen
su - haze

# Google Authenticator setup starten
google-authenticator
```

**Fragen & Antworten:**
```
1. Do you want authentication tokens to be time-based?
   → y (ENTER)

2. [QR-CODE ERSCHEINT!]
   → Mit Google Authenticator App scannen!
   → ODER: Secret Key manuell eingeben

3. Do you want me to update your ~/.google_authenticator file?
   → y (ENTER)

4. Do you want to disallow multiple uses of the same token?
   → y (ENTER)

5. Do you want to increase the time skew window?
   → n (ENTER)

6. Do you want to enable rate-limiting?
   → y (ENTER)
```

**✅ Google Authenticator ist jetzt eingerichtet!**

**Wichtig:**
- Emergency Scratch Codes sicher notieren! (Paper Backup!)
- Secret Key speichern für Backup
- QR-Code muss gescannt werden BEVOR weiter!

---

### 9.5 SSH AuthenticationMethods aktivieren

**⚠️ ERST JETZT! Nicht vorher, sonst Lockout!**

```bash
sudo nano /etc/ssh/sshd_config
```

**Am Ende der Datei hinzufügen:**
```
AuthenticationMethods publickey,keyboard-interactive
```

**Diese Zeilen sollten auch vorhanden sein (aus Phase 2):**
```
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes
UsePAM yes
```

**Speichern:** `CTRL+O`, ENTER, `CTRL+X`

---

### 9.6 SSH neu starten

```bash
sudo systemctl restart ssh.service
```

**⚠️ Alte SSH Session NICHT schließen!**

---

### 9.7 2FA testen (KRITISCH!)

**In NEUER Terminal Session (alte offen lassen!):**

```bash
ssh -p 1208 -i /path/to/private_key haze@YOUR_VPS_IP
```

**Was jetzt passiert:**
1. SSH Key wird geprüft ✅
2. **"Verification code:"** erscheint!
3. **6-stelligen Code aus Google Authenticator App eingeben!**
4. Bei richtigem Code → Login erfolgreich! ✅

**⚠️ WICHTIG - SSH Prompts verstehen:**
- Du bekommst mehrere Prompts:
  1. SSH Key Passphrase (falls Key verschlüsselt)
  2. **Username** (manchmal, wenn nicht in SSH config!)
  3. **Verification code:** ← 2FA Code hier!

**Wenn 2FA Code NICHT funktioniert:**
```bash
# Zeit auf VPS checken
ssh -p 1208 haze@YOUR_VPS_IP "date"

# Mit Handy Zeit vergleichen - MUSS EXAKT sein!
# Falls unterschiedlich:
sudo timedatectl set-ntp true
```

---

### 9.8 2FA Troubleshooting

**Problem: "Permission denied (keyboard-interactive)"**

**Lösung 1: Zeit-Synchronisation checken**
```bash
# VPS Zeit
date

# Mit Handy vergleichen!
# Unterschied > 30 Sekunden = 2FA funktioniert nicht!

# NTP aktivieren
sudo timedatectl set-ntp true
```

**Lösung 2: Warte auf neuen Code!**
- Codes sind nur 30 Sekunden gültig
- Warte bis neuer Code in App erscheint
- Gib frischen Code sofort ein!

**Lösung 3: 2FA temporär deaktivieren (Notfall!)**
```bash
# Via Hostinger Web-Terminal oder alte SSH Session
sudo sed -i 's/^AuthenticationMethods/#AuthenticationMethods/' /etc/ssh/sshd_config
sudo systemctl restart ssh.service

# Jetzt kannst du wieder ohne 2FA rein
# Problem fixen, dann AuthenticationMethods wieder aktivieren!
```

---

## 📦 PHASE 10: ZUSÄTZLICHE SOFTWARE

### 10.1 Sharrow von GitHub (Beispiel)

```bash
mkdir -p ~/Trading
cd ~/Trading
git clone https://github.com/YOUR_USERNAME/Sharrow.git
```

---

## 🛠️ TROUBLESHOOTING

### SSH Private Key Permissions Error

**Error:**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for 'key' are too open.
```

**Fix:**
```bash
chmod 600 /path/to/private_key
```

**⚠️ Hinweis:** pCloud Sync kann Permissions zurücksetzen! Immer vor SSH-Connect prüfen!

---

### Host Key Changed Warning

**Error:**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Fix (bei VPS-Neuinstallation):**
```bash
ssh-keygen -R YOUR_VPS_IP
ssh-keygen -R '[YOUR_VPS_IP]:1208'
```

---

### VNC Resolution zu groß

**Symptom:** Desktop passt nicht auf Bildschirm

**Fix:**
```bash
vncserver -kill :1
vncserver :1 -geometry 1280x720
```

---

### MT5 Watchdog Service startet nicht

**Check 1: Pfad korrekt?**
```bash
ls -la ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/terminal64.exe
```

**Check 2: Wine funktioniert?**
```bash
wine --version
```

**Check 3: Service Logs:**
```bash
sudo journalctl -u mt5-watchdog.service -f
```

**Häufiger Fehler - Path Escaping:**
- ❌ FALSCH: `ExecStart=wine /home/haze/.wine/drive_c/Program\\ Files/MetaTrader\\ 5/terminal64.exe`
- ✅ RICHTIG: `ExecStart=/bin/bash -c 'wine "/home/haze/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"'`

---

### VNC Connection Refused

**Check 1: VNC läuft?**
```bash
vncserver -list
# Output sollte sein:
# TigerVNC server sessions:
# X DISPLAY #     PROCESS ID
# :1              [PID]
```

**Check 2: Port offen?**
```bash
ss -tlnp | grep 5901
```

**Check 3: SSH Tunnel aktiv? (lokal)**
```bash
netstat -tlnp | grep 5901
```

---

## 📊 INSTALLATION STATISTIK

**Paket-Übersicht:**
- XFCE Full: ~428 Pakete (~700MB)
- TigerVNC: ~20 Pakete (~15MB)
- Wine (32+64bit): ~359 Pakete (~1.8GB)
- Google Authenticator: ~5 Pakete (~1MB)
- **Total:** ~800+ Pakete, ~2.5GB

**Zeitaufwand:**
- User Setup + SSH Hardening: ~5 Minuten
- XFCE Installation: ~5-10 Minuten
- TigerVNC Setup: ~2 Minuten
- Wine Installation: ~5-10 Minuten
- MT5 Installation: ~3-5 Minuten (manuell via GUI)
- Service Configuration: ~2 Minuten
- **Total: ~20-35 Minuten**

---

## 🎯 COMMAND REFERENCE

### SSH Commands:
```bash
# Connect with custom port
ssh -p 1208 -i /path/to/key user@ip

# Check SSH port
ss -tlnp | grep ssh

# Restart SSH service
sudo systemctl restart ssh.service

# SSH Config test
sudo sshd -t

# Remove known host
ssh-keygen -R ip
ssh-keygen -R '[ip]:port'

# Fix key permissions
chmod 600 /path/to/private_key
```

---

### VNC Commands:
```bash
# Start VNC server
vncserver :1 -geometry 1280x720 -localhost no

# Stop VNC server
vncserver -kill :1

# List VNC sessions
vncserver -list

# Change VNC password
vncpasswd
```

---

### Systemd Service Commands:
```bash
# Service status
sudo systemctl status mt5-watchdog.service

# Service logs (live)
sudo journalctl -u mt5-watchdog.service -f

# Restart service
sudo systemctl restart mt5-watchdog.service

# Stop service
sudo systemctl stop mt5-watchdog.service

# Enable on boot
sudo systemctl enable mt5-watchdog.service

# Disable
sudo systemctl disable mt5-watchdog.service

# Reload daemon
sudo systemctl daemon-reload
```

---

### Firewall Commands:
```bash
# Allow port
sudo ufw allow PORT/tcp

# Check status
sudo ufw status

# Enable firewall
sudo ufw --force enable

# Disable firewall
sudo ufw disable

# Delete rule
sudo ufw delete allow PORT/tcp
```

---

### System Info Commands:
```bash
# Check running processes
ps aux | grep wine

# Check open ports
ss -tlnp

# Check disk usage
df -h

# Check memory usage
free -h

# System load
top

# Logs
journalctl -f
```

---

## 💡 LESSONS LEARNED - Critical Insights!

### ✅ DO's:

1. **SSH Port ERST testen, DANN Firewall aktivieren!**
   - Sonst locked man sich aus!
   - Immer parallele Session zum Testen offen halten

2. **Systemd Socket IMMER checken & disablen bei SSH Port-Änderung!**
   - Ubuntu nutzt `ssh.socket` für Socket Activation
   - Überschreibt `sshd_config` Port-Settings!
   - `systemctl disable ssh.socket` + `systemctl stop ssh.socket` ist Pflicht!

3. **Private Keys: chmod 600 IMMER!**
   - pCloud Sync kann Permissions zurücksetzen
   - Vor jedem SSH Connect prüfen

4. **XFCE Full statt MATE-core verwenden!**
   - MATE-core hatte "Indicator Applet" Errors
   - XFCE Full = professionell, keine Fehler
   - Funktioniert perfekt mit TigerVNC

5. **VNC Resolution: 720p (1280x720) empfohlen!**
   - 1280x720 passt auf die meisten Displays
   - 1280x1024 ist zu hoch für viele Bildschirme

6. **Path-Escaping in Systemd mit bash -c!**
   - Spaces in Pfaden brauchen korrektes Quoting
   - `bash -c 'wine "path with spaces"'` funktioniert perfekt!

7. **Parallele Installations-Jobs nutzen!**
   - XFCE, Wine, etc. können parallel laufen
   - Spart massiv Zeit!

8. **Zeit-Synchronisation für 2FA aktivieren!**
   - NTP mit `timedatectl set-ntp true`
   - VPS Zeit muss mit Handy exakt übereinstimmen
   - TOTP Codes funktionieren nur 30 Sekunden!

---

### ❌ DON'Ts:

1. **NIEMALS remote SSH restart ohne Test-Session!**
   - Immer neue Session parallel öffnen
   - Alte Session erst nach erfolgreicher Verbindung schließen

2. **NIEMALS Firewall vor SSH-Port-Test aktivieren!**
   - SSH funktioniert → dann Firewall
   - Sonst Lockout!

3. **NIEMALS annehmen dass sshd_config alleine reicht!**
   - Systemd Socket kann Config überschreiben
   - Immer mit `ss -tlnp | grep ssh` verifizieren!

4. **NIEMALS Key-Permissions vergessen!**
   - 600 ist Pflicht!
   - SSH blockt bei zu offenen Permissions

5. **NIEMALS 2FA aktivieren ohne Zeit-Synchronisation!**
   - TOTP braucht exakte Zeit (NTP aktivieren!)
   - VPS Zeit muss mit Handy übereinstimmen
   - Codes funktionieren nur 30 Sekunden!

6. **NIEMALS 2FA vor Ende des Setups konfigurieren!**
   - Erst alles fertig, dann 2FA
   - `AuthenticationMethods` erst NACH Test aktivieren!

---

## 📂 WICHTIGE PFADE AUF VPS

```
User Home:           /home/haze/
SSH Keys:            /home/haze/.ssh/authorized_keys
VNC Config:          /home/haze/.vnc/
VNC xstartup:        /home/haze/.vnc/xstartup
VNC Password:        /home/haze/.vnc/passwd
MT5:                 /home/haze/.wine/drive_c/Program Files/MetaTrader 5/
Downloads:           /home/haze/Downloads/
Trading:             /home/haze/Trading/
Sharrow:             /home/haze/Trading/Sharrow/
Service File:        /etc/systemd/system/mt5-watchdog.service
2FA Config:          /home/haze/.google_authenticator
SSH Config:          /etc/ssh/sshd_config
PAM Config:          /etc/pam.d/sshd
UFW Status:          /etc/ufw/
Sudoers:             /etc/sudoers.d/haze
```

---

## ✅ SETUP CHECKLIST

**Server Setup:**
- [ ] User "haze" erstellt + SSH Key
- [ ] SSH Port 1208 funktioniert
- [ ] Systemd ssh.socket disabled ✅
- [ ] Firewall (UFW) aktiviert
- [ ] XFCE Full installiert
- [ ] TigerVNC Server läuft (:1 = Port 5901)
- [ ] Wine 9.0 installiert (32+64bit)
- [ ] MT5 installiert via Wine GUI
- [ ] MT5 Watchdog Service aktiv & auto-restart
- [ ] Telegram WebRequest freigegeben (`https://api.telegram.org`)
- [ ] 2FA konfiguriert + Zeit synchronisiert (optional aber empfohlen!)

**Client Setup:**
- [ ] SSH Connection zu Port 1208 funktioniert
- [ ] SSH Tunnel zu VNC (Port 5901) funktioniert
- [ ] Remmina/VNC Client verbunden
- [ ] Desktop sichtbar & funktional (1280x720)
- [ ] MT5 läuft via Watchdog Service
- [ ] Service startet MT5 nach Reboot

**Status:**
- [ ] VPS Ready für Production! 🚀

---

## 🔍 NEXT STEPS

### Nach diesem Setup:

1. **MT5 Broker konfigurieren**
   - Account Login
   - Server auswählen
   - Demo/Live aktivieren

3. **Trading Bot/EA kopieren**
   ```bash
   cp ~/Trading/Sharrow/EA.mq5 ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/
   ```

4. **Bot aktivieren in MT5**
   - "Allow live trading" aktivieren!
   - EA auf Chart ziehen

5. **Monitoring einrichten**
   - Telegram Bot testen
   - Logs überwachen: `journalctl -u mt5-watchdog -f`

6. **GO LIVE!** 📈

---

## 📝 SECURITY NOTES

**Aktuelle Security-Features:**
- ✅ Root Login disabled
- ✅ Password Auth disabled (nur SSH Key!)
- ✅ Custom SSH Port (1208, nicht Standard-22!)
- ✅ Firewall aktiv (nur Port 1208 offen)
- ✅ 2FA aktiviert (optional aber stark empfohlen!)
- ✅ Systemd Socket disabled (kein Port 22 Backdoor!)

**Wichtig:**
- 🔑 SSH Private Key sicher aufbewahren! (Offline Backup!)
- 📱 2FA Emergency Codes notieren! (Papier, Safe!)
- 🔄 Regelmäßige Updates: `apt update && apt upgrade`
- 📊 Service Logs checken: `journalctl -u mt5-watchdog.service`

---

## 🎓 KNOWLEDGE BASE - Ubuntu SSH Systemd

### Warum ssh.socket das Problem war:

**Ubuntu 24.04 nutzt Socket Activation:**
```bash
# Socket startet SSH on-demand
systemctl status ssh.socket
# → Listens on 0.0.0.0:22

# Service läuft im Hintergrund
systemctl status ssh.service
# → Uses sshd_config settings
```

**Das Problem:**
- `ssh.socket` lauscht auf Port 22 (hardcoded!)
- `ssh.service` lauscht auf `sshd_config` Port (z.B. 1208)
- **Socket hat Priorität und gewinnt!** ❌
- Resultat: Port 22 bleibt offen trotz Config-Änderung!

**Die Lösung:**
```bash
# Socket komplett ausschalten
systemctl stop ssh.socket
systemctl disable ssh.socket

# Nur Service nutzen
systemctl enable ssh.service
systemctl restart ssh.service
```

**Verification:**
```bash
ss -tlnp | grep ssh
# Output sollte ONLY :1208 zeigen, NICHT :22!
```

**Warum das wichtig ist:**
- Security: Port 22 ist ein Standardziel für Brute-Force
- Firewall: Port 22 muss nicht in UFW erlaubt werden
- Konsistenz: Config entspricht tatsächlichem Verhalten

---

## 📄 VERSION INFO

**Version:** 1.0 Production
**Datum:** 2025-12-10
**Getestet auf:** Ubuntu 24.04 LTS
**Status:** ✅ Production Ready

**Setup-Typ:** MetaTrader 5 VPS mit TigerVNC
**Use-Case:** Trading Bot 24/7 Deployment
**Remote Access:** TigerVNC via SSH Tunnel (Remmina)

**Test-Umgebung:**
- VPS: Ubuntu 24.04 LTS
- RAM: 2GB+
- Storage: 20GB+
- XFCE: 4.18
- Wine: 9.0
- TigerVNC: 1.13+
- MT5: Latest (2025)

---

## 🙏 CREDITS & ACKNOWLEDGMENTS

**Made with determination, failures, and ultimate success!**

Lessons learned from **3+ VPS setup attempts**, systemd socket discoveries, MATE-to-XFCE migration, path escaping debugging, and countless troubleshooting sessions!

**Key Technologies:**
- TigerVNC Community - Remote Desktop
- Ubuntu / systemd - OS & Service Management
- Wine Project - Windows Compatibility
- MetaTrader 5 - Trading Platform
- XFCE - Desktop Environment
- Remmina - VNC Client

**Special Thanks:**
- All the failed attempts that taught us what NOT to do!
- Systemd documentation (once we found it!)
- Stack Overflow community
- Open Source contributors

---

**🚀 Ready to deploy your trading bot 24/7!**
**💹 Built for reliability and ease of maintenance!**
**🔐 Secured and hardened from ground up!**

*Made with blood, sweat, and determination by Hasi & Ray* 💚
