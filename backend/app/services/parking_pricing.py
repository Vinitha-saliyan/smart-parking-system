from decimal import Decimal
from math import ceil


ADVANCE_FEE = Decimal("10.00")
FIRST_HOUR_FEE = Decimal("20.00")
EXTRA_STARTED_HOUR_FEE = Decimal("5.00")
SECONDS_PER_HOUR = 3600


def calculate_parking_total(duration_seconds: float) -> Decimal:
    """Return ₹20 for the first hour and ₹5 per started extra hour."""
    safe_duration = max(1.0, duration_seconds)
    if safe_duration <= SECONDS_PER_HOUR:
        return FIRST_HOUR_FEE

    extra_started_hours = ceil(
        (safe_duration - SECONDS_PER_HOUR) / SECONDS_PER_HOUR
    )
    return (
        FIRST_HOUR_FEE
        + (EXTRA_STARTED_HOUR_FEE * Decimal(extra_started_hours))
    ).quantize(Decimal("0.01"))


def calculate_checkout_balance(
    total_amount: Decimal,
    *,
    advance_paid: bool,
) -> Decimal:
    """Deduct the ₹10 credit only after its payment was verified."""
    advance_credit = ADVANCE_FEE if advance_paid else Decimal("0.00")
    return max(Decimal("0.00"), total_amount - advance_credit).quantize(
        Decimal("0.01")
    )
