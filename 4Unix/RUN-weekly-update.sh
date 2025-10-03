#!/bin/bash
# Goldjunge Weekly Update – komplett flache Struktur, Pfade nur aus TKB-config.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/TKB-config.json"
LOG_FILE="$SCRIPT_DIR/weekly_update.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DATA_DIR="$SCRIPT_DIR"
RULES_DIR="$SCRIPT_DIR"
DELETE_MQL5_CSVS=true

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
if [ -z "$MT5_PATH" ]; then
    echo "❌ ERROR: paths.mt5_path not found in TKB-config.json!"
    exit 1
fi
FILES_SUBPATH="$(python_config paths.mt5_files_subpath)"
[ -z "$FILES_SUBPATH" ] && FILES_SUBPATH="MQL5/Files"
FILES_SUBPATH=${FILES_SUBPATH#${SCRIPT_DIR}/}
FILES_SUBPATH=${FILES_SUBPATH#/}
MT5_FILES="${MT5_PATH%/}/${FILES_SUBPATH}"
PYTHON_BIN="$(python_config paths.python_bin)"
[ -z "$PYTHON_BIN" ] && PYTHON_BIN="/usr/bin/python3"
CONFIG_SCRIPT="$SCRIPT_DIR/TKB-config-Bearbeitung.py"
DATA_EXPORT_SCRIPT="$SCRIPT_DIR/TKB-Data-Export.py"
TRAIN_SCRIPT="$SCRIPT_DIR/Train-KI-Bot.py"
WELLDONE_FILE="$SCRIPT_DIR/welldone.txt"
WELLDONE_DATA_FILE="$SCRIPT_DIR/welldone-TKB-Data.txt"
SYMBOL_EXPORT_FILE="SymbolDataExport.csv"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $1" | tee -a "$LOG_FILE"
}

clean_temp_files() {
    local delete_count=0
    log "Starte Aufräumphase"
    for F in "$SCRIPT_DIR"/*; do
        local base
        base=$(basename "$F")
        if [ -d "$F" ]; then
            log "PROTECTED (Dir): $base"
            continue
        else
            case "$base" in
                *.py|*.mq5|RUN*|*config.json|*.md|*_H1.csv|*_M1.csv|*_M15.csv)
                    log "PROTECTED: $base"
                    continue
                    ;;
            esac
        fi
        rm -f "$F" && ((delete_count+=1))
    done
    log "Gelöschte Dateien: $delete_count"
}

copy_symbol_export() {
    SYMBOL_MOVED=false
    if [ -f "$MT5_FILES/$SYMBOL_EXPORT_FILE" ]; then
        log "SymbolDataExport gefunden – verschiebe nach Projekt"
        if mv "$MT5_FILES/$SYMBOL_EXPORT_FILE" "$SCRIPT_DIR/"; then
            SYMBOL_MOVED=true
        else
            log "❌ Verschieben fehlgeschlagen"
        fi
    else
        log "Keine SymbolDataExport.csv im MT5 Files"
    fi
}

copy_all_csv() {
    local count=0
    if [ -d "$MT5_FILES" ]; then
        log "Kopiere CSV-Dateien aus MT5"
        for file in "$MT5_FILES"/*.csv; do
            [ -f "$file" ] || continue
            if cp "$file" "$DATA_DIR/"; then
                ((count+=1))
            else
                log "❌ Fehler beim Kopieren: $(basename "$file")"
            fi
        done
        log "CSV-Dateien kopiert: $count"
    else
        log "⚠️ MT5 Files Verzeichnis nicht gefunden ($MT5_FILES)"
    fi
}

run_config_processing() {
    local export_path="$SCRIPT_DIR/$SYMBOL_EXPORT_FILE"
    if [ -f "$CONFIG_SCRIPT" ] && [ -f "$export_path" ]; then
        log "Aktualisiere TKB-config mit Symboldaten"
        "$PYTHON_BIN" "$CONFIG_SCRIPT" --import-symbols "$export_path" >> "$LOG_FILE" 2>&1 || log "❌ Config-Processing fehlgeschlagen"
    else
        log "Config-Processing übersprungen"
    fi
}

run_data_export() {
    if [ -f "$DATA_EXPORT_SCRIPT" ]; then
        log "Starte Datenexport"
        rm -f "$WELLDONE_DATA_FILE"
        "$PYTHON_BIN" "$DATA_EXPORT_SCRIPT" --config "$CONFIG_FILE" --dest "$DATA_DIR" >> "$LOG_FILE" 2>&1 || {
            log "❌ Datenexport fehlgeschlagen"; exit 1; }
        log "Datenexport abgeschlossen"
    else
        log "❌ TKB-Data-Export.py nicht gefunden"
        exit 1
    fi
}

run_training() {
    if [ ! -f "$TRAIN_SCRIPT" ]; then
        log "⚠️ Train-KI-Bot.py fehlt – Training übersprungen"
        return
    fi
    log "Starte Training"
    "$PYTHON_BIN" "$TRAIN_SCRIPT" >> "$LOG_FILE" 2>&1 || { log "❌ Training konnte nicht gestartet werden"; exit 1; }
    log "Training gestartet, warte auf welldone.txt"
    local timeout=0
    while [ ! -f "$WELLDONE_FILE" ]; do
        sleep 7
        timeout=$((timeout+7))
        if [ $timeout -ge 7200 ]; then
            log "❌ Training Timeout nach 120 Minuten"
            exit 1
        fi
    done
    log "Training abgeschlossen"
}

copy_rules() {
    local count=0
    if [ -d "$MT5_FILES" ]; then
        log "Kopiere rules_*.txt nach MT5"
        while IFS= read -r -d '' file; do
            if cp "$file" "$MT5_FILES/"; then
                ((count+=1))
            else
                log "❌ Fehler beim Kopieren: $(basename "$file")"
            fi
        done < <(find "$RULES_DIR" -maxdepth 1 -type f -name 'rules_*.txt' -print0 2>/dev/null)
        log "Regeln kopiert: $count"
    else
        log "⚠️ MT5 Files Verzeichnis nicht vorhanden – keine Rules kopiert"
    fi
}

cleanup_mt5_csv() {
    local deleted=0
    if [ "$DELETE_MQL5_CSVS" = true ] && [ -d "$MT5_FILES" ]; then
        log "Lösche CSV-Dateien in MT5 Files"
        for file in "$MT5_FILES"/*.csv; do
            [ -f "$file" ] || continue
            if rm -f "$file"; then
                ((deleted+=1))
            fi
        done
        log "CSV in MT5 gelöscht: $deleted"
    else
        log "CSV-Cleanup in MT5 übersprungen"
    fi
}

summary() {
    log "=== Weekly Update abgeschlossen ==="
    log "MT5 Pfad: $MT5_PATH"
    log "MT5 Files: $MT5_FILES"
    log "Python: $PYTHON_BIN"
}

main() {
    : > "$LOG_FILE"
    log "=== GOLDJUNGE WEEKLY UPDATE START ==="
    clean_temp_files
    SYMBOL_MOVED=false
    copy_symbol_export
    copy_all_csv
    run_config_processing
    run_data_export
    run_training
    copy_rules
    cleanup_mt5_csv
    summary
}

main "$@"
