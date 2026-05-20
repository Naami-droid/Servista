from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
import firebase_admin
from firebase_admin import storage
from core.firebase_init import get_db
import os

async def generate_receipt(booking_id: str, final_cost: float) -> str:
    db = get_db()
    if not db:
        return "dummy_url"
        
    booking_doc = db.collection("bookings").document(booking_id).get()
    if not booking_doc.exists:
        return ""
    booking = booking_doc.to_dict()
    
    customer_doc = db.collection("users").document(booking.get("customer_id", "")).get()
    provider_doc = db.collection("providers").document(booking.get("provider_id", "")).get()
    
    customer = customer_doc.to_dict() if customer_doc.exists else {"full_name": "Unknown"}
    provider = provider_doc.to_dict() if provider_doc.exists else {"full_name": "Unknown"}

    # Use local temp dir for windows/cross-platform
    temp_dir = os.environ.get("TEMP", "/tmp")
    filename = os.path.join(temp_dir, f"receipt_{booking_id}.pdf")
    
    c = canvas.Canvas(filename, pagesize=A4)
    c.setFont("Helvetica-Bold", 18)
    c.drawString(50, 800, "Karobar AI - Service Receipt")
    c.setFont("Helvetica", 12)
    c.drawString(50, 770, f"Booking ID:   {booking_id}")
    c.drawString(50, 750, f"Customer:     {customer.get('full_name', '')}")
    c.drawString(50, 730, f"Provider:     {provider.get('full_name', '')}")
    c.drawString(50, 710, f"Service:      {booking.get('service_type', '')}")
    c.drawString(50, 690, f"Date & Time:  {booking.get('scheduled_date', '')} {booking.get('scheduled_time', '')}")
    c.drawString(50, 670, f"Location:     {booking.get('location_text', '')}")
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, 640, f"Total Cost:   PKR {final_cost}")
    c.save()

    try:
        bucket = storage.bucket()
        blob = bucket.blob(f"receipts/{booking_id}.pdf")
        blob.upload_from_filename(filename)
        blob.make_public()
        return blob.public_url
    except Exception as e:
        print(f"Failed to upload receipt: {e}")
        return f"file://{filename}"
