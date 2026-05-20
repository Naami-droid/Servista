import json
from openai import AsyncOpenAI
from core.config import settings

system_prompt = """
You are an expert service matching advisor for Pakistan's informal economy.

Analyze the top mathematically scored providers and select the best 2 to 
recommend to the customer. Consider holistic fit beyond just the score.

Return JSON only in this format:
{
  "recommended_two": [
    {
      "provider_id": "string",
      "rank": 1,
      "headline": "string (max 8 words)",
      "reasoning": "string (2-3 sentences)",
      "tradeoff": "string (1 sentence)"
    },
    {
      "provider_id": "string",
      "rank": 2,
      "headline": "string",
      "reasoning": "string",
      "tradeoff": "string"
    }
  ],
  "why_others_excluded": "string",
  "overall_recommendation": 1
}
"""

async def llm_reasoning(top_providers: list, request: dict, excluded: list = None) -> dict:
    if excluded is None:
        excluded = []
        
    if not settings.XAI_API_KEY:
        if len(top_providers) == 0:
            return {"error": "No providers available"}
        
        recs = []
        for i, p_wrapper in enumerate(top_providers[:2]):
            p = p_wrapper["provider"]
            recs.append({
                "provider_id": p["uid"],
                "rank": i + 1,
                "headline": f"{p['full_name']} - Top Rated",
                "reasoning": f"{p['full_name']} is highly rated with {p['rating']} stars.",
                "tradeoff": "Slightly more expensive."
            })
            
        return {
            "recommended_two": recs,
            "why_others_excluded": "Other providers were too far away or had lower ratings.",
            "overall_recommendation": 1
        }
        
    client = AsyncOpenAI(
        api_key=settings.XAI_API_KEY,
        base_url="https://api.x.ai/v1",
    )
    
    prompt = f"""
Service Request: {json.dumps(request, default=str)}
Top Providers: {json.dumps(top_providers, default=str)}
Previously Excluded Providers: {json.dumps(excluded, default=str)}
    """
    
    print("Agent Log [Reasoning]: Calling xAI API...")
    try:
        response = await client.chat.completions.create(
            model="grok-4.20-0309-reasoning",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3
        )
        raw_text = response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error calling xAI: {e}")
        # Fallback dummy if connection fails
        if len(top_providers) == 0:
            return {"error": "No providers available"}
        
        recs = []
        for i, p_wrapper in enumerate(top_providers[:2]):
            p = p_wrapper["provider"]
            recs.append({
                "provider_id": p["uid"],
                "rank": i + 1,
                "headline": f"{p['full_name']} - Top Rated",
                "reasoning": f"{p['full_name']} is highly rated with {p['rating']} stars.",
                "tradeoff": "Slightly more expensive."
            })
            
        return {
            "recommended_two": recs,
            "why_others_excluded": "Other providers were excluded due to API connection failure or lower ratings.",
            "overall_recommendation": 1
        }
    
    if raw_text.startswith("```json"):
        raw_text = raw_text[7:]
    if raw_text.endswith("```"):
        raw_text = raw_text[:-3]
        
    try:
        parsed = json.loads(raw_text.strip())
        print(f"Agent Log [Reasoning]: Parsed={parsed}")
        return parsed
    except json.JSONDecodeError:
        print(f"Error parsing LLM response: {raw_text}")
        return {"error": "Failed to generate reasoning."}
