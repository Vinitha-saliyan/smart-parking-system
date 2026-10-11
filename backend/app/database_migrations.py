from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection


async def run_compatibility_migrations(conn: AsyncConnection) -> None:
    """Apply small idempotent upgrades for databases created before Alembic.

    The project already uses ``create_all``. That creates new tables, but it
    does not add a column to an existing table, so the registration number must
    be added explicitly for existing installations.
    """
    if conn.dialect.name != "postgresql":
        return

    await conn.execute(
        text(
            "ALTER TABLE reservations "
            "ADD COLUMN IF NOT EXISTS vehicle_number VARCHAR(15)"
        )
    )
    await conn.execute(
        text(
            "CREATE INDEX IF NOT EXISTS ix_reservations_vehicle_number "
            "ON reservations (vehicle_number)"
        )
    )
    await conn.execute(
        text(
            "ALTER TABLE reservations "
            "ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) "
            "NOT NULL DEFAULT 'PREBOOKED'"
        )
    )
    await conn.execute(
        text(
            "ALTER TABLE reservations "
            "ADD COLUMN IF NOT EXISTS advance_paid BOOLEAN "
            "NOT NULL DEFAULT FALSE"
        )
    )
    await conn.execute(
        text(
            "UPDATE reservations AS r SET advance_paid = TRUE "
            "WHERE EXISTS ("
            "SELECT 1 FROM payments AS p "
            "WHERE p.reservation_id = r.id AND p.status = 'COMPLETED'"
            ")"
        )
    )
    await conn.execute(
        text(
            "ALTER TABLE parking_settlements "
            "ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20)"
        )
    )
    await conn.execute(
        text(
            "ALTER TABLE parking_settlements "
            "ADD COLUMN IF NOT EXISTS recorded_by UUID REFERENCES users(id)"
        )
    )
    # Older demo seeds marked A03/A07/B02 occupied and A05 reserved without a
    # reservation. Release only untouched seed rows; real updates have an
    # updated_at value or a live reservation and are preserved.
    await conn.execute(
        text(
            "UPDATE parking_slots AS s SET status = 'VACANT' "
            "WHERE s.slot_id IN ('A03', 'A05', 'A07', 'B02') "
            "AND s.status IN ('OCCUPIED', 'RESERVED') "
            "AND s.updated_at IS NULL "
            "AND NOT EXISTS ("
            "SELECT 1 FROM reservations AS r "
            "WHERE r.slot_id = s.id "
            "AND r.status IN ("
            "'PAYMENT_PENDING', 'PENDING', 'ACTIVE', "
            "'CHECKOUT_PAYMENT_PENDING'"
            ")"
            ")"
        )
    )
