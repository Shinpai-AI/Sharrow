@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\weekly_update.log"
set "DATA_DIR=%SCRIPT_DIR%"
set "RULES_DIR=%SCRIPT_DIR%"
set "DELETE_MQL5_CSVS=true"
set "WELLDONE_FILE=%SCRIPT_DIR%\welldone.txt"
set "WELLDONE_DATA_FILE=%SCRIPT_DIR%\welldone-TKB-Data.txt"
set "CONFIG_SCRIPT=%SCRIPT_DIR%\TKB-config-Bearbeitung.py"
set "DATA_EXPORT_SCRIPT=%SCRIPT_DIR%\TKB-Data-Export.py"
set "TRAIN_SCRIPT=%SCRIPT_DIR%\Train-KI-Bot.py"
set "SYMBOL_EXPORT_FILE=SymbolDataExport.csv"

call :config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\Program Files\MetaTrader 5"
call :config_path paths.mt5_files_subpath FILES_SUBPATH
if not defined FILES_SUBPATH set "FILES_SUBPATH=MQL5/Files"
set "MQL5_FILES=%MT5_PATH%\%FILES_SUBPATH%"
set "MQL5_FILES=%MQL5_FILES:/=\%"
call :config_path paths.mt5_logs_subpath LOGS_SUBPATH
if not defined LOGS_SUBPATH set "LOGS_SUBPATH=MQL5/Logs"
set "MQL5_LOGS=%MT5_PATH%\%LOGS_SUBPATH%"
set "MQL5_LOGS=%MQL5_LOGS:/=\%"
call :config_path paths.python_bin PYTHON_BIN
if not defined PYTHON_BIN set "PYTHON_BIN=python"
set "SYMBOL_MOVED=false"

>"%LOG_FILE%" (echo [%date% %time%] === SHARROW WEEKLY UPDATE START ===)
call :log "Arbeitsverzeichnis: %SCRIPT_DIR%"
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"

call :clean_temp_files
call :copy_symbol_export
call :copy_all_csv
call :run_config_processing
call :run_data_export
call :run_training
call :copy_rules
call :cleanup_mt5_csv
call :summary

echo SHARROW WEEKLY UPDATE abgeschlossen! Schau in: %LOG_FILE%
pause
exit /b 0

:clean_temp_files
set "DELETE_COUNT=0"
call :log "Starte Aufräumphase"
for %%F in ("%SCRIPT_DIR%\*") do (
    set "ITEM=%%~fF"
    set "BASE=%%~nxF"
    if exist "%%~fF\" (
        if /i "!BASE!"=="venv" (call :log "PROTECTED (Dir): !BASE!" & continue)
        if /i "!BASE!"=="__pycache__" (call :log "PROTECTED (Dir): !BASE!" & continue)
    ) else (
        echo !BASE! | findstr /r /c:"\.py$" /c:"\.mq5$" /c:"^RUN" /c:"config\.json" /c:"\.md$" /c:"_H1\.csv$" /c:"_M1\.csv$" /c:"_M15\.csv$" >nul
        if !errorlevel! equ 0 (call :log "PROTECTED: !BASE!" & continue)
    )
    del "%%~fF" >nul 2>&1
    if not errorlevel 1 set /a DELETE_COUNT+=1
)
call :log "Gelöschte Dateien: !DELETE_COUNT!"
exit /b 0

:copy_symbol_export
if exist "%MQL5_FILES%\%SYMBOL_EXPORT_FILE%" (
    call :log "SymbolDataExport gefunden – verschiebe nach Projekt"
    move "%MQL5_FILES%\%SYMBOL_EXPORT_FILE%" "%SCRIPT_DIR%\" >nul 2>&1
    if errorlevel 1 (
        call :log "❌ Verschieben fehlgeschlagen"
        set "SYMBOL_MOVED=false"
    ) else (
        set "SYMBOL_MOVED=true"
    )
) else (
    call :log "Keine SymbolDataExport.csv im MT5 Files"
    set "SYMBOL_MOVED=false"
)
exit /b 0

:copy_all_csv
set "CSV_COPY_COUNT=0"
if exist "%MQL5_FILES%\" (
    call :log "Kopiere CSV-Dateien aus MT5"
    for %%F in ("%MQL5_FILES%\*.csv") do (
        copy "%%~fF" "%DATA_DIR%\" >nul 2>&1
        if errorlevel 1 (
            call :log "❌ Fehler beim Kopieren: %%~nxF"
        ) else (
            set /a CSV_COPY_COUNT+=1
        )
    )
    call :log "CSV-Dateien kopiert: !CSV_COPY_COUNT!"
) else (
    call :log "⚠️ MT5 Files Verzeichnis nicht gefunden (%MQL5_FILES%)"
)
exit /b 0

:run_config_processing
if "%SYMBOL_MOVED%"=="true" if exist "%CONFIG_SCRIPT%" (
    call :log "Aktualisiere TKB-config mit Symboldaten"
    "%PYTHON_BIN%" "%CONFIG_SCRIPT%" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 call :log "❌ Config-Processing fehlgeschlagen"
) else (
    call :log "Config-Processing übersprungen"
)
exit /b 0

:run_data_export
if exist "%DATA_EXPORT_SCRIPT%" (
    call :log "Starte Datenexport"
    if exist "%WELLDONE_DATA_FILE%" del "%WELLDONE_DATA_FILE%" >nul 2>&1
    "%PYTHON_BIN%" "%DATA_EXPORT_SCRIPT%" --config "%CONFIG_FILE%" --dest "%DATA_DIR%" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
        call :log "❌ Datenexport fehlgeschlagen"
        exit /b 1
    )
    call :log "Datenexport abgeschlossen"
) else (
    call :log "❌ TKB-Data-Export.py nicht gefunden"
    exit /b 1
)
exit /b 0

:run_training
if not exist "%TRAIN_SCRIPT%" (
    call :log "⚠️ Train-KI-Bot.py fehlt – Training übersprungen"
    goto :eof
)
call :log "Starte Training"
"%PYTHON_BIN%" "%TRAIN_SCRIPT%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "❌ Training konnte nicht gestartet werden"
    exit /b 1
)
call :log "Training gestartet, warte auf welldone.txt"
set "TIMEOUT=0"
:wait_training
if exist "%WELLDONE_FILE%" goto training_done
ping -n 8 127.0.0.1 >nul
set /a TIMEOUT+=7
if !TIMEOUT! GEQ 7200 (
    call :log "❌ Training Timeout nach 120 Minuten"
    exit /b 1
)
goto wait_training

:training_done
call :log "Training abgeschlossen"
exit /b 0

:copy_rules
set "RULES_COUNT=0"
if exist "%MQL5_FILES%\" (
    call :log "Kopiere rules_*.txt nach MT5"
    for %%F in ("%RULES_DIR%\rules_*.txt") do (
        if exist "%%~fF" (
            copy "%%~fF" "%MQL5_FILES%\" >nul 2>&1
            if errorlevel 1 (
                call :log "❌ Fehler beim Kopieren: %%~nxF"
            ) else (
                set /a RULES_COUNT+=1
            )
        )
    )
    call :log "Regeln kopiert: !RULES_COUNT!"
) else (
    call :log "⚠️ MT5 Files Verzeichnis nicht vorhanden – keine Rules kopiert"
)
exit /b 0

:cleanup_mt5_csv
if /I "%DELETE_MQL5_CSVS%"=="true" if exist "%MQL5_FILES%\" (
    set "CSV_DELETE_COUNT=0"
    call :log "Lösche CSV-Dateien in MT5 Files"
    for %%F in ("%MQL5_FILES%\*.csv") do (
        del "%%~fF" >nul 2>&1
        if not errorlevel 1 set /a CSV_DELETE_COUNT+=1
    )
    call :log "CSV in MT5 gelöscht: !CSV_DELETE_COUNT!"
) else (
    call :log "CSV-Cleanup in MT5 übersprungen"
)
exit /b 0

:summary
call :log "=== Weekly Update abgeschlossen ==="
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"
exit /b 0

:log
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "TS=%%t"
echo [!TS!] %~1
>>"%LOG_FILE%" echo [!TS!] %~1
exit /b 0

:config_path
set "CFG_KEY=%~1"
set "RESULT="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "\
  $cfgPath = $env:CONFIG_FILE;\
  if (!(Test-Path $cfgPath)) { return };\
  $cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json;\
  $value = $cfg;\
  foreach ($part in $env:CFG_KEY.Split('.')) {\
    if ($null -eq $value) { break }\
    try { $value = $value | Select-Object -ExpandProperty $part -ErrorAction Stop }\
    catch { $value = $null }\
  }\
  if ($value -is [string] -and $value) {\
    if (-not [System.IO.Path]::IsPathRooted($value)) {\
      $base = Split-Path -Parent $cfgPath;\
      $value = [System.IO.Path]::GetFullPath((Join-Path $base $value))\
    }\
    Write-Output $value\
  } elseif ($value) {\
    Write-Output $value\
  }"`) do set "RESULT=%%i"
set "%~2=%RESULT%"
exit /b 0
