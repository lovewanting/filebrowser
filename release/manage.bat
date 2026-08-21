@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%manage.ps1"
set "EXE=%SCRIPT_DIR%filebrowser.exe"

set "PORT=6066"
set "ADDRESS=0.0.0.0"
set "ROOT=%USERPROFILE%"

:: If called with arguments, delegate to PowerShell directly
if not "%1"=="" (
    if /i "%1"=="console" goto :console
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
    exit /b %ERRORLEVEL%
)

:: ====== Interactive Menu (double-click) ======
:menu
cls
echo.
echo  ============================================
echo      File Browser 管理
echo  ============================================
echo.
echo      1. 启动服务 (后台运行)
echo      2. 停止服务
echo      3. 重启服务
echo      4. 查看状态
echo      5. 退出
echo.
echo  ============================================
echo.

choice /c 12345 /n /m "   请输入选项 (1-5): "

if errorlevel 5 exit /b 0
if errorlevel 4 goto :do_status
if errorlevel 3 goto :do_restart
if errorlevel 2 goto :do_stop
if errorlevel 1 goto :do_start

goto :menu

:do_start
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" start
echo.
pause
goto :menu

:do_stop
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" stop
echo.
pause
goto :menu

:do_restart
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" restart
echo.
pause
goto :menu

:do_status
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" status
echo.
pause
goto :menu

:console
if not exist "%EXE%" (
    echo Error: filebrowser.exe not found
    pause
    exit /b 1
)
echo [%TIME%] Starting File Browser in foreground (Ctrl+C to stop)
echo.
"%EXE%" --address "%ADDRESS%" --port "%PORT%" --root "%ROOT%" --database "%SCRIPT_DIR%filebrowser.db"
pause
exit /b 0