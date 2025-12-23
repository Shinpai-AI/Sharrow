@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-data-refresh.log"
set "DATA_DIR=%SCRIPT_DIR%"
set "DATA_EXPORT_SCRIPT=%SCRIPT_DIR%\TKB-Data-Export.py"
set "MARKER_FILE="

call :config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\\Users\\Hanne\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075"
call :config_path paths.mt5_files_subpath FILES_SUBPATH
set "RESOLVE_SUB=%FILES_SUBPATH%"
call :resolve_mt5_child "MQL5/Files" MQL5_FILES
call :config_path paths.python_bin PYTHON_BIN
if not defined PYTHON_BIN set "PYTHON_BIN=python"

call :log "=== GOLDJUNGE MONTHLY DATA REFRESH START ==="
call :log "Arbeitsverzeichnis: %SCRIPT_DIR%"
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"

call :delete_old_csv || goto :fail
call :copy_extend_files || goto :fail
call :create_marker || goto :fail
call :run_data_export || goto :fail
call :analyze_new_csv || goto :fail
call :log "=== GOLDJUNGE DATA REFRESH COMPLETE ==="
goto :cleanup

:fail
set "EXIT_CODE=1"
goto :cleanup

:cleanup
call :remove_marker
if not defined EXIT_CODE set "EXIT_CODE=0"
exit /b %EXIT_CODE%

:delete_old_csv
call :log "--- Phase 1: Lösche alte CSV-Dateien ---"
set "DELETED_COUNT=0"
for %%T in (H1 M1 M15) do (
    for /f "usebackq delims=" %%F in (`dir /b /a:-d "%DATA_DIR%\*%%T*.csv" 2^>nul`) do (
        del "%DATA_DIR%\%%F" >nul 2>&1
        if not errorlevel 1 set /a DELETED_COUNT+=1
    )
)
call :log "Gesamt gelöschte CSV-Dateien: !DELETED_COUNT!"
exit /b 0

:copy_extend_files
call :log "--- Phase 2: Kopiere MT5 Extend Files ---"
set "EXTEND_COUNT=0"
if exist "%MQL5_FILES%\" (
    for /f "usebackq delims=" %%F in (`dir /b /a:-d "%MQL5_FILES%\*_extend.csv" 2^>nul`) do (
        set "SRC=%MQL5_FILES%\%%F"
        set "DEST=%DATA_DIR%\%%F"
        if /I "!SRC!"=="!DEST!" (
            rem überspringe gleiche Datei
        ) else (
            copy /Y "!SRC!" "!DEST!" >nul 2>&1
            if errorlevel 1 (
                call :log "✗ FEHLER beim Kopieren von %%F"
            ) else (
                set /a EXTEND_COUNT+=1
            )
        )
    )
    call :log "Extend Files kopiert: !EXTEND_COUNT!"
) else (
    call :log "⚠️ WARNUNG: MT5 Verzeichnis nicht gefunden (%MQL5_FILES%)"
)
exit /b 0

:create_marker
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$path=[System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),'run-data-refresh-' + [guid]::NewGuid().ToString('N') + '.tmp'); New-Item -ItemType File -Path $path -Force | Out-Null; Write-Output $path"`) do set "MARKER_FILE=%%I"
if not defined MARKER_FILE (
    call :log "✗ FEHLER: Konnte temporäre Marker-Datei nicht erstellen"
    exit /b 1
)
exit /b 0

:run_data_export
if not exist "%DATA_EXPORT_SCRIPT%" (
    call :log "✗ FEHLER: TKB-Data-Export.py nicht gefunden!"
    exit /b 1
)
call :log "--- Phase 3: Starte TKB-Data-Export ---"
set "EXPORT_START="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "EXPORT_START=%%t"
"%PYTHON_BIN%" "%DATA_EXPORT_SCRIPT%" --config "%CONFIG_FILE%" --dest "%DATA_DIR%" >> "%LOG_FILE%" 2>&1
set "EXPORT_RESULT=%errorlevel%"
set "EXPORT_END="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "EXPORT_END=%%t"
if not "%EXPORT_RESULT%"=="0" (
    call :log "✗ TKB-Data-Export fehlgeschlagen (Exit Code: %EXPORT_RESULT%)"
    exit /b 1
)
call :log "✓ TKB-Data-Export erfolgreich (%EXPORT_START% → %EXPORT_END%)"
exit /b 0

:analyze_new_csv
call :log "--- Phase 4: Analysiere neue CSV-Dateien ---"
if not defined MARKER_FILE (
    call :log "⚠️ Marker nicht verfügbar – Analyse übersprungen"
    exit /b 0
)
set "NEW_COUNT=0"
set "START_DATE="
set "END_DATE="
for /f "usebackq tokens=1* delims==" %%A in (`powershell -NoProfile -Command "$marker = Get-Item -LiteralPath $env:MARKER_FILE -ErrorAction Stop; $dataDir = Get-Item -LiteralPath $env:DATA_DIR -ErrorAction Stop; $files = Get-ChildItem -LiteralPath $dataDir.FullName -File | Where-Object { $_.Name -like '*H1*.csv' -or $_.Name -like '*M1*.csv' -or $_.Name -like '*M15*.csv' }; $recent = $files | Where-Object { $_.LastWriteTime -gt $marker.LastWriteTime }; $count = $recent.Count; $start = $null; $end = $null; foreach ($file in $recent) { $first = $null; try { $first = (Get-Content -LiteralPath $file.FullName -TotalCount 2 | Select-Object -Last 1) } catch {}; if ($first) { $first = $first.Split(';')[0]; if (-not [string]::IsNullOrWhiteSpace($first)) { if (-not $start -or $first -lt $start) { $start = $first } } } $last = $null; try { $last = (Get-Content -LiteralPath $file.FullName -Tail 1) } catch {}; if ($last) { $last = $last.Split(';')[0]; if (-not [string]::IsNullOrWhiteSpace($last)) { if (-not $end -or $last -gt $end) { $end = $last } } } }; Write-Output ('COUNT={0}' -f $count); if ($start) { Write-Output ('START={0}' -f $start) } else { Write-Output 'START=' }; if ($end) { Write-Output ('END={0}' -f $end) } else { Write-Output 'END=' }"`) do (
    set "KEY=%%A"
    set "VAL=%%B"
    for /f "tokens=* delims= " %%G in ("!VAL!") do set "VAL=%%G"
    if /I "!KEY!"=="COUNT" set "NEW_COUNT=!VAL!"
    if /I "!KEY!"=="START" set "START_DATE=!VAL!"
    if /I "!KEY!"=="END" set "END_DATE=!VAL!"
)
call :log "Neue CSV-Dateien erstellt: !NEW_COUNT!"
if defined START_DATE if defined END_DATE (
    call :log "Datenbereich: !START_DATE! bis !END_DATE!"
) else (
    call :log "Datenbereich konnte nicht bestimmt werden"
)
exit /b 0

:remove_marker
if defined MARKER_FILE if exist "%MARKER_FILE%" del "%MARKER_FILE%" >nul 2>&1
set "MARKER_FILE="
exit /b 0

:log
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "TS=%%t"
echo [!TS!] %~1
>>"%LOG_FILE%" echo [!TS!] %~1
exit /b 0

:resolve_mt5_child
set "RESOLVE_DEFAULT=%~1"
set "TARGET_VAR=%~2"
if not defined RESOLVE_SUB set "RESOLVE_SUB="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$script = $env:SCRIPT_DIR; $sub = $env:RESOLVE_SUB; if (-not $sub) { $sub = $env:RESOLVE_DEFAULT }; $sub = $sub -replace '/', '\'; if ($script -and $sub -and $sub.StartsWith($script, [System.StringComparison]::OrdinalIgnoreCase)) { $sub = $sub.Substring($script.Length).TrimStart('\','/') }; if ($sub -and [System.IO.Path]::IsPathRooted($sub)) { $result = $sub } elseif ($env:MT5_PATH) { $result = [System.IO.Path]::Combine($env:MT5_PATH, $sub) } else { $result = $sub }; Write-Output $result"`) do set "%TARGET_VAR%=%%I"
set "RESOLVE_SUB="
set "RESOLVE_DEFAULT="
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
