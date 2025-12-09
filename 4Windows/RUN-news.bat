@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-news.log"
set "NEWS_DIR=%SCRIPT_DIR%"
set "SIGNAL_FILE=%NEWS_DIR%\welldone-News.txt"

call :config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\\Users\\Hanne\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075"
call :config_path paths.mt5_files_subpath FILES_SUBPATH
if not defined FILES_SUBPATH set "FILES_SUBPATH=MQL5/Files"
set "MQL5_FILES=%MT5_PATH%\%FILES_SUBPATH%"
set "MQL5_FILES=%MQL5_FILES:/=\%"
call :config_path paths.python_bin PYTHON_BIN
if not defined PYTHON_BIN set "PYTHON_BIN=python"
set "NEWS_SCRIPT_PATH=%SCRIPT_DIR%\TKB-News-Bot.py"

call :log "🚀 Sharrow News Workflow gestartet"
call :log "Arbeitsverzeichnis: %SCRIPT_DIR%"
call :log "MT5 Pfad: %MT5_PATH%"
call :log "MT5 Files: %MQL5_FILES%"
call :log "Python: %PYTHON_BIN%"

pushd "%NEWS_DIR%" >nul
call :log "🧹 Leere News-Verzeichnis"
del /q "*_Info.txt" 2>nul
if exist "welldone-News.txt" del "welldone-News.txt" 2>nul
popd >nul

call :log "🗑️ Lösche *_Info.txt in MQL5/Files"
if exist "%MQL5_FILES%\" (
    del /q "%MQL5_FILES%\*_Info.txt" 2>nul
) else (
    call :log "⚠️ MQL5/Files nicht gefunden (%MQL5_FILES%)"
)

if not exist "%NEWS_SCRIPT_PATH%" (
    call :log "❌ TKB-News-Bot.py fehlt"
    exit /b 1
)
call :log "🎯 Starte TKB-News-Bot.py"
"%PYTHON_BIN%" "%NEWS_SCRIPT_PATH%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
    call :log "❌ News-Bot Fehler"
    exit /b 1
)
call :log "✅ News-Bot abgeschlossen"

if exist "%SIGNAL_FILE%" (
    call :log "✅ welldone-News.txt gefunden"
) else (
    call :log "⚠️ Keine welldone-News.txt erstellt"
)

call :log "📋 Kopiere *_Info.txt nach MQL5/Files"
if not exist "%MQL5_FILES%\" (
    call :log "❌ MQL5/Files nicht vorhanden – Abbruch"
    exit /b 1
)

set "FILES_COPIED=0"
set "FILES_FAILED=0"
if exist "%NEWS_DIR%\*_Info.txt" (
    for %%F in ("%NEWS_DIR%\*_Info.txt") do (
        copy "%%~F" "%MQL5_FILES%\" >nul 2>&1
        if errorlevel 1 (
            set /a FILES_FAILED+=1
            call :log "❌ Fehler beim Kopieren: %%~nxF"
        ) else (
            set /a FILES_COPIED+=1
            call :log "📄 kopiert: %%~nxF"
        )
    )
) else (
    call :log "ℹ️ Keine *_Info.txt Dateien zum Kopieren gefunden"
)

call :log "=== News Workflow beendet ==="
call :log "📄 Erfolgreich kopiert: !FILES_COPIED!"
call :log "❌ Fehler: !FILES_FAILED!"

if !FILES_COPIED! GTR 0 if !FILES_FAILED! EQU 0 (
    echo ✅ SHARROW News Workflow SUCCESSFUL!
    exit /b 0
) else (
    echo ❌ SHARROW News Workflow FAILED!
    exit /b 1
)

goto :eof

:log
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "TS=%%t"
echo [%TS%] %~1
>>"%LOG_FILE%" echo [%TS%] %~1
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
