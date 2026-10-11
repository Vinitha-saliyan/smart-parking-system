@echo off
cd /d "%~dp0"

echo Connecting phone to FastAPI backend...

"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

if errorlevel 1 (
    echo Connection failed. Check USB debugging.
    pause
    exit /b 1
)

echo Connection successful.
echo Starting Flutter...

flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

pause