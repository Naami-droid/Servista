# Servista (Karobar & Informal Economy AI) 🚀
**Challenge 2: AI Service Orchestrator for Informal Economy**

Servista is a powerful, Agentic AI-driven platform that automates the end-to-end lifecycle of informal service requests (Plumbers, AC Technicians, Electricians, Tutors) across Pakistan. Built strictly on **Google Antigravity** as the core orchestration layer, Servista eliminates the chaos of WhatsApp groups and phone calls by intelligently parsing natural language (Urdu, Roman Urdu, English), ranking the best nearby providers, executing simulated bookings, and tracking automated follow-ups.

---

## 🌟 Hackathon Requirements & Mobile/PWA Surgical Enhancements

### 1. Intent Understanding (Urdu / Roman Urdu Support):
- The platform flawlessly understands mixed languages.
- Example handled: *"Mujhe kal subah G-13 mein AC technician chahiye"* automatically extracts the service type (`AC Technician`), location (`G-13`), and time (`tomorrow morning`).

### 2. Provider Discovery & Location Context:
- Instead of static dummy matching, Servista leverages `geopy` and `Nominatim` to geocode locations like "G-13" into real Lat/Lng coordinates.
- The dataset simulates 1000 geographically distributed service providers across 4 categories.

### 3. Matching & Ranking Algorithm:
- **6-Factor Agentic Matching:** Providers are ranked based on real-time geodesic distance (km), availability calendars, 5-star rating systems, on-time scores, and historical cancellation risk.

### 4. Action Simulation (End-to-End Execution):
- **Simulated Booking:** When a provider accepts a job, the system transitions state to `CONFIRMED` and establishes a real-time HTTP-polling Live Chat room.
- **Service Completed:** Providers can mark jobs as `COMPLETED`.
- **Review Workflow:** Customers instantly receive a prompt to leave a 5-star review, which permanently updates the Provider's database record.

### 5. Follow-Up Automation:
- A specialized Background Timer Agent continually monitors deadlines. 
- If a provider ignores a request for 3 minutes, the system simulates a timeout, searches for new providers, and **permanently penalizes the unresponsive provider's rating and risk score**.

### 6. PWA Enablement & Mobile-Native Performance:
- **Service Worker Caching & Fallback:** Registered custom `service-worker.js` with strategic network-first caching and a dedicated `offline.html` fallback page.
- **Dynamic API Connection:** Integrated local persistence via `SharedPreferences` in `AuthScreen` allowing testing on physical Android devices by entering dynamic base URLs.
- **In-App PWA Install Banner:** A custom modern bottom install bar widget listening to `beforeinstallprompt` via JS-to-Dart bindings.
- **Web Share & QR Modal:** A gorgeous reusable popup modal generating QR codes dynamically for easy mobile device testing, combined with `navigator.share` fallback.
- **Dynamic Light/Dark Theme:** Material 3 theme toggle switcher with smooth transitions and state persistence.
- **Screen Wake Lock API:** Ensures the screen doesn't timeout or turn off while providers/customers are on active tracking or live chat screens.
- **Offline Mutation Sync:** An `OfflineSyncService` that intercepts network requests on network failure, queues mutations locally, and syncs them once the network returns.

---

## 🤖 The Agentic Pipeline Architecture

The system is composed of 4 specialized Autonomous Agents:

1. **Triage Agent (`triage_agent.py`):** The natural language parser. It standardizes messy Roman Urdu into a strict, unified JSON schema.
2. **Matchmaker Agent (`matchmaker.py`):** The data cruncher. It runs the geodesic math, filters the 1000+ Firestore providers, and ranks the Top 5 candidates based on our 6-factor algorithm.
3. **Reasoning Agent (`reasoning_agent.py`):** The decider. It evaluates the Matchmaker's Top 5, selects the best 2 candidates, and generates a human-readable justification (e.g., *"Ali AC Services is the optimal choice because they are only 2.1km away with a 4.8 rating"*).
4. **Timer/Follow-up Agent (`timer_agent.py`):** The background enforcer. It handles simulated scheduling, sends notifications, enforces response timeouts, and dynamically updates provider reliability scores.

---

## 🛠 Tech Stack

*   **Frontend:** Flutter (Mobile App for both Customers and Providers)
*   **Backend:** FastAPI (Python)
*   **Database:** Firebase Firestore
*   **AI Models:** xAI / OpenAI via standard completions API
*   **Geospatial:** Geopy / Nominatim for real-time location resolution
*   **Orchestration:** Google Antigravity (Strictly orchestrated multi-step reasoning)

---

## 🚀 Deployment & CI/CD Configs

The app includes templates for zero-config deployments:
*   **Vercel:** `vercel.json` configurations for builds, routing, and PWA assets.
*   **Netlify:** `netlify.toml` configurations for automated web builds.
*   **GitHub Actions:** `.github/workflows/ci.yml` compiles, formats, lints, and runs tests on push/pull requests.

---

## 📱 Demo Flow (How to Test)

1. **Customer Login:** Use the Flutter app to login as a Customer.
2. **Submit Query:** Type *"Mujhe kal subah G-13 mein AC technician chahiye"* in the chat.
3. **Observe Reasoning:** Click the "Reasoning" dropdown in the chat to see the AI's traceable logs and decision logic.
4. **Provider Login:** In a second simulator or window, login as the selected Provider.
5. **Dashboard:** You will see a live ticking countdown timer. Press **Accept**.
6. **Live Chat & Completion:** Both sides transition to `CONFIRMED`. Open the Live Chat to coordinate. Once done, the provider clicks **Mark Service Completed**.
7. **Follow-up:** The customer is prompted to leave a review, completing the entire informal economy lifecycle!

