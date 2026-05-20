from pydantic import BaseModel
from datetime import datetime

class Review(BaseModel):
    booking_id: str
    customer_id: str
    provider_id: str
    rating: float
    review_text: str
    service_type: str
    created_at: datetime

class Notification(BaseModel):
    user_id: str
    title: str
    body: str
    type: str # "booking_confirmed", "provider_timeout", etc.
    booking_id: str
    is_read: bool = False
    created_at: datetime

class AgentLog(BaseModel):
    booking_id: str
    step: str
    input_data: dict
    output_data: dict
    reasoning: str
    tool_used: str
    timestamp: datetime
