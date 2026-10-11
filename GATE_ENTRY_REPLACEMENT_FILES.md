# Gate Entry Replacement Files

The complete project ZIP already contains these files in their correct paths.
Use this list only when copying the corrections into another copy of the same
project.

## Backend

- `backend/app/utils/vehicle_number.py`
- `backend/app/services/plate_recognition_service.py`
- `backend/app/services/gate_camera_service.py`
- `backend/app/services/reservation_service.py`
- `backend/app/services/auth_service.py`
- `backend/app/seed.py`
- `backend/app/database_migrations.py`
- `backend/app/routers/auth_router.py`
- `backend/app/schemas/gate_schema.py`
- `backend/app/schemas/user_schema.py`
- `backend/.env.example`
- `backend/tests/test_auth_tokens.py`
- `backend/tests/test_gate_camera_performance.py`
- `backend/tests/test_gate_reservation_matching.py`
- `backend/tests/test_plate_only_recognition.py`
- `backend/tests/test_vehicle_number.py`
- `backend/tests/test_walk_in_billing.py`

## Admin web application

- `admin_app/lib/data/services/api_service.dart`
- `admin_app/lib/data/repositories/auth_repository.dart`
- `admin_app/lib/domain/providers/auth_provider.dart`
- `admin_app/lib/data/models/gate_model.dart`
- `admin_app/lib/ui/gate_control/gate_control_screen.dart`

## User application

- `user_app/lib/data/services/api_service.dart`
- `user_app/lib/data/repositories/auth_repository.dart`
- `user_app/lib/domain/providers/auth_provider.dart`

## Launcher and instructions

- `START_SMART_PARKING.bat`
- `ANPR_GATE_SETUP.md`
- `GATE_ENTRY_WINDOWS_COMMANDS.md`

Keep the folder paths exactly as shown. Do not place backend Python files in
the Flutter folders or Dart files in the backend folder.
