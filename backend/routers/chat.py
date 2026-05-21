from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timezone
from core.firebase_init import get_db

router = APIRouter()

# --- Booking-specific Chats (Existing) ---
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

# --- AI Match Agent Chats (New) ---

class CreateChatSessionRequest(BaseModel):
    customer_id: str
    title: Optional[str] = "New Chat"

class AddMessageRequest(BaseModel):
    message: dict

@router.post("/sessions/create")
async def create_chat_session(request: CreateChatSessionRequest):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    session_ref = db.collection("agent_chats").document()
    
    now_str = datetime.now(timezone.utc).isoformat()
    session_data = {
        "chat_id": session_ref.id,
        "customer_id": request.customer_id,
        "title": request.title,
        "created_at": now_str,
        "updated_at": now_str
    }
    
    session_ref.set(session_data)
    return {"status": "success", "session": session_data}

@router.get("/sessions/list/{customer_id}")
async def list_chat_sessions(customer_id: str):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    docs = db.collection("agent_chats")\
             .where("customer_id", "==", customer_id)\
             .order_by("updated_at", direction="DESCENDING")\
             .get()
             
    sessions = []
    for doc in docs:
        sessions.append(doc.to_dict())
        
    return {"status": "success", "sessions": sessions}

@router.get("/sessions/{chat_id}/messages")
async def get_chat_session_messages(chat_id: str):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    docs = db.collection("agent_chats")\
             .document(chat_id)\
             .collection("messages")\
             .order_by("timestamp")\
             .get()
             
    messages = []
    for doc in docs:
        messages.append(doc.to_dict())
        
    return {"status": "success", "messages": messages}

@router.post("/sessions/{chat_id}/messages/add")
async def add_chat_session_message(chat_id: str, request: AddMessageRequest):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    now_str = datetime.now(timezone.utc).isoformat()
    
    message_data = request.message.copy()
    if "timestamp" not in message_data or not message_data["timestamp"]:
        message_data["timestamp"] = now_str
        
    # Store message in subcollection
    db.collection("agent_chats")\
      .document(chat_id)\
      .collection("messages")\
      .add(message_data)
      
    # Update parent session's updated_at
    db.collection("agent_chats")\
      .document(chat_id)\
      .update({"updated_at": now_str})
      
    # Update title dynamically on the first message if it is user text
    if not message_data.get("isUser", False) == False and message_data.get("text"):
        session_doc = db.collection("agent_chats").document(chat_id).get()
        if session_doc.exists:
            current_title = session_doc.to_dict().get("title", "New Chat")
            if current_title == "New Chat":
                # Truncate first message to 4-5 words for title
                words = message_data["text"].split()
                new_title = " ".join(words[:4])
                if len(words) > 4:
                    new_title += "..."
                db.collection("agent_chats").document(chat_id).update({"title": new_title})
      
    return {"status": "success", "message": message_data}

@router.delete("/sessions/{chat_id}")
async def delete_chat_session(chat_id: str):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    # 1. Delete all messages inside the subcollection first
    messages_ref = db.collection("agent_chats").document(chat_id).collection("messages")
    docs = messages_ref.limit(500).get()
    for doc in docs:
        doc.reference.delete()
        
    # 2. Delete the parent session document
    db.collection("agent_chats").document(chat_id).delete()
    
    return {"status": "success", "message": "Chat session and all its messages deleted successfully"}

