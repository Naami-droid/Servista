from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timezone
from core.firebase_init import get_db

router = APIRouter()

class SendMessageRequest(BaseModel):
    sender_id: str
    sender_role: str # 'customer' or 'provider'
    text: str

@router.post("/{booking_id}/send")
async def send_message(booking_id: str, request: SendMessageRequest):
    db = get_db()
    if not db:
        return {"status": "error", "message": "Database not connected"}
        
    message_data = {
        "sender_id": request.sender_id,
        "sender_role": request.sender_role,
        "text": request.text,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    # Add to a messages subcollection
    db.collection("bookings").document(booking_id).collection("messages").add(message_data)
    
    return {"status": "success", "message": "Message sent"}

@router.get("/{booking_id}/messages")
async def get_messages(booking_id: str):
    db = get_db()
    if not db:
        return {"status": "error", "message": "Database not connected"}
        
    docs = db.collection("bookings").document(booking_id).collection("messages").order_by("timestamp").get()
    
    messages = []
    for doc in docs:
        messages.append(doc.to_dict())
        
    return {"status": "success", "messages": messages}
