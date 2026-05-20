from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from core.firebase_init import get_db
from datetime import datetime, timezone, timedelta
from agents.timer_agent import schedule_appointment_reminder

router = APIRouter()

class BookingAction(BaseModel):
    booking_id: str
    action: str # "accept" or "reject"

class CreateBookingRequest(BaseModel):
    customer_id: str
    request_data: dict
    offered_provider_ids: List[str]
    reasoning_data: dict

@router.post("/create")
async def create_booking(request: CreateBookingRequest):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    booking_ref = db.collection("bookings").document()
    
    booking_data = {
        "customer_id": request.customer_id,
        "request_data": request.request_data,
        "offered_provider_ids": request.offered_provider_ids,
        "reasoning_data": request.reasoning_data,
        "status": "PENDING",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    
    booking_ref.set(booking_data)
    
    deadline_time = datetime.now(timezone.utc) + timedelta(minutes=3)
    
    return {
        "status": "success", 
        "booking_id": booking_ref.id,
        "deadline": deadline_time.isoformat()
    }

@router.get("/pending/{provider_id}")
async def get_pending_bookings(provider_id: str):
    db = get_db()
    if not db:
        return {"status": "error", "message": "Database not connected"}
        
    if provider_id == "ALL":
        docs = db.collection("bookings")\
                 .where("status", "==", "PENDING")\
                 .get()
    else:
        docs = db.collection("bookings")\
                 .where("status", "==", "PENDING")\
                 .where("offered_provider_ids", "array_contains", provider_id)\
                 .get()
             
    bookings = []
    for doc in docs:
        b = doc.to_dict()
        b["id"] = doc.id
        bookings.append(b)
        
    return {"status": "success", "bookings": bookings}

@router.get("/status/{booking_id}")
async def get_booking_status(booking_id: str):
    db = get_db()
    if not db:
        return {"status": "error", "message": "Database not connected"}
    doc_ref = db.collection("bookings").document(booking_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Booking not found")
    data = doc.to_dict()
    return {"status": "success", "booking_status": data.get("status")}

@router.post("/action")
async def provider_action(payload: BookingAction):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    doc_ref = db.collection("bookings").document(payload.booking_id)
    doc = doc_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Booking not found")
        
    booking_data = doc.to_dict()
    if booking_data["status"] != "PENDING":
        return {"status": "error", "message": "Booking is no longer pending"}
        
    if payload.action == "accept":
        doc_ref.update({
            "status": "CONFIRMED",
            "confirmed_provider_id": "current_provider_id_mock", # In real app, grab from auth token
            "updated_at": datetime.now(timezone.utc)
        })
        # Schedule 1-hour reminder
        try:
            appt_time = datetime.now(timezone.utc) + timedelta(hours=2)
            await schedule_appointment_reminder(payload.booking_id, appt_time)
        except Exception as e:
            print(f"Failed to schedule reminder: {e}")
            
        return {"status": "success", "message": "Booking confirmed! Customer notified."}

    elif payload.action == "renegotiate":
        doc_ref.update({
            "status": "RENEGOTIATING",
            "updated_at": datetime.now(timezone.utc)
        })
        return {"status": "success", "message": "Booking renegotiating"}
        
    elif payload.action == "reject":
        doc_ref.update({
            "status": "REJECTED",
            "updated_at": datetime.now(timezone.utc)
        })
        return {"status": "success", "message": "Booking rejected. Customer notified to search again."}
    
    raise HTTPException(status_code=400, detail="Invalid action")
