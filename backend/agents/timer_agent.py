from apscheduler.schedulers.asyncio import AsyncIOScheduler
from datetime import datetime, timedelta, timezone
import json
from core.firebase_init import get_db
from firebase_admin import firestore

scheduler = AsyncIOScheduler()

async def schedule_provider_timeout(booking_id: str, deadline: datetime):
    print(f"Scheduling timeout for {booking_id} at {deadline}")
    scheduler.add_job(
        func=handle_provider_timeout,
        trigger="date",
        run_date=deadline,
        args=[booking_id],
        id=f"timeout_{booking_id}",
        replace_existing=True
    )

def send_notification(title: str, body: str):
    # In a real app, use FCM. For hackathon, just print to console.
    print("\n" + "="*40)
    print(f"🔔 NOTIFICATION: {title}")
    print(f"   {body}")
    print("="*40 + "\n")

async def handle_appointment_reminder(booking_id: str):
    db = get_db()
    if not db: return
    
    doc = db.collection("bookings").document(booking_id).get()
    if not doc.exists: return
    
    booking = doc.to_dict()
    if booking.get("status") == "CONFIRMED":
        send_notification(
            title="Appointment Reminder",
            body=f"Your {booking['service_category']} appointment is in 1 hour!"
        )

async def schedule_appointment_reminder(booking_id: str, appointment_time: datetime):
    # Schedule for 1 hour before the appointment
    reminder_time = appointment_time - timedelta(hours=1)
    
    # If the appointment is already less than 1 hour away, just send it now
    if reminder_time < datetime.now(timezone.utc):
        reminder_time = datetime.now(timezone.utc) + timedelta(seconds=10) # 10 secs for testing
        
    print(f"Scheduling 1-hour reminder for {booking_id} at {reminder_time}")
    scheduler.add_job(
        func=handle_appointment_reminder,
        trigger="date",
        run_date=reminder_time,
        args=[booking_id],
        id=f"reminder_{booking_id}",
        replace_existing=True
    )

async def handle_provider_timeout(booking_id: str):
    print(f"Timer expired for booking {booking_id}")
    db = get_db()
    if not db:
        print("Firebase DB not initialized. Skipping timeout logic.")
        return
        
    booking_ref = db.collection("bookings").document(booking_id)
    booking_doc = booking_ref.get()
    
    if not booking_doc.exists:
        return
        
    booking = booking_doc.to_dict()

    if booking.get("status") != "PENDING":
        return

    pending_providers = booking.get("offered_provider_ids", [])

    booking_ref.update({
        "status": "provider_timeout",
        "timer_expired": True,
        "updated_at": firestore.SERVER_TIMESTAMP()
    })

    # Penalize non-responsive providers
    for provider_id in pending_providers:
        provider_ref = db.collection("providers").document(provider_id)
        provider_doc = provider_ref.get()
        if provider_doc.exists:
            data = provider_doc.to_dict()
            new_rating = max(1.0, data.get("rating", 5.0) - 0.05)
            # Increase cancellation risk / lower availability score proxy
            new_cancellation_risk = min(100, data.get("cancellation_risk_score", 0) + 2)
            
            provider_ref.update({
                "rating": new_rating,
                "cancellation_risk_score": new_cancellation_risk
            })
            print(f"Penalized provider {provider_id} for timeout: rating={new_rating}, risk={new_cancellation_risk}")

    send_notification(
        title="Timeout",
        body="Providers did not respond in time. Searching for new ones..."
    )
    
    print(f"Providers {pending_providers} timed out for booking {booking_id}. Rerunning pipeline...")

