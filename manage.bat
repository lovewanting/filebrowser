@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ===== 配置修改区（按需改）=====
set PORT=6066
set ADDRESS=0.0.0.0
set ROOT=%USERPROFILE%
set EXE_NAME=filebrowser.exe
set EXE=%~dp0filebrowser.exe
set DB=%~dp0filebrowser.db
set LOG=%~dp0filebrowser.log
set TITLE=FileBrowser
:: ================================

if "%1"=="" (
    echo.
    echo  用法: manage.bat [命令]
    echo.
    echo  命令:
    echo    start      启动服务（后台运行）
    echo    stop       停止服务
    echo    restart    重启服务
    echo    status     查看运行状态
    echo    console    前台启动（查看实时日志）
    echo.
    exit /b 1
)

if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="status" goto status
if "%1"=="console" goto console

echo 未知命令: %1
exit /b 1

:start
echo [%TIME%] 正在启动 %TITLE%...
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>nul | find /I "%EXE_NAME%" >nul 2>nul
if !errorlevel! equ 0 (
    echo [!] %TITLE% 已在运行中，请先执行 stop 或使用 restart。
    exit /b 1
)

:: 检查 exe 是否存在
if not exist "%EXE%" (
    echo [!] 找不到 %EXE%
    exit /b 1
)

:: 后台启动，日志重定向到文件
start "%TITLE%" "%EXE%"^
    --address "%ADDRESS%"^
    --port "%PORT%"^
    --root "%ROOT%"^
    --database "%DB%"^
    >> "%LOG%" 2>&1

:: 等一会确认启动
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>nul | find /I "%EXE_NAME%" >nul
if !errorlevel! equ 0 (
    echo [OK] %TITLE% 启动成功
    echo     地址: http://%ADDRESS%:%PORT%
    echo     日志: %LOG%
) else (
    echo [!] %TITLE% 启动失败，查看日志: %LOG%
)
goto end

:stop
echo [%TIME%] 正在停止 %TITLE%...
:: 通过窗口标题精确关闭（避免误杀同名进程）
taskkill /FI "WINDOWTITLE eq %TITLE%" /F >nul 2>nul

:: 如果标题匹配不到，再按 exe 名停
taskkill /IM "%EXE_NAME%" /F >nul 2>nul

echo [OK] %TITLE% 已停止
goto end

:restart
call :stop
timeout /t 2 /nobreak >nul
call :start
goto end

:status
echo.
echo ===== %TITLE% 运行状态 =====
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>nul | find /I "%EXE_NAME%" >nul
if !errorlevel! equ 0 (
    echo  状态: 运行中
    for /f "tokens=2 delims=," %%a in ('wmic process where "name='%EXE_NAME%'" get ProcessId /format:csv 2^>nul ^| findstr /r "[0-9]"') do echo  PID: %%a

    :: 查询监听端口
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr LISTENING') do (
        echo  端口: %PORT%
    )
) else (
    echo  状态: 未运行
)
echo  进程名: %EXE_NAME%
echo  数据库: %DB%
echo  日志文件: %LOG%
if exist "%LOG%" (
    for %%f in ("%LOG%") do echo  日志大小: %%~zf 字节
)
echo ==============================
echo.
goto end

:console
echo [%TIME%] 前台启动 %TITLE%...
echo 按 Ctrl+C 停止
echo.
"%EXE%" --address "%ADDRESS%" --port "%PORT%" --root "%ROOT%" --database "%DB%"
goto end

:end
endlocal