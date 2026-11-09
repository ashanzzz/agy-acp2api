@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "PID_FILE=.agy2api.pid"
set "LOG_FILE=agy2api.log"
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

if /i "%ACTION%"=="stop" goto :do_stop
if /i "%ACTION%"=="status" goto :do_status
if /i "%ACTION%"=="fg" goto :do_fg
goto :do_start

:stop_existing
if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    if not "!OLD_PID!"=="" (
        tasklist /FI "PID eq !OLD_PID!" 2>nul | find /I "!OLD_PID!" >nul
        if !errorlevel! equ 0 (
            echo [INFO] 正在停止旧的后台进程 ^(PID: !OLD_PID!^)...
            taskkill /PID !OLD_PID! /T /F >nul 2>&1
        )
    )
    del /f /q "%PID_FILE%" >nul 2>&1
)
exit /b 0

:check_env
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 未检测到 Node.js，请先安装 Node.js ^(>= 22.5.0^): https://nodejs.org/
    pause
    exit /b 1
)
where agy >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] 未在 PATH 中检测到 agy 命令，请确认已安装 Antigravity CLI 或已设置 AGY_BIN 环境变量。
)
if not exist "node_modules" (
    echo [INFO] 首次运行，正在自动安装依赖 ^(npm install^)...
    call npm install
    if %errorlevel% neq 0 (
        echo [ERROR] 依赖安装失败，请检查网络或 npm 配置。
        pause
        exit /b 1
    )
)
exit /b 0

:do_stop
call :stop_existing
echo [OK] agy-acp2api 后台服务已停止。
exit /b 0

:do_status
if exist "%PID_FILE%" (
    set /p CUR_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !CUR_PID!" 2>nul | find /I "!CUR_PID!" >nul
    if !errorlevel! equ 0 (
        echo [OK] agy-acp2api 正在后台常驻运行 ^(PID: !CUR_PID!^)
    ) else (
        echo [WARN] agy-acp2api 当前未运行 ^(PID !CUR_PID! 已退出^)。
    )
) else (
    echo [WARN] agy-acp2api 当前未运行。
)
if exist "%LOG_FILE%" (
    echo --- 最近日志 ^(%LOG_FILE%^) ---
    powershell -NoProfile -Command "Get-Content -Path '%LOG_FILE%' -Tail 20"
)
exit /b 0

:do_fg
echo ========================================================
echo   agy-acp2api - 前台调试模式 ^(按 Ctrl+C 退出^)
echo ========================================================
call :check_env
if %errorlevel% neq 0 exit /b 1
call :stop_existing
call npx tsx --no-warnings src/index.ts --open
exit /b %errorlevel%

:do_start
echo ========================================================
echo   agy-acp2api - Antigravity ACP to OpenAI API Gateway
echo ========================================================
call :check_env
if %errorlevel% neq 0 exit /b 1
call :stop_existing

echo [INFO] 正在以常驻守护模式后台启动 agy-acp2api...
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c npx tsx --no-warnings src/index.ts --open > ""%LOG_FILE%"" 2>&1' -WorkingDirectory '%CD%' -WindowStyle Hidden -PassThru; $p.Id"`) do set "NEW_PID=%%i"

if "%NEW_PID%"=="" (
    echo [ERROR] 无法创建后台进程。
    exit /b 1
)

echo %NEW_PID%> "%PID_FILE%"
timeout /t 2 /nobreak >nul

tasklist /FI "PID eq %NEW_PID%" 2>nul | find /I "%NEW_PID%" >nul
if %errorlevel% equ 0 (
    echo [OK] 启动成功！已在后台无窗口常驻运行 ^(PID: %NEW_PID%^)，关闭本窗口不会中断服务。
    echo   - 查看状态: start.bat status
    echo   - 停止服务: start.bat stop
    echo   - 前台运行: start.bat fg
) else (
    echo [ERROR] 后台启动异常退出，最近日志如下：
    if exist "%LOG_FILE%" type "%LOG_FILE%"
    del /f /q "%PID_FILE%" >nul 2>&1
    exit /b 1
)
