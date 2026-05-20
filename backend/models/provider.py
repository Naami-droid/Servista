from pydantic import BaseModel
from typing import Optional, Dict, List
from datetime import datetime

class Provider(BaseModel):
    uid: str
    full_name: str
    service_category: str
    skill_specialization: str
    base_rate: float
    rating: float
    total_reviews: int
    on_time_score: float
    cancellation_risk_score: float
    timeout_count: int
    current_location: Dict[str, float]
    service_radius_km: float
    availability_calendar: Dict[str, List[str]]
    is_online: bool
    is_verified: bool
    fcm_token: str
    profile_photo_url: str
    bio: str
    total_jobs_completed: int
    blacklisted_until: Optional[datetime] = None
