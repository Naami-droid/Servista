from fastapi import APIRouter
from pydantic import BaseModel
from datetime import datetime
from core.firebase_init import get_db

router = APIRouter()

class SubmitReviewRequest(BaseModel):
    booking_id: str
    customer_id: str
    rating: float
    review_text: str

@router.post("/submit")
async def submit_review(request: SubmitReviewRequest):
    db = get_db()
    if not db:
        return {"status": "success", "message": "Dummy success"}

    booking_doc = db.collection("bookings").document(request.booking_id).get()
    if not booking_doc.exists:
        return {"error": "Booking not found"}
        
    booking = booking_doc.to_dict()
    provider_id = booking.get("provider_id")
    
    db.collection("reviews").add({
        "booking_id": request.booking_id,
        "customer_id": request.customer_id,
        "provider_id": provider_id,
        "rating": request.rating,
        "review_text": request.review_text,
        "service_type": booking.get("service_type", ""),
        "created_at": datetime.utcnow()
    })
    
    return {"status": "success", "message": "Review submitted"}
