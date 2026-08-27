# YOLOv11 Recorded-Video Integration

This integration adds recorded parking-video processing without changing the
working authentication, reservation, payment, parking timer, billing, or
Flutter screens.

## What it does

1. Accepts an `.mp4`, `.avi`, `.mov`, or `.mkv` upload.
2. Starts a background processing job so a long upload does not cause an HTTP
   timeout.
3. Uses YOLOv11 to detect cars, motorcycles, buses, and trucks.
4. Maps vehicle boxes to the 20 fixed slot polygons in the supplied AI video.
5. Requires three matching observations before confirming occupancy, reducing
   flicker when a vehicle drives past a space.
6. Produces an annotated result video showing vehicle boxes and slot states.
7. Can update matching database slots and notify existing WebSocket clients.

## Safety rules that protect working components

- `update_database` defaults to `false`. The first run is preview-only.
- `RESERVED`, maintenance, and other special states are never overwritten.
- YOLO may change `VACANT` to `OCCUPIED` after confirmation.
- YOLO does **not** automatically change `OCCUPIED` to `VACANT` by default.
  The existing checkout and Razorpay verification remain responsible for
  releasing a paid parking slot.
- A missing YOLO model does not prevent the remaining backend from starting;
  the model loads only when detection is requested.
- Uploaded source files are removed after processing. Result videos remain
  available until the job is deleted or the operating-system temporary folder
  is cleaned.

## Required libraries

The existing `backend/requirements.txt` already contains everything needed:

- `ultralytics` — YOLOv11 inference
- `opencv-python-headless` — video reading, output, and polygon calculations
- `numpy` — frame and coordinate arrays
- `python-multipart` — FastAPI file uploads

Do not install another YOLO or OpenCV package.

## Step 1 — Apply and verify the code patch

Run these commands in Command Prompt after applying the provided patch:

```cmd
cd /d C:\Users\HP\Downloads\smart_parking_system-main\backend
call .venv\Scripts\activate.bat
python -m pip install -r requirements.txt
python -m compileall app
```

The first YOLO request may download `yolo11n.pt`. It is then cached locally for
later runs. If you already have the model, set its location in `backend/.env`:

```env
YOLO_MODEL_PATH=yolo11n.pt
```

## Step 2 — Start the existing backend

```cmd
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Open:

```text
http://127.0.0.1:8000/docs
```

## Step 3 — Find the parking-area ID

In Swagger, open:

```text
GET /api/v1/parking/areas
```

Click **Try it out** and **Execute**, then copy the required area's `id` UUID.

## Step 4 — Preview the uploaded video safely

Open:

```text
POST /api/v1/detection/videos
```

Use these values:

| Field | First-test value |
| --- | --- |
| `file` | `Create_a_photorealistic_fixed_.mp4` |
| `area_id` | UUID copied in Step 3 |
| `floor` | Floor containing A01–E01, normally `1` |
| `layout_name` | `generated_parking_1280x720` |
| `repeat_count` | `1` |
| `update_database` | `false` |
| `save_annotated_video` | `true` |

Click **Execute**. The response returns a `job_id`.

## Step 5 — Check progress and result

Open:

```text
GET /api/v1/detection/jobs/{job_id}
```

Paste the returned `job_id` and execute until `status` is `completed`. Then
open:

```text
GET /api/v1/detection/jobs/{job_id}/video
```

Click **Download file** and confirm that every green/red polygon matches the
correct physical space.

## Step 6 — Enable database updates

Only after the annotated preview is correct, upload the video again with:

```text
update_database = true
```

YOLO will update matching vacant slots to occupied. It will not release an
occupied or reserved slot, so the existing payment and checkout workflow stays
in control.

## Simulating one hour with the 10-second AI video

The supplied clip is approximately 10 seconds. Set:

```text
repeat_count = 360
```

This simulates one hour without creating and uploading a very large duplicate
file. Use `repeat_count = 1` until the initial test works because one hour of
CPU inference takes considerably longer on an 8 GB laptop.

## Endpoints added

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/detection/model` | Model status; use `load=true` to test loading |
| `GET /api/v1/detection/layouts/default` | View the calibrated 20-slot layout |
| `POST /api/v1/detection/videos` | Upload and start processing |
| `GET /api/v1/detection/jobs` | List detection jobs |
| `GET /api/v1/detection/jobs/{job_id}` | Check progress and occupancy |
| `POST /api/v1/detection/jobs/{job_id}/stop` | Stop a long-running job |
| `GET /api/v1/detection/jobs/{job_id}/video` | Download annotated result |
| `DELETE /api/v1/detection/jobs/{job_id}` | Remove a completed job and result |

## Important calibration note

The included slot layout is calibrated specifically for the uploaded
`1280 × 720` fixed-camera AI video. A future real CCTV camera will require its
own polygon layout because its camera angle and parking-space coordinates will
be different.
