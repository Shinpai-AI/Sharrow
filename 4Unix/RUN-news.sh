#!/bin/bash
# RUN-news.sh v6.3
# Sharrow News Workflow – Pfade kommen automatisch aus TKB-config.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/TKB-config.json"
NEWS_DIR="$SCRIPT_DIR"
LOG_FILE="$SCRIPT_DIR/RUN-news.log"
SIGNAL_FILE="$NEWS_DIR/welldone-News.txt"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

python_config() {
    local key="$1"
    /usr/bin/env python3 - "$CONFIG_FILE" "$key" <<'PY'
import json, os, sys
cfg_path, dotted = sys.argv[1:3]
try:
    with open(cfg_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except FileNotFoundError:
    print('', end=''); sys.exit(0)
value = data
for part in dotted.split('.'):
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        value = ''
        break
if isinstance(value, str) and value:
    if not os.path.isabs(value):
        base = os.path.dirname(cfg_path)
        value = os.path.normpath(os.path.join(base, value))
    print(value, end='')
else:
    print('', end='')
PY
}

MT5_PATH="$(python_config paths.mt5_path)"
[ -z "$MT5_PATH" ] && MT5_PATH="/home/shinpai/.wine/drive_c/Program Files/MetaTrader 5"
FILES_SUBPATH="$(python_config paths.mt5_files_subpath)"
[ -z "$FILES_SUBPATH" ] && FILES_SUBPATH="MQL5/Files"
if [[ "$FILES_SUBPATH" == "$SCRIPT_DIR"* ]]; then
    FILES_SUBPATH="${FILES_SUBPATH#$SCRIPT_DIR/}"
fi
case "$FILES_SUBPATH" in
    /*) MT5_FILES_DIR="$FILES_SUBPATH" ;;
    *) MT5_FILES_DIR="${MT5_PATH%/}/${FILES_SUBPATH}" ;;
esac

PYTHON_BIN="$(python_config paths.python_bin)"
[ -z "$PYTHON_BIN" ] && PYTHON_BIN="/usr/bin/python3"
NEWS_SCRIPT_PATH="$SCRIPT_DIR/TKB-News-Bot.py"

log() {
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$ts] $1" | tee -a "$LOG_FILE"
}

log "🚀 Sharrow News Workflow gestartet"
log "Arbeitsverzeichnis: $SCRIPT_DIR"
log "MT5 Pfad: $MT5_PATH"
log "MT5 Files: $MT5_FILES_DIR"
log "Python: $PYTHON_BIN"

cd "$NEWS_DIR"
log "🧹 Leere News-Verzeichnis"
rm -f ./*_Info.txt "$SIGNAL_FILE" 2>/dev/null || true

log "🗑️ Lösche *_Info.txt in MT5/Files"
if [ -d "$MT5_FILES_DIR" ]; then
    rm -f "$MT5_FILES_DIR"/*_Info.txt 2>/dev/null || true
else
    log "⚠️ MQL5/Files nicht gefunden ($MT5_FILES_DIR)"
fi

log "🎯 Starte TKB-News-Bot.py"
if [ ! -f "$NEWS_SCRIPT_PATH" ]; then
    log "❌ TKB-News-Bot.py fehlt"
    exit 1
fi
"$PYTHON_BIN" "$NEWS_SCRIPT_PATH" >> "$LOG_FILE" 2>&1
NEWS_EXIT_CODE=$?
if [ $NEWS_EXIT_CODE -ne 0 ]; then
    log "❌ News-Bot Fehler (Exit $NEWS_EXIT_CODE)"
    exit 1
fi
log "✅ News-Bot abgeschlossen"

if [ -f "$SIGNAL_FILE" ]; then
    log "✅ welldone-News.txt gefunden"
else
    log "⚠️ Keine welldone-News.txt erstellt"
fi

log "📋 Kopiere *_Info.txt nach MT5/Files"
if [ ! -d "$MT5_FILES_DIR" ]; then
    log "❌ MQL5/Files nicht vorhanden – Abbruch"
    exit 1
fi

FILES_COPIED=0
FILES_FAILED=0
while IFS= read -r -d '' info_file; do
    filename="$(basename "$info_file")"
    if cp "$info_file" "$MT5_FILES_DIR/" 2>/dev/null; then
        ((FILES_COPIED+=1))
        log "📄 kopiert: $filename"
    else
        ((FILES_FAILED+=1))
        log "❌ Fehler beim Kopieren: $filename"
    fi
done < <(find "$NEWS_DIR" -maxdepth 1 -type f -name '*_Info.txt' -print0 2>/dev/null)

log "=== News Workflow beendet ==="
log "📄 Erfolgreich kopiert: $FILES_COPIED"
log "❌ Fehler: $FILES_FAILED"

if [ $FILES_COPIED -gt 0 ] && [ $FILES_FAILED -eq 0 ]; then
    echo "✅ GOLDJUNGE News Workflow SUCCESSFUL!"
    exit 0
else
    echo "❌ GOLDJUNGE News Workflow FAILED!"
    exit 1
fi
