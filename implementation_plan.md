# Comprehensive System Upgrade Plan

You have requested a major expansion of the Karobar AI platform! This involves swapping the core AI engine, adding authentication, implementing real-time notifications, and creating a provider workflow.

Due to the size of this request, I have broken it down into logical phases.

## User Review Required

> [!WARNING]
> **Push Notifications & Authentication**
> Implementing real push notifications (outside the app) on Android/iOS requires actual Firebase Cloud Messaging (FCM) setup, which usually requires generating Google-services.json files and Apple APNs certificates. I can write all the code for it, but you will need to register the Android app in your Firebase Console for it to actually buzz your phone.

## Open Questions

> [!IMPORTANT]
> 1. **xAI API Key**: Do you already have an `XAI_API_KEY` ready to put in your `.env` file?
> 2. **Provider App Interface**: Currently, we only built the "Customer" side of the app. To allow providers to "confirm" jobs and "communicate", I will need to build a new screen in the Flutter app for Providers. Does that sound good?
> 3. **Firebase Auth**: I will add the `firebase_auth` package to Flutter. This requires enabling "Email/Password" sign-in in your Firebase Console. Are you okay with that?

## Proposed Changes

### Phase 1: AI Engine Migration (Gemini to xAI)
- **[MODIFY]** `backend/requirements.txt`: Add `openai` SDK (xAI uses the OpenAI SDK format).
- **[MODIFY]** `backend/core/config.py`: Replace `GEMINI_API_KEY` with `XAI_API_KEY`.
- **[MODIFY]** `backend/agents/triage_agent.py` & `reasoning_agent.py`: Rewrite to use the `openai` client pointing to `https://api.x.ai/v1` and the `grok-beta` or `grok-2` model.
- **[MODIFY]** `mobile/lib/features/customer/chat_screen.dart`: Update the UI to stream or show the "Agentic reasoning" blocks (why it chose to do things) in the chat feed *before* showing the final provider cards.

### Phase 2: Authentication & Multi-Role Setup
- **[NEW]** `mobile/lib/features/auth/auth_screen.dart`: A screen to Sign Up / Log In and choose an account type ("Customer" or "Service Provider").
- **[MODIFY]** `backend/seed_db.py`: Wipe the dummy providers and create exactly 1 User and multiple Providers using the email `mrnaami2004@gmail.com`, setting up custom Firebase Auth accounts and database records for them.
- **[MODIFY]** `mobile/lib/main.dart`: Add an authentication listener to route logged-in users to either the Customer Chat or the Provider Dashboard.

### Phase 3: Notifications & Provider Workflow
- **[NEW]** `mobile/lib/features/provider/provider_dashboard.dart`: A UI where providers see incoming requests and can hit "Accept" or "Reject".
- **[MODIFY]** `backend/routers/agent.py`: When a user selects a provider, it creates a `PENDING` booking and sends an FCM push notification to the specific provider.
- **[NEW]** `backend/routers/booking.py`: Endpoints for the Provider to `/accept` or `/reject` the booking.
  - If **Rejected**: Backend pushes a notification to the user asking if they want to search again.
  - If **Accepted**: Backend schedules a job (using APScheduler) to send a notification 1 hour before the appointment, and updates the booking status to `CONFIRMED`.
- **[MODIFY]** `mobile/lib/features/customer/chat_screen.dart`: Add a Notification Bell icon at the top that opens a list of incoming notifications.

## Verification Plan
1. **Authentication Test**: Register a customer and a provider. Verify they route to different screens.
2. **xAI Test**: Send a chat message and verify the backend successfully uses Grok/xAI to parse the text and generate reasoning, and that the UI shows this reasoning in real-time.
3. **End-to-End Workflow**:
   - Customer requests an AC repair.
   - Provider receives a notification.
   - Provider hits "Accept".
   - Customer receives "Confirmed" notification.
   - Wait/Simulate the 1-hour APScheduler job to verify the reminder fires.
