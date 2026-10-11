from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, List
import logging
import asyncio

router = APIRouter(tags=["WebSocket"])
logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, area_id: str, websocket: WebSocket):
        await websocket.accept()
        if area_id not in self.active_connections:
            self.active_connections[area_id] = []
        self.active_connections[area_id].append(websocket)
        logger.info(f"Client connected to area {area_id}. Total: {len(self.active_connections[area_id])}")

    def disconnect(self, area_id: str, websocket: WebSocket):
        if area_id in self.active_connections:
            self.active_connections[area_id].remove(websocket)
            logger.info(f"Client disconnected from area {area_id}.")

    async def broadcast_slot_update(self, area_id: str, slot_data: dict):
        if area_id in self.active_connections:
            for connection in self.active_connections[area_id]:
                try:
                    await connection.send_json(slot_data)
                except Exception as e:
                    logger.error(f"Failed to send to websocket: {e}")

manager = ConnectionManager()

@router.websocket("/ws/parking/{area_id}")
async def websocket_endpoint(websocket: WebSocket, area_id: str):
    await manager.connect(area_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(area_id, websocket)
