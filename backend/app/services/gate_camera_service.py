from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any
from uuid import UUID

import cv2
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.database import AsyncSessionLocal
from app.models.gate_event import GateEvent
from app.models.parking_settlement import ParkingSettlement
from app.models.reservation import Reservation
from app.schemas.gate_schema import GateMode
from app.services.plate_recognition_service import PlateRecognitionService
from app.services.realtime_service import broadcast_gate_event as _broadcast_gate_event
from app.services.reservation_service import check_in, check_out
from app.utils.vehicle_number import is_safe_reservation_plate_match

logger = logging.getLogger(__name__)


async def broadcast_gate_event(area_id: Any, event: dict[str, Any]) -> None:
    """A notification failure must not block gate closure or undo a DB decision."""
    try:
        await asyncio.wait_for(_broadcast_gate_event(area_id, event), timeout=1.0)
    except Exception:
        logger.exception('Gate notification failed; status polling remains available')


class GateCameraService:
    """Own the laptop camera and convert stable OCR results into gate events."""

    def __init__(self) -> None:
        self.recognizer = PlateRecognitionService()
        self.mode: GateMode = "ENTRY"
        self.parking_area_id: UUID | None = None
        self.camera_index = settings.GATE_CAMERA_INDEX
        self.camera_running = False
        self.gate_state = "CLOSED"
        self.last_vehicle_number: str | None = None
        self.last_raw_vehicle_number: str | None = None
        self.last_ocr_confidence: float | None = None
        self.last_decision_seconds: float | None = None
        self.last_authorized: bool | None = None
        self.last_reservation_id: UUID | None = None
        self.last_slot_id: UUID | None = None
        self.last_slot_number: str | None = None
        self.last_booking_type: str | None = None
        self.last_amount_due: Any | None = None
        self.last_advance_paid: bool | None = None
        self.manual_payment_required = False
        self.message = "Camera is stopped"
        self.error: str | None = None
        self._camera_task: asyncio.Task[None] | None = None
        self._recognition_task: asyncio.Task[None] | None = None
        self._close_task: asyncio.Task[None] | None = None
        self._latest_frame: bytes | None = None
        self._recognition_epoch = 0
        self._recognition_scan_count = 0
        self._candidate_plate: str | None = None
        self._candidate_count = 0
        self._candidate_started_at: float | None = None
        self._last_processed: dict[tuple[str, str], float] = {}

    async def start(
        self,
        mode: GateMode,
        parking_area_id: UUID,
        camera_index: int,
    ) -> None:
        await self.set_mode(mode, parking_area_id)
        self.camera_index = camera_index
        if self.camera_running:
            return

        self.camera_running = True
        self.error = None
        self.message = f"Starting laptop camera in {mode.lower()} mode"
        self._camera_task = asyncio.create_task(self._camera_loop())

    async def stop(self) -> None:
        self.camera_running = False
        self._recognition_epoch += 1
        recognition_task = self._recognition_task
        self._recognition_task = None
        if recognition_task:
            recognition_task.cancel()
            try:
                await recognition_task
            except asyncio.CancelledError:
                pass
        task = self._camera_task
        self._camera_task = None
        if task:
            try:
                await asyncio.wait_for(task, timeout=3)
            except asyncio.TimeoutError:
                task.cancel()
            except asyncio.CancelledError:
                pass
        self.message = "Camera is stopped"

    async def set_mode(
        self,
        mode: GateMode,
        parking_area_id: UUID,
    ) -> None:
        if self.gate_state == 'OPEN':
            raise HTTPException(status_code=409, detail='Wait for the gate to close before changing mode')
        if self._close_task:
            self._close_task.cancel()
            self._close_task = None
        self.mode = mode
        self.parking_area_id = parking_area_id
        self._recognition_epoch += 1
        self._recognition_scan_count = 0
        self._candidate_plate = None
        self._candidate_count = 0
        self._candidate_started_at = None
        self.last_vehicle_number = None
        self.last_raw_vehicle_number = None
        self.last_ocr_confidence = None
        self.last_decision_seconds = None
        self.last_authorized = None
        self.gate_state = "CLOSED"
        self._remember_session(None)
        self.error = None
        self.message = f"{mode.title()} recognition ready"

    def status(self) -> dict[str, Any]:
        return {
            "camera_running": self.camera_running,
            "camera_index": self.camera_index,
            "mode": self.mode,
            "parking_area_id": self.parking_area_id,
            "gate_state": self.gate_state,
            "last_vehicle_number": self.last_vehicle_number,
            "last_raw_vehicle_number": self.last_raw_vehicle_number,
            "last_ocr_confidence": self.last_ocr_confidence,
            "last_decision_seconds": self.last_decision_seconds,
            "last_authorized": self.last_authorized,
            "message": self.message,
            "error": self.error,
            "yolo_loaded": self.recognizer.yolo.is_loaded,
            "ocr_loaded": self.recognizer.ocr_loaded,
            "last_reservation_id": self.last_reservation_id,
            "last_slot_id": self.last_slot_id,
            "last_slot_number": self.last_slot_number,
            "last_booking_type": self.last_booking_type,
            "last_amount_due": self.last_amount_due,
            "last_advance_paid": self.last_advance_paid,
            "manual_payment_required": self.manual_payment_required,
        }

    def snapshot(self) -> bytes | None:
        return self._latest_frame

    @staticmethod
    def _open_capture(camera_index: int) -> cv2.VideoCapture:
        if os.name == "nt":
            capture = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
            if capture.isOpened():
                return capture
            capture.release()
        return cv2.VideoCapture(camera_index)

    async def _camera_loop(self) -> None:
        capture: cv2.VideoCapture | None = None
        try:
            capture = await asyncio.to_thread(
                self._open_capture,
                self.camera_index,
            )
            if not capture.isOpened():
                raise RuntimeError(
                    "Laptop camera could not be opened. Close other camera "
                    "applications and check Windows camera permission."
                )

            # MJPG lets most Windows webcams deliver 720p without transferring
            # large uncompressed frames through the CPU on every capture.
            capture.set(
                cv2.CAP_PROP_FOURCC,
                cv2.VideoWriter_fourcc(*"MJPG"),
            )
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
            capture.set(cv2.CAP_PROP_FPS, 30)
            capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            # Publish a raw preview first, then start with lightweight
            # guide-box OCR. Comprehensive YOLO/full-frame work is periodic.
            last_detection_at = time.monotonic()
            last_preview_at = 0.0
            preview_interval = 1.0 / max(settings.GATE_PREVIEW_FPS, 1.0)
            self.message = f"Camera active in {self.mode.lower()} mode"

            while self.camera_running:
                ok, frame = await asyncio.to_thread(capture.read)
                if not ok or frame is None:
                    await asyncio.sleep(0.1)
                    continue

                now = time.monotonic()
                recognition_task = self._recognition_task
                if recognition_task is not None and recognition_task.done():
                    try:
                        recognition_task.result()
                    except asyncio.CancelledError:
                        pass
                    self._recognition_task = None

                if (
                    now - last_detection_at
                    >= settings.GATE_DETECTION_INTERVAL_SECONDS
                    and self._recognition_task is None
                    and self.error is None
                    and self.gate_state != 'OPEN'
                ):
                    last_detection_at = now
                    self._recognition_scan_count += 1
                    run_yolo = self._is_comprehensive_scan(
                        self._recognition_scan_count
                    )
                    self._recognition_task = asyncio.create_task(
                        self._recognize_frame(
                            frame.copy(),
                            self._recognition_epoch,
                            run_yolo,
                        )
                    )

                if now - last_preview_at >= preview_interval:
                    last_preview_at = now
                    preview = frame.copy()
                    self._draw_gate_overlay(preview)
                    success, encoded = cv2.imencode(
                        ".jpg",
                        preview,
                        [
                            cv2.IMWRITE_JPEG_QUALITY,
                            settings.GATE_PREVIEW_JPEG_QUALITY,
                        ],
                    )
                    if success:
                        self._latest_frame = encoded.tobytes()
                await asyncio.sleep(0.005)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            self.error = str(exc)
            self.message = str(exc)
            logger.exception("Gate camera processing failed")
        finally:
            self.camera_running = False
            self._recognition_epoch += 1
            recognition_task = self._recognition_task
            if recognition_task is not None:
                recognition_task.cancel()
                self._recognition_task = None
                try:
                    await recognition_task
                except asyncio.CancelledError:
                    pass
            if capture is not None:
                await asyncio.to_thread(capture.release)

    @staticmethod
    def _is_comprehensive_scan(scan_count: int) -> bool:
        """Keep the first response fast and run YOLO periodically."""
        every = max(settings.GATE_YOLO_EVERY_N_SCANS, 1)
        return scan_count % every == 0

    async def _recognize_frame(
        self,
        frame: Any,
        epoch: int,
        run_yolo: bool,
    ) -> None:
        """Run heavy AI work without pausing the live camera preview."""
        scan_started_at = time.monotonic()
        try:
            result = await asyncio.to_thread(
                self.recognizer.recognize,
                frame,
                run_yolo=run_yolo,
                full_frame_fallback=run_yolo,
            )
            if not self.camera_running or epoch != self._recognition_epoch:
                return
            if self.gate_state == 'OPEN':
                return
            if time.monotonic() - scan_started_at > settings.GATE_MAX_SCAN_SECONDS:
                self._candidate_count = 0
                self._candidate_plate = None
                self.message = 'Scan too slow; hold plate steady and reduce other CPU work'
                return
            if result.vehicle_number:
                await self._observe_plate(
                    result.vehicle_number,
                    result.confidence,
                    scan_started_at=scan_started_at,
                )
            else:
                self._candidate_count = 0
                self._candidate_plate = None
                self._candidate_started_at = None
                if self.gate_state != 'PAYMENT_REQUIRED':
                    self.message = ('Multiple plates visible; show one plate only'
                                    if result.vehicles_detected > 1 else
                                    'Waiting for a clear plate inside the guide')
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            if self.camera_running and epoch == self._recognition_epoch:
                self.error = str(exc)
                self.message = f"Recognition error: {exc}"
            logger.exception("Gate recognition failed")

    async def _observe_plate(
        self,
        vehicle_number: str,
        confidence: float | None,
        scan_started_at: float | None = None,
    ) -> None:
        key = (self.mode, vehicle_number)
        now = time.monotonic()
        if self.gate_state == 'OPEN' or confidence is None or not 0.65 <= confidence <= 1:
            return
        if (self._candidate_started_at is not None and
                now - self._candidate_started_at > settings.GATE_CONFIRM_WINDOW_SECONDS):
            self._candidate_plate = None
            self._candidate_count = 0
        last_time = self._last_processed.get(key, float('-inf'))
        if now - last_time < settings.GATE_DUPLICATE_COOLDOWN_SECONDS:
            return

        # Show OCR output immediately, even while a low-confidence result is
        # waiting for its second observation.
        self.last_raw_vehicle_number = vehicle_number
        self.last_vehicle_number = vehicle_number
        self.last_ocr_confidence = confidence
        self.last_authorized = None

        if vehicle_number == self._candidate_plate:
            self._candidate_count += 1
        else:
            self._candidate_plate = vehicle_number
            self._candidate_count = 1
            self._candidate_started_at = scan_started_at or now

        confirmations_required = max(2, settings.GATE_PLATE_CONFIRMATIONS)

        if self._candidate_count < confirmations_required:
            self.message = f"Confirming plate {vehicle_number} ({self._candidate_count}/{confirmations_required})"
            return

        self._last_processed[key] = now
        self._candidate_count = 0
        processed_number = await self._process_plate(vehicle_number, confidence)
        self._last_processed[(self.mode, processed_number)] = now
        started_at = self._candidate_started_at or scan_started_at or now
        self.last_decision_seconds = round(
            max(0.0, time.monotonic() - started_at),
            3,
        )
        self._candidate_started_at = None

    async def _find_reservation(
        self,
        db: Any,
        area_id: UUID,
        observed_number: str,
    ) -> tuple[Reservation | None, str, str | None]:
        statuses = (
            ["PAYMENT_PENDING", "PENDING", "ACTIVE", "CHECKOUT_PAYMENT_PENDING"]
            if self.mode == "ENTRY"
            else ["ACTIVE", "CHECKOUT_PAYMENT_PENDING"]
        )
        result = await db.execute(
            select(Reservation)
            .options(selectinload(Reservation.slot))
            .filter(
                Reservation.parking_area_id == area_id,
                Reservation.status.in_(statuses),
            )
            .order_by(Reservation.created_at.desc())
        )
        reservations = list(result.scalars().all())

        exact = next(
            (
                reservation
                for reservation in reservations
                if reservation.vehicle_number == observed_number
            ),
            None,
        )
        if exact is not None:
            return exact, observed_number, None

        close_matches = [
            reservation
            for reservation in reservations
            if reservation.vehicle_number
            and is_safe_reservation_plate_match(
                observed_number,
                reservation.vehicle_number,
            )
        ]
        distinct_numbers = {
            reservation.vehicle_number for reservation in close_matches
        }
        if len(distinct_numbers) == 1:
            matched_number = next(iter(distinct_numbers))
            matched_reservation = next(
                reservation
                for reservation in close_matches
                if reservation.vehicle_number == matched_number
            )
            return (
                matched_reservation,
                matched_number,
                f"OCR read {observed_number}; uniquely matched active "
                f"reservation {matched_number}.",
            )
        if len(distinct_numbers) > 1:
            return (
                None,
                observed_number,
                "Plate reading is ambiguous. Reposition the plate and scan again.",
            )
        return None, observed_number, None

    async def _process_plate(
        self,
        vehicle_number: str,
        confidence: float | None,
    ) -> str:
        area_id = self.parking_area_id
        if area_id is None:
            self._set_decision(
                vehicle_number,
                False,
                "Select a parking area before starting recognition",
                "CLOSED",
            )
            return vehicle_number

        reservation: Reservation | None = None
        settlement: ParkingSettlement | None = None
        authorized = False
        gate_state = "CLOSED"
        message = "Vehicle not authorized"
        resolved_number = vehicle_number
        match_note: str | None = None

        async with AsyncSessionLocal() as db:
            reservation, resolved_number, match_note = await self._find_reservation(
                db,
                area_id,
                vehicle_number,
            )

            if reservation is None:
                if match_note:
                    message = match_note
                else:
                    message = (
                        "No prebooking found. Select vacant W01 or W02 below to "
                        "admit this vehicle as a walk-in."
                        if self.mode == "ENTRY"
                        else "No active parking session matches this number plate"
                    )
            elif self.mode == "ENTRY" and reservation.status in {"ACTIVE", "CHECKOUT_PAYMENT_PENDING"}:
                message = (
                    "This vehicle is already checked in. Use Exit Mode when "
                    "leaving the parking area."
                )
            elif self.mode == "ENTRY":
                try:
                    reservation = await check_in(
                        db,
                        reservation.id,
                        reservation.user_id,
                    )
                    authorized = True
                    gate_state = "OPEN"
                    payment_note = (
                        " ₹10 advance verified."
                        if reservation.advance_paid
                        else " ₹10 advance unpaid; the full parking fee is due at exit."
                    )
                    message = (
                        f"Entry approved. Proceed to slot "
                        f"{reservation.slot.slot_id}.{payment_note}"
                    )
                    if match_note:
                        message = f"{match_note} {message}"
                except HTTPException as exc:
                    message = str(exc.detail)
            elif reservation.status == "CHECKOUT_PAYMENT_PENDING":
                authorized = True
                gate_state = "PAYMENT_REQUIRED"
                settlement_result = await db.execute(
                    select(ParkingSettlement).where(
                        ParkingSettlement.reservation_id == reservation.id
                    )
                )
                settlement = settlement_result.scalars().first()
                if reservation.booking_type == "WALK_IN" and settlement:
                    message = (
                        f"Collect ₹{settlement.amount_due:.2f} and record "
                        "Cash or UPI below. Gate remains closed."
                    )
                else:
                    message = "Final payment is pending. Gate remains closed."
                if match_note:
                    message = f"{match_note} {message}"
            else:
                try:
                    reservation = await check_out(
                        db,
                        reservation.id,
                        reservation.user_id,
                    )
                    authorized = True
                    gate_state = "PAYMENT_REQUIRED"
                    settlement_result = await db.execute(
                        select(ParkingSettlement).where(
                            ParkingSettlement.reservation_id == reservation.id
                        )
                    )
                    settlement = settlement_result.scalars().first()
                    if reservation.booking_type == "WALK_IN" and settlement:
                        message = (
                            "Walk-in exit recognized. Timer stopped; collect "
                            f"₹{settlement.amount_due:.2f} and record Cash or UPI."
                        )
                    else:
                        message = (
                            "Exit recognized. Parking timer stopped; complete the "
                            "final payment to open the gate."
                        )
                    if match_note:
                        message = f"{match_note} {message}"
                except HTTPException as exc:
                    message = str(exc.detail)

            event = GateEvent(
                parking_area_id=area_id,
                reservation_id=reservation.id if reservation else None,
                slot_id=reservation.slot_id if reservation else None,
                event_type=self.mode,
                vehicle_number=resolved_number,
                ocr_confidence=confidence,
                authorized=authorized,
                gate_state=gate_state,
                message=message,
            )
            db.add(event)
            await db.commit()
            await db.refresh(event)

        self._remember_session(reservation, settlement)
        self._set_decision(
            resolved_number,
            authorized,
            message,
            gate_state,
        )
        event_payload = {
            "event_id": str(event.id),
            "event_type": self.mode,
            "vehicle_number": resolved_number,
            "authorized": authorized,
            "gate_state": gate_state,
            "message": message,
            "reservation_id": str(reservation.id) if reservation else None,
            "slot_id": str(reservation.slot_id) if reservation else None,
        }
        if gate_state == 'OPEN':
            self._schedule_gate_close()
        await broadcast_gate_event(area_id, event_payload)
        return resolved_number

    def _set_decision(
        self,
        vehicle_number: str,
        authorized: bool,
        message: str,
        gate_state: str,
    ) -> None:
        self.last_vehicle_number = vehicle_number
        self.last_authorized = authorized
        self.message = message
        self.gate_state = gate_state

    def _remember_session(
        self,
        reservation: Reservation | None,
        settlement: ParkingSettlement | None = None,
    ) -> None:
        self.last_reservation_id = reservation.id if reservation else None
        self.last_slot_id = reservation.slot_id if reservation else None
        self.last_slot_number = (
            reservation.slot.slot_id
            if reservation is not None and reservation.slot is not None
            else None
        )
        self.last_booking_type = (
            reservation.booking_type if reservation else None
        )
        self.last_amount_due = settlement.amount_due if settlement else None
        self.last_advance_paid = (
            bool(reservation.advance_paid) if reservation else None
        )
        self.manual_payment_required = bool(
            reservation
            and reservation.booking_type == "WALK_IN"
            and reservation.status == "CHECKOUT_PAYMENT_PENDING"
            and settlement
            and settlement.status != "COMPLETED"
        )

    async def show_walk_in_admission(
        self,
        reservation: Reservation,
        message: str,
    ) -> None:
        self.parking_area_id = reservation.parking_area_id
        self._remember_session(reservation)
        self._set_decision(
            reservation.vehicle_number,
            True,
            message,
            "OPEN",
        )
        await broadcast_gate_event(
            reservation.parking_area_id,
            {
                "event_type": "ENTRY",
                "vehicle_number": reservation.vehicle_number,
                "authorized": True,
                "gate_state": "OPEN",
                "message": message,
                "reservation_id": str(reservation.id),
                "slot_id": str(reservation.slot_id),
            },
        )
        self._schedule_gate_close()

    async def open_after_manual_payment(
        self,
        reservation: Reservation,
        settlement: ParkingSettlement,
        message: str,
    ) -> None:
        self.parking_area_id = reservation.parking_area_id
        self._remember_session(reservation, settlement)
        self.manual_payment_required = False
        self._set_decision(
            reservation.vehicle_number,
            True,
            message,
            "OPEN",
        )
        await broadcast_gate_event(
            reservation.parking_area_id,
            {
                "event_type": "EXIT",
                "vehicle_number": reservation.vehicle_number,
                "authorized": True,
                "gate_state": "OPEN",
                "message": message,
                "reservation_id": str(reservation.id),
                "slot_id": str(reservation.slot_id),
            },
        )
        self._schedule_gate_close()

    def _schedule_gate_close(self) -> None:
        if self._close_task:
            self._close_task.cancel()
        self._close_task = asyncio.create_task(self._close_gate_later())

    async def _close_gate_later(self) -> None:
        try:
            await asyncio.sleep(settings.GATE_OPEN_SECONDS)
            self.gate_state = "CLOSED"
            self.message = "Gate closed; camera recognition remains active"
        except asyncio.CancelledError:
            pass

    async def open_after_payment(
        self,
        parking_area_id: UUID,
        reservation_id: UUID,
        slot_id: UUID,
        vehicle_number: str,
    ) -> None:
        message = "Final payment verified. Exit gate opened and slot released."
        self.parking_area_id = parking_area_id
        self.last_reservation_id = reservation_id
        self.last_slot_id = slot_id
        self.manual_payment_required = False
        self._set_decision(vehicle_number, True, message, "OPEN")
        self._schedule_gate_close()
        await broadcast_gate_event(
            parking_area_id,
            {
                "event_type": "EXIT",
                "vehicle_number": vehicle_number,
                "authorized": True,
                "gate_state": "OPEN",
                "message": message,
                "reservation_id": str(reservation_id),
                "slot_id": str(slot_id),
            },
        )

    def _draw_gate_overlay(self, frame: Any) -> None:
        color = (45, 210, 80) if self.gate_state == "OPEN" else (40, 70, 230)
        height, width = frame.shape[:2]
        guide_x1 = int(width * 0.10)
        guide_x2 = int(width * 0.90)
        guide_y1 = int(height * 0.30)
        guide_y2 = int(height * 0.75)
        guide_color = (0, 215, 255)

        cv2.rectangle(
            frame,
            (guide_x1, guide_y1),
            (guide_x2, guide_y2),
            guide_color,
            2,
        )
        cv2.putText(
            frame,
            "ALIGN NUMBER PLATE INSIDE BOX",
            (guide_x1, max(26, guide_y1 - 12)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            guide_color,
            2,
            cv2.LINE_AA,
        )
        cv2.rectangle(frame, (12, 12), (520, 105), (8, 18, 32), -1)
        cv2.putText(
            frame,
            f"{self.mode} MODE | GATE {self.gate_state}",
            (28, 46),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            color,
            2,
            cv2.LINE_AA,
        )
        plate = self.last_vehicle_number or "Waiting for number plate"
        cv2.putText(
            frame,
            plate,
            (28, 82),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            (245, 245, 245),
            2,
            cv2.LINE_AA,
        )


gate_camera_service = GateCameraService()
