from typing import Any

from fastapi.encoders import jsonable_encoder

from app.routers.websocket_router import manager


async def broadcast_slot_status(slot: Any) -> None:
    payload = {
        column.name: getattr(slot, column.name)
        for column in slot.__table__.columns
    }
    encoded = jsonable_encoder(payload)
    encoded.update(
        {
            "type": "slot_status_update",
            "slotId": str(slot.slot_id),
            "slotNumber": str(slot.slot_id),
            "parkingAreaId": str(slot.parking_area_id),
        }
    )
    await manager.broadcast_slot_update(str(slot.parking_area_id), encoded)


async def broadcast_gate_event(area_id: Any, event: dict[str, Any]) -> None:
    payload = jsonable_encoder({"type": "gate_event", **event})
    await manager.broadcast_slot_update(str(area_id), payload)
