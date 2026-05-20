from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional
from agents.triage_agent import triage_parser
from agents.matchmaker import six_factor_match
from agents.reasoning_agent import llm_reasoning

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    customer_id: str
    conversation_history: Optional[List[dict]] = []
    excluded_providers: Optional[List[str]] = []
    parsed_override: Optional[dict] = None

@router.post("/chat")
async def process_chat(request: ChatRequest):
    if request.parsed_override:
        parsed_data = request.parsed_override
    else:
        # 1. Parse natural language using Triage Agent
        triage_result = await triage_parser(request.message, request.conversation_history)
        
        if triage_result.get("needs_clarification"):
            return {"status": "clarify", "message": triage_result.get("question")}
            
        parsed_data = triage_result["data"]
    
    # 2. Find mathematically top 5 providers using Matchmaker
    match_result = await six_factor_match(parsed_data, excluded_ids=request.excluded_providers)
    top_5 = match_result.get("top_5", [])
    
    if not top_5:
        return {"status": "no_providers", "message": "Sorry, no other providers found for this service in your area."}
        
    # 3. Use LLM Reasoning Agent to pick top 2 and generate explanations
    reasoning_result = await llm_reasoning(top_5, parsed_data)
    
    # Extract the top 2 provider details to send back to Flutter UI
    recommended_providers = []
    if "recommended_two" in reasoning_result:
        for rec in reasoning_result["recommended_two"]:
            provider_id = rec.get("provider_id")
            for p in top_5:
                if p["provider"]["uid"] == provider_id:
                    recommended_providers.append({
                        "provider_info": p["provider"],
                        "score_breakdown": p["factor_breakdown"],
                        "distance_km": p.get("distance_km", 0.0),
                        "ai_reasoning": rec
                    })
                    break
    
    return {
        "status": "success",
        "parsed_request": parsed_data,
        "recommended_providers": recommended_providers,
        "reasoning": reasoning_result
    }
