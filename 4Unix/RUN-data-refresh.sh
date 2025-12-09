#!/bin/bash
# =============================================================================
# SHARROW HISTORICAL DATA REFRESH SCRIPT
# =============================================================================
# Automatisches monatliches Löschen und Neuerstellen aller CSV-Dateien
# Für Crontab: 0 6 1 * * /path/to/RUN-data-refresh.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/TKB-config.json"
DATA_DIR="$SCRIPT_DIR"
LOG_FILE="$SCRIPT_DIR/RUN-data-refresh.log"

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
    /*) MT5_FILES="$FILES_SUBPATH" ;;
    *) MT5_FILES="${MT5_PATH%/}/${FILES_SUBPATH}" ;;
esac

PYTHON_BIN="$(python_config paths.python_bin)"
[ -z "$PYTHON_BIN" ] && PYTHON_BIN="/usr/bin/python3"

log_message() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $1" | tee -a "$LOG_FILE"
}

main() {
    log_message "=== SHARROW MONTHLY DATA REFRESH STARTED ==="
    log_message "Arbeitsverzeichnis: $SCRIPT_DIR"
    log_message "MT5 Pfad: $MT5_PATH"
    log_message "MT5 Files: $MT5_FILES"

    deleted_count=0
    log_message "--- Phase 1: Lösche alte CSV-Dateien ---"
    set +e
    for timeframe in H1 M1 M15; do
        while IFS= read -r -d '' file; do
            rm -f "$file" || true
            ((deleted_count++))
        done < <(find "$DATA_DIR" -maxdepth 1 -type f -name "*${timeframe}*.csv" -print0 2>/dev/null || true)
    done
    set -e
    log_message "Gesamt gelöschte CSV-Dateien: $deleted_count"

    log_message "--- Phase 2: Kopiere MT5 Extend Files ---"
    extend_count=0
    if [ -d "$MT5_FILES" ]; then
        set +e
        while IFS= read -r -d '' extend_file; do
            dest_file="$DATA_DIR/$(basename "$extend_file")"
            if [ "$extend_file" -ef "$dest_file" ] 2>/dev/null; then
                continue
            fi
            if cp -f "$extend_file" "$dest_file" 2>>"$LOG_FILE"; then
                ((extend_count++))
            else
                log_message "✗ FEHLER beim Kopieren von $(basename "$extend_file")"
            fi
        done < <(find "$MT5_FILES" -maxdepth 1 -type f -name '*_extend.csv' -print0 2>/dev/null || true)
        set -e
        log_message "Extend Files kopiert: $extend_count"
    else
        log_message "⚠️ WARNUNG: MT5 Verzeichnis nicht gefunden ($MT5_FILES)"
    fi

    log_message "--- Phase 3: Starte TKB-Data-Export ---"
    if [ -f "$SCRIPT_DIR/TKB-Data-Export.py" ]; then
        marker_file="$(mktemp "${TMPDIR:-/tmp}/run-data-refresh.XXXXXX")"
        trap 'rm -f "$marker_file"' EXIT
        touch "$marker_file"
        export_start=$(date '+%Y-%m-%d %H:%M:%S')
        "$PYTHON_BIN" "$SCRIPT_DIR/TKB-Data-Export.py" --config "$CONFIG_FILE" --dest "$DATA_DIR" >> "$LOG_FILE" 2>&1
        export_result=$?
        export_end=$(date '+%Y-%m-%d %H:%M:%S')
        if [ $export_result -eq 0 ]; then
            log_message "✓ TKB-Data-Export erfolgreich ($export_start → $export_end)"
        else
            log_message "✗ TKB-Data-Export fehlgeschlagen (Exit Code: $export_result)"
            exit 1
        fi
    else
        log_message "✗ FEHLER: TKB-Data-Export.py nicht gefunden!"
        exit 1
    fi

    log_message "--- Phase 4: Analysiere neue CSV-Dateien ---"
    new_count=0
    start_date=""
    end_date=""
    for timeframe in H1 M1 M15; do
        mapfile -t files_found < <(find "$DATA_DIR" -maxdepth 1 -name "*${timeframe}*.csv" -type f -newer "$marker_file" 2>/dev/null || true)
        for file in "${files_found[@]}"; do
            [ -f "$file" ] || continue
            ((new_count++))
            if [ -s "$file" ]; then
                first_line=$(sed -n '2p' "$file" | cut -d';' -f1)
                last_line=$(tail -n 1 "$file" | cut -d';' -f1)
                [[ -n "$first_line" && ( -z "$start_date" || "$first_line" < "$start_date" ) ]] && start_date="$first_line"
                [[ -n "$last_line" && ( -z "$end_date" || "$last_line" > "$end_date" ) ]] && end_date="$last_line"
            fi
        done
    done
    rm -f "$marker_file"
    trap - EXIT
    log_message "Neue CSV-Dateien erstellt: $new_count"
    if [ -n "$start_date" ] && [ -n "$end_date" ]; then
        log_message "Datenbereich: $start_date bis $end_date"
    else
        log_message "Datenbereich konnte nicht bestimmt werden"
    fi

    log_message "=== SHARROW DATA REFRESH COMPLETE ==="
}

main "$@"
