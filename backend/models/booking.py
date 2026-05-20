from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime

class Booking(BaseModel):
    booking_id: str
    customer_id: str
    provider_id: Optional[str] = None
    pending_provider_ids: List[str] = []
    service_type: str
    location_text: str
    location_coords: Dict[str, float]
    scheduled_date: str
    scheduled_time: Optional[str] = None
    status: str
    provider_response_deadline: datetime
    timer_expired: bool = False
    timed_out_providers: List[str] = []
    cancelled_providers: List[str] = []
    estimated_cost: Optional[float] = None
    final_cost: Optional[float] = None
    agent_reasoning: str
    matched_providers: List[dict] = []
    shortlisted_providers: List[dict] = []
    customer_rating: Optional[float] = None
    customer_review: Optional[str] = None
    receipt_url: Optional[str] = None
    confirmation_sent: bool = False
    reminder_sent: bool = False
    parent_booking_id: Optional[str] = None
    rerun_count: int = 0
    created_at: datetime
    updated_at: datetime
