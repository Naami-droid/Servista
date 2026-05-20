from geopy.distance import geodesic
from datetime import datetime
from core.firebase_init import get_db

def calculate_distance(provider_coords, request_coords):
    try:
        return geodesic(
            (provider_coords["lat"], provider_coords["lng"]),
            (request_coords["lat"], request_coords["lng"])
        ).km
    except Exception:
        return 5.0 # default fallback

def distance_penalty(km: float) -> float:
    return min(km / 10.0, 1.0)

def availability_score(provider: dict, requested_date: str, time_pref: str) -> float:
    slots = provider.get("availability_calendar", {}).get(requested_date, [])
    if not slots:
        return 0.0
    time_map = {
        "morning":   ["08:00","09:00","10:00","11:00"],
        "afternoon": ["12:00","13:00","14:00","15:00"],
        "evening":   ["16:00","17:00","18:00"],
        "any":       ["08:00","09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00","18:00"]
    }
    preferred = time_map.get(time_pref, [])
    if not preferred:
        return 1.0 # If unknown time pref, just assume they are available if they have any slots
    return min(len(set(slots) & set(preferred)) / max(len(preferred), 1), 1.0)

def specialization_match(provider: dict, service_type: str) -> float:
    spec = provider.get("skill_specialization", "").lower()
    stype = service_type.lower()
    return 1.0 if (stype in spec or spec in stype) else 0.5

def is_provider_eligible(provider: dict, excluded_ids: list) -> bool:
    if provider["uid"] in excluded_ids:
        return False
    if not provider.get("is_online", False):
        return False
    blacklisted_until = provider.get("blacklisted_until")
    if blacklisted_until:
        # Handle string or datetime
        if isinstance(blacklisted_until, str):
            try:
                dt = datetime.fromisoformat(blacklisted_until.replace('Z', '+00:00'))
                if dt.replace(tzinfo=None) > datetime.utcnow():
                    return False
            except ValueError:
                pass
        elif isinstance(blacklisted_until, datetime):
             if blacklisted_until > datetime.utcnow():
                 return False
    return True

async def get_all_providers():
    db = get_db()
    if not db:
        # Fallback dummy data
        return [
            {
                "uid": "prov_1", "full_name": "Ali", "service_category": "AC Repair",
                "skill_specialization": "Inverter ACs", "base_rate": 1500, "rating": 4.8,
                "on_time_score": 95, "cancellation_risk_score": 5, "current_location": {"lat": 33.6844, "lng": 73.0479},
                "service_radius_km": 20, "availability_calendar": {"today": ["09:00", "10:00"]}, "is_online": True
            },
            {
                "uid": "prov_2", "full_name": "Usman", "service_category": "AC Repair",
                "skill_specialization": "Window ACs", "base_rate": 1200, "rating": 4.2,
                "on_time_score": 80, "cancellation_risk_score": 15, "current_location": {"lat": 33.6844, "lng": 73.0479},
                "service_radius_km": 10, "availability_calendar": {"today": ["08:00", "09:00"]}, "is_online": True
            }
        ]
    docs = db.collection("providers").stream()
    return [doc.to_dict() for doc in docs]

from geopy.geocoders import Nominatim
import asyncio

async def geocode_location(location_text: str):
    try:
        # Run synchronous geocoding in a thread to not block event loop
        loop = asyncio.get_event_loop()
        geolocator = Nominatim(user_agent="karobar_ai")
        # Ensure we target Pakistan for better results if user just says "G-13"
        query = f"{location_text}, Pakistan" if "pakistan" not in location_text.lower() else location_text
        location = await loop.run_in_executor(None, geolocator.geocode, query)
        
        if location:
            return {"lat": location.latitude, "lng": location.longitude}
    except Exception as e:
        print(f"Geocoding failed for {location_text}: {e}")
        
    # Default to Islamabad center if failed
    return {"lat": 33.6844, "lng": 73.0479}

async def six_factor_match(parsed_request: dict, excluded_ids: list = None, top_n: int = 5) -> dict:
    if excluded_ids is None:
        excluded_ids = []
        
    providers = await get_all_providers()
    relevant = [
        p for p in providers
        if (p["service_category"].lower() in parsed_request["service_type"].lower()
            or parsed_request["service_type"].lower() in p["service_category"].lower())
        and is_provider_eligible(p, excluded_ids)
    ]

    request_coords = await geocode_location(parsed_request["location"])
    scored = []

    for p in relevant:
        dist = calculate_distance(p["current_location"], request_coords)
        if dist > p.get("service_radius_km", 15):
            continue

        score = (
            (p["rating"] / 5.0)                          * 0.30 +
            (p["on_time_score"] / 100.0)                  * 0.20 +
            availability_score(p, parsed_request["date"],
                               parsed_request["time_preference"]) * 0.20 -
            distance_penalty(dist)                         * 0.15 -
            (p["cancellation_risk_score"] / 100.0)         * 0.10 +
            specialization_match(p, parsed_request["service_type"]) * 0.05
        )

        scored.append({
            "provider": p,
            "score": round(score, 4),
            "distance_km": round(dist, 2),
            "factor_breakdown": {
                "rating_score":        round((p["rating"] / 5.0) * 0.30, 3),
                "on_time_score":       round((p["on_time_score"] / 100.0) * 0.20, 3),
                "availability_score":  round(availability_score(
                                           p, parsed_request["date"],
                                           parsed_request["time_preference"]) * 0.20, 3),
                "distance_penalty":    round(distance_penalty(dist) * 0.15, 3),
                "cancellation_risk":   round((p["cancellation_risk_score"] / 100.0) * 0.10, 3),
                "specialization":      round(specialization_match(
                                           p, parsed_request["service_type"]) * 0.05, 3)
            }
        })

    scored.sort(key=lambda x: x["score"], reverse=True)
    top_matched = scored[:top_n]
    print(f"Agent Log [Matching]: Evaluated={len(scored)}, Selected={len(top_matched)}")
    return {"top_5": top_matched, "total_evaluated": len(scored)}
