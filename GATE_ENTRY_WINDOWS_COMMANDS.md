# Gate Entry — Exact Windows Run and Test Commands

## Fastest method

Extract the project to a normal folder such as:

```text
C:\Users\HP\Desktop\smart-parking-system-main
```

Keep `START_SMART_PARKING.bat` beside `backend`, `admin_app` and `user_app`.
Double-click it. The launcher opens the complete folder in VS Code and starts
PostgreSQL, Redis, FastAPI, the admin web app and the phone app.

You can also run it from the VS Code terminal:

```powershell
cd C:\Users\HP\Desktop\smart-parking-system-main
.\START_SMART_PARKING.bat
```

## Manual commands

Open Docker Desktop and wait until it reports that the engine is running.

### Command Prompt 1 — backend

```cmd
cd /d C:\Users\HP\Desktop\smart-parking-system-main\backend
docker compose up -d
py -3.12 -m venv .venv
.venv\Scripts\python.exe -m pip install --upgrade pip
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Create the virtual environment only on the first run. On later runs, execute
only `docker compose up -d` and the final Uvicorn command.

### Command Prompt 2 — admin web app

```cmd
cd /d C:\Users\HP\Desktop\smart-parking-system-main\admin_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

### Command Prompt 3 — user phone app

```cmd
cd /d C:\Users\HP\Desktop\smart-parking-system-main\user_app
flutter pub get
run_phone.bat
```

## Gate-entry test

1. Log in to the user app and reserve a vacant normal slot.
2. Enter `KA01MN9787` as the vehicle number.
3. The ₹10 payment is optional for entry.
4. Enter the admin web app and open **Gate Camera**.
5. Select **Entry Mode**, select the parking area and start the camera.
6. Hold a clear image of `KA01MN9787` inside the yellow box.
7. Confirm that the screen displays OCR confidence and decision time.
8. A valid reservation must change to `ACTIVE`, its slot must change to
   `OCCUPIED`, and the simulated gate must show `OPEN` for four seconds.

If the OCR initially reads `KA0MN9787`, the backend can match it to
`KA01MN9787` only when that is the single safe live reservation match. The
screen will display the raw reading and the matched booking separately.

## Backend verification tests

Stop the backend with `Ctrl+C`, then run:

```cmd
cd /d C:\Users\HP\Desktop\smart-parking-system-main\backend
.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Restart it afterward:

```cmd
.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Swagger checks

Open:

```text
http://127.0.0.1:8000/docs
```

Authorize using the admin account and check:

- `GET /api/v1/gate/status`
- `GET /api/v1/gate/events`
- `POST /api/v1/auth/refresh`

The refresh request body is:

```json
{
  "refresh_token": "the_refresh_token_returned_by_login"
}
```

Normally, the Flutter applications refresh tokens automatically; Swagger
testing is optional.

## Important troubleshooting

- Close Windows Camera, Zoom, Teams and other webcam applications.
- Allow desktop applications to access the camera in Windows privacy settings.
- Keep the plate straight, well lit and large inside the yellow guide.
- If the admin screen is redirected to login after this update, log in once to
  replace an older untyped refresh token.
- Razorpay credentials are not required to test entry. They are required only
  for a real advance or final Razorpay payment.
