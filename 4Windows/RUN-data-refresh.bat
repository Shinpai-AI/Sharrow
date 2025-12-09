@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-data-refresh.log"
set "DATA_DIR=%SCRIPT_DIR%"

call :config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\\Users\\Hanne\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075"
call :config_path paths.mt5_files_subpath FILES_SUBPATH
if not defined FILES_SUBPATH set "FILES_SUBPATH=MQL5/Files"
set "FILES_SUBPATH=%FILES_SUBPATH:/=\%"
set "SCRIPT_PREFIX=%SCRIPT_DIR:/=\%"
set "FILES_SUBPATH_NO_PREFIX=%FILES_SUBPATH%"
set "FILES_SUBPATH_NO_PREFIX=%FILES_SUBPATH_NO_PREFIX:%SCRIPT_PREFIX%\=%"
if not "%FILES_SUBPATH_NO_PREFIX%"=="%FILES_SUBPATH%" (
    set "FILES_SUBPATH=%FILES_SUBPATH_NO_PREFIX%"
    if "%FILES_SUBPATH:~0,1%"=="\" set "FILES_SUBPATH=%FILES_SUBPATH:~1%"
)
set "MQL5_FILES=%FILES_SUBPATH%"
if not "%MQL5_FILES:~1,1%"==":" if not "%MQL5_FILES:~0,2%"=="\\" (
    if "%MQL5_FILES:~0,1%"=="\" set "MQL5_FILES=%MQL5_FILES:~1%"
    set "MQL5_FILES=%MT5_PATH%\%MQL5_FILES%"
)
set "MQL5_FILES=%MQL5_FILES:/=\%"
call :config_path paths.python_bin PYTHON_BIN
if not defined PYTHON_BIN set "PYTHON_BIN=python"
set "DATA_EXPORT_SCRIPT=%SCRIPT_DIR%\TKB-Data-Export.py"

call :log "=== SHARROW MONTHLY DATA REFRESH START ==="
call :log "Arbeitsverzeichnis: %SCRIPT_DIR%"
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"

call :delete_old_csv
call :copy_extend_files
call :run_data_export
call :analyze_new_csv
call :log "=== SHARROW DATA REFRESH COMPLETE ==="
exit /b 0

:delete_old_csv
set "DELETED_COUNT=0"
for %%T in (H1 M1 M15) do (
    for %%F in ("%DATA_DIR%\*%%T*.csv") do (
        if exist "%%~fF" (
            del "%%~fF" >nul 2>&1
            if not errorlevel 1 set /a DELETED_COUNT+=1
        )
    )
)
call :log "Gelöschte CSV-Dateien: !DELETED_COUNT!"
exit /b 0

:copy_extend_files
set "EXTEND_COUNT=0"
if exist "%MQL5_FILES%\" (
    call :log "Kopiere *_extend.csv aus %MQL5_FILES%"
    for %%F in ("%MQL5_FILES%\*_extend.csv") do (
        if exist "%%~fF" (
            copy "%%~fF" "%DATA_DIR%\" >nul 2>&1
            if errorlevel 1 (
                call :log "❌ Fehler beim Kopieren: %%~nxF"
            ) else (
                set /a EXTEND_COUNT+=1
            )
        )
    )
    call :log "Extend Files kopiert: !EXTEND_COUNT!"
) else (
    call :log "⚠️ MT5 Files Verzeichnis nicht gefunden (%MQL5_FILES%)"
)
exit /b 0

:run_data_export
if exist "%DATA_EXPORT_SCRIPT%" (
    call :log "Starte TKB-Data-Export.py"
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

:analyze_new_csv
set "NEW_COUNT=0"
set "START_DATE="
set "END_DATE="
for %%T in (H1 M1 M15) do (
    for %%F in ("%DATA_DIR%\*%%T*.csv") do (
        if exist "%%~fF" (
            set /a NEW_COUNT+=1
            for /f "usebackq skip=1 tokens=1 delims=;" %%a in ("%%~fF") do if not defined START_DATE set "START_DATE=%%a"
            for /f "usebackq tokens=1 delims=;" %%a in ("%%~fF") do set "END_DATE=%%a"
        )
    )
)
call :log "Neue CSV-Dateien erstellt: !NEW_COUNT!"
if defined START_DATE call :log "Datenbereich: !START_DATE! bis !END_DATE!"
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
