@echo off
cd /d "%~dp0"

echo Starting PostgreSQL and Redis...
docker compose up -d

if errorlevel 1 (
    echo ERROR: Docker services could not be started.
    pause
    exit /b 1
)

echo Starting FastAPI backend...
.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause