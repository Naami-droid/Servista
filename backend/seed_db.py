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

    categories = ["AC Technician", "Tuition Teacher", "Plumber", "Electrician"]
    first_names = ["Ali", "Usman", "Ahmad", "Bilal", "Zain", "Omar", "Hassan", "Kamran", "Tariq", "Imran", "Naveed", "Farhan", "Raza", "Saad", "Waqas"]
    last_names = ["Khan", "Ahmed", "Shah", "Malik", "Chaudhry", "Raja", "Sheikh", "Qureshi", "Ansari", "Mirza", "Baig", "Syed"]
    
    # Create 1 main provider account for auth/dashboard login purposes
    main_provider_email = "mrnaami2004+provider1@gmail.com"
    main_provider_uid = create_auth_user(main_provider_email, customer_password, "Naami Main Provider")
    
    print("Generating 1000 service providers in Firestore...")
    batch = db.batch()
    count = 0
    
    for i in range(1000):
        if i == 0 and main_provider_uid:
            provider_uid = main_provider_uid
            full_name = "Naami Main Provider"
            email = main_provider_email
        else:
            provider_uid = f"mock_prov_{uuid.uuid4().hex[:12]}"
            full_name = f"{random.choice(first_names)} {random.choice(last_names)}"
            email = f"provider_{provider_uid}@example.com"
            
        cat = random.choice(categories)
        lat = 33.6844 + random.uniform(-0.15, 0.15) # Spread around Islamabad
        lng = 73.0479 + random.uniform(-0.15, 0.15)
        
        provider_data = {
            "uid": provider_uid,
            "full_name": full_name,
            "email": email,
            "role": "provider",
            "phone_number": f"+92300{random.randint(1000000, 9999999)}",
            "service_category": cat,
            "rating": round(random.uniform(3.0, 5.0), 1),
            "jobs_completed": random.randint(0, 500),
            "current_location": {"lat": lat, "lng": lng},
            "base_rate": random.randint(1000, 5000),
            "on_time_score": random.randint(60, 100),
            "cancellation_risk_score": random.randint(0, 30),
            "service_radius_km": random.randint(5, 30),
            "availability_calendar": {
                datetime.now(timezone.utc).strftime("%Y-%m-%d"): ["08:00", "09:00", "10:00", "14:00", "15:00", "16:00"]
            },
            "is_online": True,
            "created_at": datetime.now(timezone.utc)
        }
        
        doc_ref = db.collection("providers").document(provider_uid)
        batch.set(doc_ref, provider_data)
        count += 1
        
        if count == 400: # Firestore batch limit is 500
            batch.commit()
            batch = db.batch()
            count = 0
            print("Committed a batch of 400 providers...")
            
    if count > 0:
        batch.commit()
        print(f"Committed final batch of {count} providers...")
        
    print("Successfully seeded database with 1000 providers!")

if __name__ == "__main__":
    asyncio.run(seed_data())
