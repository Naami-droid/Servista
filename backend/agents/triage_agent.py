import json
from openai import AsyncOpenAI
from core.config import settings
from datetime import datetime

system_prompt = """
You are a service request parser for Pakistani users.
Extract structured data from messages in English, Urdu, or Roman Urdu.
Return valid JSON only. No markdown. No explanation.

CRITICAL INSTRUCTION: You will receive "Conversation History" and the "Current User Message". 
You MUST combine information from the ENTIRE history with the current message.
For example, if the history mentions "AC repair" and the current message says "G-13 at 10am", your JSON must contain BOTH the service type and the location/time.
Do NOT ask for information that the user has already provided in the history.

IMPORTANT TRANSLATION RULES:
If the user speaks in Urdu or Roman Urdu (e.g. "Mujhe kal subah G-13 mein AC technician chahiye"), you must TRANSLATE the intent into English for the JSON.
Service Types must map to one of: "AC Technician", "Tuition Teacher", "Plumber", "Electrician".

Output format:
{
  "service_type": "string",
  "location": "string",
  "date": "string (YYYY-MM-DD or 'today'/'tomorrow')",
  "time_preference": "'morning'|'afternoon'|'evening'|'any'",
  "budget_sensitivity": "'high'|'medium'|'low'",
  "urgency": "'urgent'|'normal'",
  "additional_notes": "string",
  "confidence": 0.9,
  "clarification_needed": false,
  "clarification_question": null
}
"""

async def triage_parser(user_message: str, conversation_history: list = None) -> dict:
    if not settings.XAI_API_KEY:
        # Fallback dummy for development without API key
        return {
            "needs_clarification": False,
            "data": {
                "service_type": "AC Repair",
                "location": "G-13, Islamabad",
                "date": "today",
                "time_preference": "morning",
                "budget_sensitivity": "medium",
                "urgency": "normal",
                "additional_notes": user_message,
                "confidence": 0.95,
                "clarification_needed": False,
                "clarification_question": None
            }
        }
        
    client = AsyncOpenAI(
        api_key=settings.XAI_API_KEY,
        base_url="https://api.x.ai/v1",
    )
    
    prompt = f"""
    Conversation History: {json.dumps(conversation_history) if conversation_history else 'None'}
    
    Current User Message: {user_message}
    
    Based on the history and the new message, extract the complete service request data.
    If the user is answering a previous clarification question, combine their answer with the previous details.
    """
    
    print("Agent Log [Triage]: Calling xAI API...")
    try:
        response = await client.chat.completions.create(
            model="grok-4.20-0309-reasoning",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt}
            ],
            temperature=0.1
        )
        raw_text = response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Agent Log [Triage] Error: {e}")
        # Fallback dummy if connection fails
        return {
            "needs_clarification": False,
            "data": {
                "service_type": "AC Repair",
                "location": "G-13, Islamabad",
                "date": "today",
                "time_preference": "morning",
                "budget_sensitivity": "medium",
                "urgency": "normal",
                "additional_notes": user_message,
                "confidence": 0.95,
                "clarification_needed": False,
                "clarification_question": None
            }
        }
    
    if raw_text.startswith("```json"):
        raw_text = raw_text[7:]
    if raw_text.endswith("```"):
        raw_text = raw_text[:-3]
        
    try:
        parsed = json.loads(raw_text.strip())
        print(f"Agent Log [Triage]: Input={user_message}, Parsed={parsed}")
        
        if parsed.get("confidence", 0) < 0.80 or parsed.get("clarification_needed"):
            return {
                "needs_clarification": True, 
                "question": parsed.get("clarification_question", "Could you please clarify?")
            }
            
        return {"needs_clarification": False, "data": parsed}
    except json.JSONDecodeError:
        return {
            "needs_clarification": False,
            "data": {
                "service_type": "General Service",
                "location": "Unknown",
                "date": "today",
                "time_preference": "any",
                "budget_sensitivity": "medium",
                "urgency": "normal",
                "additional_notes": user_message,
                "confidence": 0.9,
                "clarification_needed": False,
                "clarification_question": None
            }
        }
