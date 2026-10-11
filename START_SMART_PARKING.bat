@echo off
setlocal EnableExtensions
title Smart Parking System Launcher
color 0A

cd /d "%~dp0"
set "PROJECT_ROOT=%CD%"
set "BACKEND_DIR=%PROJECT_ROOT%\backend"
set "ADMIN_DIR=%PROJECT_ROOT%\admin_app"
set "USER_DIR=%PROJECT_ROOT%\user_app"
set "PYTHON_EXE=%BACKEND_DIR%\.venv\Scripts\python.exe"

echo ============================================================
echo          AI SMART PARKING SYSTEM - STARTING
echo ============================================================
echo.

if not exist "%BACKEND_DIR%\app\main.py" goto :project_error
if not exist "%ADMIN_DIR%\pubspec.yaml" goto :project_error
if not exist "%USER_DIR%\pubspec.yaml" goto :project_error

echo Opening the complete project in Visual Studio Code...
where code >nul 2>&1
if errorlevel 1 (
    echo WARNING: The VS Code command "code" is not available in PATH.
    echo The project services will still start normally.
) else (
    start "" code "%PROJECT_ROOT%"
)
echo.

echo [1/5] Checking Docker Desktop...
where docker >nul 2>&1
if errorlevel 1 goto :docker_missing

docker info >nul 2>&1
if errorlevel 1 goto :docker_not_running

echo [2/5] Starting PostgreSQL and Redis...
pushd "%BACKEND_DIR%"
docker compose up -d
if errorlevel 1 (
    popd
    goto :docker_compose_error
)
popd

echo [3/5] Checking the Python environment...
if exist "%PYTHON_EXE%" goto :venv_ready

where py >nul 2>&1
if errorlevel 1 goto :python_missing

py -3.12 --version >nul 2>&1
if errorlevel 1 goto :python_312_missing

echo Creating backend Python 3.12 environment...
pushd "%BACKEND_DIR%"
py -3.12 -m venv .venv
if errorlevel 1 (
    popd
    goto :venv_error
)
popd

:venv_ready
echo Checking backend packages...
"%PYTHON_EXE%" -c "import fastapi,uvicorn,sqlalchemy,asyncpg,redis,cv2,ultralytics,easyocr,razorpay,jose,bcrypt,qrcode,PIL" >nul 2>&1
if not errorlevel 1 goto :dependencies_ready

echo Installing backend and ANPR packages. First setup can take time...
"%PYTHON_EXE%" -m pip install --upgrade pip
if errorlevel 1 goto :dependency_error

"%PYTHON_EXE%" -m pip install -r "%BACKEND_DIR%\requirements.txt"
if errorlevel 1 goto :dependency_error

:dependencies_ready
echo [4/5] Checking Flutter...
where flutter >nul 2>&1
if errorlevel 1 goto :flutter_missing

if not exist "%BACKEND_DIR%\.env" (
    echo.
    echo WARNING: backend\.env was not found.
    echo The applications will open, but Razorpay requires your key ID and secret.
    echo Never put the Razorpay secret inside the Flutter applications.
    echo.
)

echo [5/5] Opening the project components in Command Prompt...

start "Smart Parking - Backend" /D "%BACKEND_DIR%" cmd /k ".venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

start "Smart Parking - Admin Web" /D "%ADMIN_DIR%" cmd /k "flutter pub get ^&^& flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1"

start "Smart Parking - User App" /D "%USER_DIR%" cmd /k "flutter pub get ^&^& call run_phone.bat"

echo.
echo Three Command Prompt windows have been opened:
echo   1. FastAPI backend
echo   2. Admin web application
echo   3. User application on the USB-connected phone
echo.
echo Swagger will open automatically. Keep all three windows open.
timeout /t 8 /nobreak >nul
start "" "http://127.0.0.1:8000/docs"
exit /b 0

:project_error
echo ERROR: This BAT file is not inside the correct project folder.
echo Put START_SMART_PARKING.bat beside backend, admin_app and user_app.
goto :failed

:docker_missing
echo ERROR: Docker is not installed or is not available in PATH.
echo Install or repair Docker Desktop, then run this file again.
goto :failed

:docker_not_running
echo ERROR: Docker Desktop is installed but is not running.
echo Open Docker Desktop, wait until it says Engine running, then retry.
goto :failed

:docker_compose_error
echo ERROR: PostgreSQL or Redis could not be started.
echo Check the Docker Desktop containers and the messages above.
goto :failed

:python_missing
echo ERROR: The Python launcher was not found.
echo Install Python 3.12 and enable the Python launcher during installation.
goto :failed

:python_312_missing
echo ERROR: Python 3.12 is required but was not found.
echo Install Python 3.12, then run this file again.
goto :failed

:venv_error
echo ERROR: The backend Python environment could not be created.
goto :failed

:dependency_error
echo ERROR: Backend package installation failed.
echo Check your internet connection and the installation error above.
goto :failed

:flutter_missing
echo ERROR: Flutter is not available in PATH.
echo Run flutter doctor in a new Command Prompt and fix the reported issue.
goto :failed

:failed
echo.
pause
exit /b 1
