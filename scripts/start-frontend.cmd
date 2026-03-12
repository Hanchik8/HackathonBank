@echo off
setlocal
cd /d "%~dp0..\mobile"
if not exist "..\.codex-run" mkdir "..\.codex-run"
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000') do taskkill /PID %%a /F >nul 2>nul
start "hackathon-frontend" /b cmd /c "flutter run -d web-server --web-port 3000 1>..\.codex-run\frontend.log 2>..\.codex-run\frontend.err.log"
