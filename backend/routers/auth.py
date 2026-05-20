from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from core.firebase_init import get_db

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str
    role: str

@router.post("/login")
async def login(request: LoginRequest):
    db = get_db()
    if not db:
        raise HTTPException(status_code=500, detail="Database not connected")
        
    collection_name = "users" if request.role == "customer" else "providers"
    docs = db.collection(collection_name).where("email", "==", request.email).limit(1).get()
    
    if not docs:
        raise HTTPException(status_code=401, detail=f"Invalid email or user not found for {request.role}.")
        
    doc = docs[0].to_dict()
    
    return {
        "status": "success",
        "uid": doc["uid"],
        "email": doc["email"],
        "full_name": doc.get("full_name", ""),
        "role": request.role
    }
