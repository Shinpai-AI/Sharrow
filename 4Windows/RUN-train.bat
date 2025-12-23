@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-train.log"
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
if not defined MT5_PATH set "MT5_PATH=C:\\Users\\Hanne\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075"
call :config_path paths.mt5_files_subpath FILES_SUBPATH
set "RESOLVE_SUB=%FILES_SUBPATH%"
call :resolve_mt5_child "MQL5/Files" MQL5_FILES
call :config_path paths.python_bin PYTHON_BIN
if not defined PYTHON_BIN set "PYTHON_BIN=python"

call :log "=== GOLDJUNGE TRAIN WORKFLOW START ==="
call :log "Arbeitsverzeichnis: %SCRIPT_DIR%"
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"

call :clean_temp_files
call :copy_symbol_export
call :copy_all_csv
call :run_config_processing
call :run_data_export || goto :fail
call :run_training || goto :fail
call :copy_rules
call :cleanup_mt5_csv
call :summary
goto :end

:fail
call :log "❌ TRAIN WORKFLOW abgebrochen"
exit /b 1

:end
exit /b 0

:clean_temp_files
set "DELETE_COUNT=0"
call :log "Starte Aufräumphase"
for %%F in ("%SCRIPT_DIR%\*") do (
    if exist "%%~fF\" (
        call :log "PROTECTED (Dir): %%~nxF"
    ) else (
        set "BASE=%%~nxF"
        call :is_protected_file "%%~nxF"
        if "!PROTECT_FLAG!"=="1" (
            call :log "PROTECTED: %%~nxF"
        ) else (
            del "%%~fF" >nul 2>&1
            if not errorlevel 1 set /a DELETE_COUNT+=1
        )
    )
)
call :log "Gelöschte Dateien: !DELETE_COUNT!"
exit /b 0

:is_protected_file
set "CHECK_NAME=%~1"
set "PROTECT_FLAG=0"
if /I "!CHECK_NAME:~-3!"==".py" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-4!"==".mq5" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-3!"==".md" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~0,3!"=="RUN" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-11!"=="config.json" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-7!"=="_H1.csv" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-7!"=="_M1.csv" set "PROTECT_FLAG=1"
if /I "!CHECK_NAME:~-8!"=="_M15.csv" set "PROTECT_FLAG=1"
exit /b 0

:copy_symbol_export
if exist "%MQL5_FILES%\%SYMBOL_EXPORT_FILE%" (
    call :log "SymbolDataExport gefunden – verschiebe nach Projekt"
    move "%MQL5_FILES%\%SYMBOL_EXPORT_FILE%" "%SCRIPT_DIR%\" >nul 2>&1
    if errorlevel 1 (
        call :log "❌ Verschieben fehlgeschlagen"
    )
) else (
    call :log "Keine SymbolDataExport.csv im MT5 Files"
)
exit /b 0

:copy_all_csv
set "CSV_COPY_COUNT=0"
if exist "%MQL5_FILES%\" (
    call :log "Kopiere CSV-Dateien aus MT5"
    for /f "usebackq delims=" %%F in (`dir /b /a:-d "%MQL5_FILES%\*.csv" 2^>nul`) do (
        set "SRC=%MQL5_FILES%\%%F"
        set "DEST=%DATA_DIR%\%%F"
        copy /Y "!SRC!" "!DEST!" >nul 2>&1
        if errorlevel 1 (
            call :log "❌ Fehler beim Kopieren: %%F"
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
set "EXPORT_PATH=%SCRIPT_DIR%\%SYMBOL_EXPORT_FILE%"
if exist "%CONFIG_SCRIPT%" if exist "%EXPORT_PATH%" (
    call :log "Aktualisiere TKB-config mit Symboldaten"
    "%PYTHON_BIN%" "%CONFIG_SCRIPT%" --import-symbols "%EXPORT_PATH%" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 call :log "❌ Config-Processing fehlgeschlagen"
) else (
    call :log "Config-Processing übersprungen"
)
exit /b 0

:run_data_export
if not exist "%DATA_EXPORT_SCRIPT%" (
    call :log "❌ TKB-Data-Export.py nicht gefunden"
    exit /b 1
)
call :log "Starte Datenexport"
if exist "%WELLDONE_DATA_FILE%" del "%WELLDONE_DATA_FILE%" >nul 2>&1
"%PYTHON_BIN%" "%DATA_EXPORT_SCRIPT%" --config "%CONFIG_FILE%" --dest "%DATA_DIR%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "❌ Datenexport fehlgeschlagen"
    exit /b 1
)
call :log "Datenexport abgeschlossen"
exit /b 0

:run_training
if not exist "%TRAIN_SCRIPT%" (
    call :log "⚠️ Train-KI-Bot.py fehlt – Training übersprungen"
    exit /b 0
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
    for /f "usebackq delims=" %%F in (`dir /b /a:-d "%RULES_DIR%\rules_*.txt" 2^>nul`) do (
        set "SRC=%RULES_DIR%\%%F"
        set "DEST=%MQL5_FILES%\%%F"
        copy /Y "!SRC!" "!DEST!" >nul 2>&1
        if errorlevel 1 (
            call :log "❌ Fehler beim Kopieren: %%F"
        ) else (
            set /a RULES_COUNT+=1
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
    for /f "usebackq delims=" %%F in (`dir /b /a:-d "%MQL5_FILES%\*.csv" 2^>nul`) do (
        del "%MQL5_FILES%\%%F" >nul 2>&1
        if not errorlevel 1 set /a CSV_DELETE_COUNT+=1
    )
    call :log "CSV in MT5 gelöscht: !CSV_DELETE_COUNT!"
) else (
    call :log "CSV-Cleanup in MT5 übersprungen"
)
exit /b 0

:summary
call :log "=== Training Workflow abgeschlossen ==="
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"
exit /b 0

:resolve_mt5_child
set "RESOLVE_DEFAULT=%~1"
set "TARGET_VAR=%~2"
if not defined RESOLVE_SUB set "RESOLVE_SUB="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$script = $env:SCRIPT_DIR; $sub = $env:RESOLVE_SUB; if (-not $sub) { $sub = $env:RESOLVE_DEFAULT }; $sub = $sub -replace '/', '\'; if ($script -and $sub -and $sub.StartsWith($script, [System.StringComparison]::OrdinalIgnoreCase)) { $sub = $sub.Substring($script.Length).TrimStart('\','/') }; if ($sub -and [System.IO.Path]::IsPathRooted($sub)) { $result = $sub } elseif ($env:MT5_PATH) { $result = [System.IO.Path]::Combine($env:MT5_PATH, $sub) } else { $result = $sub }; Write-Output $result"`) do set "%TARGET_VAR%=%%I"
set "RESOLVE_SUB="
set "RESOLVE_DEFAULT="
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
set "RESULT="
exit /b 0
