#!/bin/bash
# Löscht MT5-Logs basierend auf TKB-config.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/TKB-config.json"
LOG_FILE="$SCRIPT_DIR/RUN-MT5-Log-Cleaner.log"

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
LOGS_SUBPATH="$(python_config paths.mt5_logs_subpath)"
[ -z "$LOGS_SUBPATH" ] && LOGS_SUBPATH="MQL5/Logs"
# Wenn python_config einen relativen Pfad fälschlich relativ zum Script-Verzeichnis
# aufgelöst hat, zurück auf die reine relative Form kürzen.
case "$LOGS_SUBPATH" in
    "$SCRIPT_DIR"/*)
        LOGS_SUBPATH="${LOGS_SUBPATH#${SCRIPT_DIR}/}"
        ;;
esac
MT5_LOG_DIR="${MT5_PATH%/}/${LOGS_SUBPATH}"

if [ -d "$MT5_LOG_DIR" ]; then
    rm -f "$MT5_LOG_DIR"/*.log 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logs in $MT5_LOG_DIR gelöscht" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fehler: $MT5_LOG_DIR existiert nicht" >> "$LOG_FILE"
fi
