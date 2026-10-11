import re


_STANDARD_NUMBER = re.compile(r"^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$")
_BHARAT_NUMBER = re.compile(r"^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$")


def normalize_vehicle_number(value: str) -> str:
    """Return a canonical registration number for matching camera OCR data."""
    return re.sub(r"[^A-Z0-9]", "", value.strip().upper())


def is_valid_indian_vehicle_number(value: str) -> bool:
    normalized = normalize_vehicle_number(value)
    return bool(
        _STANDARD_NUMBER.fullmatch(normalized)
        or _BHARAT_NUMBER.fullmatch(normalized)
    )


def validate_vehicle_number(value: str) -> str:
    normalized = normalize_vehicle_number(value)
    if not is_valid_indian_vehicle_number(normalized):
        raise ValueError(
            "Enter a valid Indian vehicle number, for example KA19AB1234"
        )
    return normalized


def _edit_distance_at_most_one(left: str, right: str) -> bool:
    """Return True when two normalized strings differ by at most one edit."""
    if left == right:
        return True
    if abs(len(left) - len(right)) > 1:
        return False

    if len(left) == len(right):
        differences = sum(a != b for a, b in zip(left, right))
        return differences <= 1

    shorter, longer = (left, right) if len(left) < len(right) else (right, left)
    short_index = 0
    long_index = 0
    skipped = False

    while short_index < len(shorter) and long_index < len(longer):
        if shorter[short_index] == longer[long_index]:
            short_index += 1
            long_index += 1
            continue
        if skipped:
            return False
        skipped = True
        long_index += 1

    return True


def is_safe_reservation_plate_match(observed: str, registered: str) -> bool:
    """Allow one OCR error only when the stable parts of a plate agree.

    This helper is deliberately conservative.  It is used only against live
    reservations and the caller must also require a unique database match.
    The state code and final four digits must be identical, which prevents a
    missing middle character such as ``KA0MN9787`` from being guessed against
    an unrelated reservation.
    """
    camera_value = normalize_vehicle_number(observed)
    stored_value = normalize_vehicle_number(registered)
    if camera_value == stored_value:
        return True
    if len(camera_value) < 7 or len(stored_value) < 7:
        return False
    if camera_value[:2] != stored_value[:2]:
        return False
    if camera_value[-4:] != stored_value[-4:]:
        return False
    return _edit_distance_at_most_one(camera_value, stored_value)
