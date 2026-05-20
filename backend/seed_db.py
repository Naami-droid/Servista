import asyncio
from datetime import datetime, timezone
import uuid
import random
from core.firebase_init import get_db
from firebase_admin import auth

def create_auth_user(email, password, display_name):
    try:
        user = auth.get_user_by_email(email)
        print(f"User {email} already exists in Auth. Deleting to start fresh...")
        auth.delete_user(user.uid)
    except Exception:
        pass
        
    try:
        user = auth.create_user(
            email=email,
            password=password,
            display_name=display_name
        )
        print(f"Created Auth User: {email} with UID: {user.uid}")
        return user.uid
    except Exception as e:
        print(f"Error creating user {email}: {e}")
        return None

async def seed_data():
    print("Connecting to Firebase...")
    db = get_db()
    if not db:
        print("Database not connected. Exiting.")
        return

    # 1. Create a Customer Account
    customer_email = "mrnaami2004+customer@gmail.com"
    customer_password = "password123"
    customer_uid = create_auth_user(customer_email, customer_password, "Naami (Customer)")
    
    if customer_uid:
        db.collection("users").document(customer_uid).set({
            "uid": customer_uid,
            "full_name": "Muhammad Naami",
            "email": customer_email,
            "role": "customer",
            "created_at": datetime.now(timezone.utc)
        })

    # 2. Create Provider Accounts
    categories = ["AC Repair", "Plumbing", "Electrician"]
    provider_names = ["Naami AC Services", "Naami Plumbers", "Naami Electric"]
    
    for i in range(3):
        provider_email = f"mrnaami2004+provider{i+1}@gmail.com"
        provider_uid = create_auth_user(provider_email, customer_password, provider_names[i])
        
        if provider_uid:
            provider_data = {
                "uid": provider_uid,
                "full_name": provider_names[i],
                "email": provider_email,
                "role": "provider",
                "phone_number": f"+92300{random.randint(1000000, 9999999)}",
                "service_category": categories[i],
                "rating": round(random.uniform(3.5, 5.0), 1),
                "jobs_completed": random.randint(5, 100),
                "current_location": {"lat": 33.6844 + random.uniform(-0.05, 0.05), "lng": 73.0479 + random.uniform(-0.05, 0.05)},
                "base_rate": random.randint(1000, 3000),
                "created_at": datetime.now(timezone.utc)
            }
            db.collection("providers").document(provider_uid).set(provider_data)

    print("Successfully seeded database with Auth and Firestore Data!")

if __name__ == "__main__":
    asyncio.run(seed_data())
