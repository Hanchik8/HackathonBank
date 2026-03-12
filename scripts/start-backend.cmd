@echo off
setlocal
cd /d "%~dp0.."
if not exist ".codex-run" mkdir ".codex-run"
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080') do taskkill /PID %%a /F >nul 2>nul
start "hackathon-backend" /b cmd /c ".\mvnw.cmd -q -DskipTests spring-boot:run 1>.codex-run\backend.log 2>.codex-run\backend.err.log"
