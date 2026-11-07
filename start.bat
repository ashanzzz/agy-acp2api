@echo off
chcp 65001 >nul 2>&1
setlocal
cd /d "%~dp0"

echo ========================================================
echo   agy-acp2api - Antigravity ACP to OpenAI API Gateway
echo ========================================================

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

echo [INFO] 正在启动 agy-acp2api 网关并打开控制台...
call npx tsx --no-warnings src/index.ts --open %*

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] 网关异常退出 ^(Exit Code: %errorlevel%^)。
    pause
)
