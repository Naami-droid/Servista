# Servista (Formerly Karobar AI)

An AI-powered agentic orchestration platform for connecting customers with service providers.

## Features
- **Agentic Matchmaking**: Uses xAI to parse natural language requests and pair them with the best providers mathematically and logically.
- **Unified Login System**: A role-based routing architecture using Firebase Authentication and Firestore.
- **Real-Time Dashboards**: Separate customer and provider dashboards to accept/reject and renegotiate service appointments.
- **Live Notifications & Timers**: Countdown timers for pending requests and scheduled background reminders via email.

## Tech Stack
- **Frontend**: Flutter (Web/Mobile)
- **Backend**: FastAPI, Python
- **Database**: Firebase Firestore
- **AI Integration**: xAI (Grok)

## Running the Application

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Frontend
```bash
cd mobile
flutter run -d chrome
```
