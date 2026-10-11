# Swagger Correction Guide

Use this guide only after the backend shows `Application startup complete`.
Open `http://127.0.0.1:8000/docs`.

## 1. Authorize as the administrator

1. Select **Authorize** at the top-right of Swagger.
2. In `username`, enter the administrator email address.
3. Enter the administrator password.
4. Leave `client_id` and `client_secret` empty.
5. Select **Authorize**, then **Close**.

Use an `ADMIN` or `MANAGER` account for the cleanup endpoints below.

## 2. Find and release a booking left by the earlier crash

The earlier Flutter crash could create a real `PAYMENT_PENDING` reservation
before the payment page appeared. That reservation correctly holds its slot, so
trying the same slot again returns `Slot is not available`.

1. Open **Admin**.
2. Run `GET /api/v1/admin/reservations` with:
   - `status`: leave empty
   - `limit`: `100`
3. Find the record using its vehicle number, user, area, or slot number.
4. Copy the reservation's `id` value. Do not copy its `slot_id` value.
5. Run `PUT /api/v1/admin/reservations/{reservation_id}/force-cancel`.
6. Paste the reservation UUID into `reservation_id` and execute.

This endpoint accepts `PAYMENT_PENDING`, `PENDING`, and `ACTIVE`. It changes
the reservation to `CANCELLED`, changes the linked slot to `VACANT`, and sends
the live slot update. Do not force-cancel `COMPLETED`, `CANCELLED`, or `EXPIRED`
records.

## 3. Verify the real slot status

1. Run `GET /api/v1/parking/areas`.
2. Copy the `id` of the required parking area, such as Smart Park Central.
3. Run `GET /api/v1/parking/areas/{area_id}/slots`.
4. Paste the parking-area UUID into `area_id`.
5. Leave `floor` and `status` empty to inspect every slot.

Each slot has two different identifiers:

- `id`: PostgreSQL UUID used in API paths and reservation requests.
- `slot_id`: readable number such as `A01`, `B02`, or `C03`.

For a genuine free slot, `status` must be exactly `VACANT`. The supported
status values are:

- `VACANT`
- `RESERVED`
- `OCCUPIED`
- `MAINTENANCE`

## 4. Correct a mismatched slot only when no live reservation owns it

Normally, booking, payment, ANPR entry, and final payment update status
automatically. Do not manually change an actively booked slot.

If a slot has no live reservation but its status is incorrect:

1. Copy the slot's PostgreSQL `id` from the slots response.
2. Open `PUT /api/v1/admin/slots/{slot_id}`.
3. Paste that UUID into the path parameter.
4. Use this request body:

```json
{
  "status": "VACANT",
  "slot_type": "STANDARD"
}
```

After execution, run the parking-area slots endpoint again and confirm that
the same readable slot number now reports `VACANT`.

## 5. Test a reservation as the user

1. In Swagger, select **Authorize**, then **Logout**.
2. Authorize again using the user-app account's email and password.
3. Run `GET /api/v1/parking/areas/{area_id}/slots` with `status=VACANT`.
4. Copy the selected slot's UUID from `id`.
5. Open `POST /api/v1/reservations/` and use:

```json
{
  "slot_id": "PASTE_SLOT_UUID_HERE",
  "parking_area_id": "PASTE_AREA_UUID_HERE",
  "start_time": "2026-09-02T18:00:00Z",
  "end_time": "2026-09-02T19:00:00Z",
  "vehicle_number": "KA01MN9787"
}
```

Replace both UUIDs and use the current date/time. A successful response has:

- reservation `status`: `PAYMENT_PENDING`
- nested `slot.slot_id`: the readable slot number
- nested `slot.status`: `RESERVED`
- `vehicle_number`: the normalized plate number
- `total_amount`: `10.00`

## 6. Optionally test the ₹10 Razorpay order

Keep Swagger authorized as the same user who created the reservation.

1. Copy the reservation `id` from the previous response.
2. Open `POST /api/v1/payments/create-order`.
3. Use:

```json
{
  "reservation_id": "PASTE_RESERVATION_UUID_HERE",
  "amount": 1000,
  "currency": "INR",
  "purpose": "ADVANCE"
}
```

`amount` is in paise, so ₹10 is `1000`. A successful response contains a real
Razorpay `order_id`, amount `1000`, currency `INR`, and the public `key_id`.

Do not enter invented values in `POST /api/v1/payments/verify-payment`.
Verification requires the real `razorpay_payment_id`, `razorpay_order_id`, and
signature produced by a successful Razorpay Checkout. Use the user app for this
step. The secret key must remain only in `backend/.env`.

After successful verification, `GET /api/v1/reservations/active` shows
reservation status `PENDING` and `advance_paid: true`. Without payment it stays
`PAYMENT_PENDING` with `advance_paid: false`; both states are accepted by the
entry camera during the 30-minute window.

## 7. Test the laptop entry camera

Authorize Swagger as `ADMIN`, `MANAGER`, `OPERATOR`, or `SECURITY`.

Run `POST /api/v1/gate/camera/start`:

```json
{
  "mode": "ENTRY",
  "parking_area_id": "PASTE_AREA_UUID_HERE",
  "camera_index": 0
}
```

Present the same vehicle number entered in the reservation. After two matching
OCR readings:

- reservation becomes `ACTIVE`;
- slot becomes `OCCUPIED`;
- `actual_check_in` is recorded;
- parking timer starts;
- simulated entry gate opens for four seconds.

Use `GET /api/v1/gate/status` and `GET /api/v1/gate/events` to verify the scan.

## 8. Test exit

Run `PUT /api/v1/gate/mode`:

```json
{
  "mode": "EXIT",
  "parking_area_id": "PASTE_AREA_UUID_HERE"
}
```

Scan the same vehicle number. The reservation becomes
`CHECKOUT_PAYMENT_PENDING` and the timer stops. The slot remains `OCCUPIED`
until the final Razorpay payment is verified. After verification, the
reservation becomes `COMPLETED`, the slot becomes `VACANT`, and the exit gate
opens.

When finished, run `POST /api/v1/gate/camera/stop`.

## 9. Test W01/W02 walk-in parking

Keep Swagger authorized as an admin/operator and scan a plate in Entry Mode
that has no prebooking.

1. Run `GET /api/v1/gate/walk-in-slots` with the parking-area UUID.
2. Copy the UUID from the `id` field of vacant W01 or W02.
3. Run `POST /api/v1/gate/walk-ins/admit`:

```json
{
  "parking_area_id": "PASTE_AREA_UUID_HERE",
  "slot_id": "PASTE_W01_OR_W02_UUID_HERE",
  "vehicle_number": "KA01MN9787"
}
```

The `vehicle_number` must be the plate just detected by the running Entry Mode
camera. On exit, switch to Exit Mode and scan it again. Copy
`last_reservation_id` from `GET /api/v1/gate/status`, then run
`POST /api/v1/gate/walk-ins/{reservation_id}/payment` with either:

```json
{
  "method": "CASH"
}
```

or `"method": "UPI"`. The backend records the final amount and payment method,
opens the gate for four seconds, completes the reservation, and releases the W
slot.

## Do not manually call during the normal ANPR demonstration

- `PUT /api/v1/reservations/{reservation_id}/check-in`
- `PUT /api/v1/reservations/{reservation_id}/check-out`

The gate camera should trigger entry and exit in the real project workflow.
