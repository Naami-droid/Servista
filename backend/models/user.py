from pydantic import BaseModel
from typing import Optional, Dict
from datetime import datetime

class User(BaseModel):
    uid: str
    account_type: str # "customer" | "provider"
    full_name: str
    email: str
    phone: str
    profile_photo_url: str
    fcm_token: str
    created_at: datetime
    preferred_language: str # "en" | "ur" | "roman_ur"
    location: Dict[str, float] # {"lat": ..., "lng": ...}
