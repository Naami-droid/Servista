# Comprehensive UI & Workflow Enhancement Plan

This plan outlines the steps to build a flawless, fully-functional, end-to-end user and provider experience for Servista. The goal is to move from a static UI to a dynamic, logically coherent workflow.

## 1. Provider Dashboard Enhancements
- **Fix Scrolling:** The `ListView.builder` inside `Expanded` is causing scrolling issues when combined with other elements on the web/desktop view. We will wrap the entire body in a `SingleChildScrollView` or `CustomScrollView`.
- **"Active for Jobs" Toggle:** Implement state management for the toggle switch. It should visually update and send a request to the backend to update the provider's availability status.
- **Notification Panel:** Create a modal/drawer when clicking the notification bell that displays a history of received requests.

## 2. Customer Chat & Workflow
- **Voice Input Integration:** We will use the `speech_to_text` package to make the microphone button functional, capturing real voice input for the Roman Urdu queries.
- **Job Lifecycle (Cancellation & Rating):**
  - **Cancellation:** Customers and Providers should have a "Cancel" button.
  - **Rating System:** Upon completion, the customer receives a rating prompt.

## 3. Implementation Steps
1. **Scrolling Fix:** Fix `provider_dashboard.dart` layout.
2. **Toggle State:** Add boolean state and API call for the Active toggle.
3. **Speech to Text:** Add dependencies and implement the mic button in `chat_screen.dart`.
4. **Notifications:** Implement a simple UI popup for notifications.
5. **Testing & Deployment:** Verify all UI interactions and push to GitHub.
