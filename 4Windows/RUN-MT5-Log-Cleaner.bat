@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CONFIG_FILE=%SCRIPT_DIR%\TKB-config.json"
set "LOG_FILE=%SCRIPT_DIR%\RUN-MT5-Log-Cleaner.log"

call :config_path paths.mt5_path MT5_PATH
if not defined MT5_PATH set "MT5_PATH=C:\\Users\\Hanne\\AppData\\Roaming\\MetaQuotes\\Terminal\\D0E8209F77C8CF37AD8BF550E51FF075"
call :config_path paths.mt5_logs_subpath LOGS_SUBPATH
set "RESOLVE_SUB=%LOGS_SUBPATH%"
call :resolve_mt5_child "MQL5/Logs" MT5_LOG_DIR

if exist "%MT5_LOG_DIR%\" (
    del /q "%MT5_LOG_DIR%\*.log" 2>nul
    call :write_log "Logs in %MT5_LOG_DIR% gelöscht"
) else (
    call :write_log "Fehler: %MT5_LOG_DIR% existiert nicht"
)
exit /b 0

:write_log
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set "TS=%%t"
>>"%LOG_FILE%" echo [!TS!] %~1
echo [!TS!] %~1
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
