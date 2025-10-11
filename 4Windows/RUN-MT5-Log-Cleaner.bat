@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-MT5-Log-Cleaner.log"
set "PYTHON_BIN=python"

call :get_config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\\Program Files\\MetaTrader 5"

call :get_config_path paths.mt5_logs_subpath LOGS_SUBPATH
if not defined LOGS_SUBPATH set "LOGS_SUBPATH=MQL5/Logs"

set "MT5_LOG_DIR=%MT5_PATH%\%LOGS_SUBPATH%"
set "MT5_LOG_DIR=%MT5_LOG_DIR:/=\%"

for /f "delims=" %%I in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "TS=%%I"

if exist "%MT5_LOG_DIR%" (
    del /q "%MT5_LOG_DIR%\*.log" 2>nul
    >>"%LOG_FILE%" echo [%TS%] Logs in %MT5_LOG_DIR% gelöscht
) else (
    >>"%LOG_FILE%" echo [%TS%] Fehler: %MT5_LOG_DIR% existiert nicht
)

exit /b 0

:get_config_path
set "__KEY=%~1"
for /f "usebackq delims=" %%I in (`"%PYTHON_BIN%" -c "import json, os, sys; cfg_path=sys.argv[1]; dotted=sys.argv[2]; data=json.load(open(cfg_path, 'r', encoding='utf-8')); value=data;\nfor part in dotted.split('.'): value=value.get(part, '') if isinstance(value, dict) else '';\nif isinstance(value, str) and value: print(os.path.normpath(os.path.join(os.path.dirname(cfg_path), value)) if not os.path.isabs(value) else value, end='')\nelse: print('', end='')" "%CONFIG_FILE%" "%__KEY%"`) do set "%~2=%%I"
exit /b 0
