# Windows setup: connected admin dashboard

The admin dashboard now reads live data from FastAPI. Keep the backend and
Flutter web app running in two separate **Command Prompt** terminals.

## 1. Start PostgreSQL and Redis

Open Command Prompt in the project folder:

```cmd
cd /d C:\Projects\smart_parking_system-main\backend
docker compose up -d
```

Check that both containers are running:

```cmd
docker compose ps
```

## 2. Prepare and seed the backend

PowerShell activation is not required. These commands call the virtual
environment directly:

```cmd
cd /d C:\Projects\smart_parking_system-main\backend
py -3.12 -m venv .venv
.venv\Scripts\python.exe -m pip install --upgrade pip
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m app.seed
```

The seed command creates or resets this development administrator:

- Email: `admin@smartparking.com`
- Password: `Admin@123`

## 3. Start FastAPI

```cmd
cd /d C:\Projects\smart_parking_system-main\backend
.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verify these pages before opening Flutter:

- API health: <http://127.0.0.1:8000/health>
- Swagger: <http://127.0.0.1:8000/docs>

Do not close this terminal.

## 4. Start the admin app in Chrome

Open a second Command Prompt terminal:

```cmd
cd /d C:\Projects\smart_parking_system-main\admin_app
flutter create . --platforms=web,android
flutter clean
flutter pub get
flutter run -d chrome
```

Log in with the seeded administrator above. Flutter web connects to
`http://127.0.0.1:8000/api/v1` automatically.

## Android emulator or physical phone

The Android emulator uses `http://10.0.2.2:8000/api/v1` automatically. For a
physical phone, replace `192.168.1.10` below with the laptop's IPv4 address:

```cmd
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
```

The phone and laptop must be on the same Wi-Fi network, and FastAPI must be
started with `--host 0.0.0.0`.

## What is live

- Admin login uses FastAPI OAuth2 form login and JWT tokens.
- Dashboard counts, occupancy, revenue, and seven-day revenue come from the
  PostgreSQL database.
- Parking areas, users, reservations, and camera status use admin API routes.
- Area activation, user suspension, and reservation cancellation update the
  database.
- Empty database sections show an empty state instead of invented sample data.
