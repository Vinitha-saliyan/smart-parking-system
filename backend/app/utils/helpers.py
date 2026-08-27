import qrcode
import base64
from io import BytesIO
from decimal import Decimal

def generate_qr_code(data: str) -> str:
    """Generate QR code and return as base64 PNG string."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffered = BytesIO()
    img.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
    return img_str

def generate_slot_ids(prefix: str, count: int) -> list[str]:
    """Generate slot IDs like A01, A02."""
    return [f"{prefix}{i:02d}" for i in range(1, count + 1)]

def format_currency(amount: Decimal, currency: str = 'INR') -> str:
    if currency == 'INR':
        return f"₹{amount}"
    return f"{amount} {currency}"
