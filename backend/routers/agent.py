from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional
import logging
from agents.triage_agent import triage_parser
from agents.matchmaker import six_factor_match
from agents.reasoning_agent import llm_reasoning

router = APIRouter()

# Configure logger for agent workflows
logger = logging.getLogger("agentic_workflow")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    logger.addHandler(ch)

class ChatRequest(BaseModel):
    message: str
    customer_id: str
    conversation_history: Optional[List[dict]] = []
    excluded_providers: Optional[List[str]] = []
    parsed_override: Optional[dict] = None

@router.post("/chat")
async def process_chat(request: ChatRequest):
    logger.info(f"\n{'='*50}\n🚀 [Agentic Workflow Started] Request from Customer: {request.customer_id}")
    
    if request.parsed_override:
        logger.info(f"⏭️ [Triage Bypassed] Using override parsed data: {request.parsed_override}")
        parsed_data = request.parsed_override
    else:
        logger.info(f"🧠 [Triage Agent Calling] Analyzing natural language: '{request.message}'")
        # 1. Parse natural language using Triage Agent
        triage_result = await triage_parser(request.message, request.conversation_history)
        
        if triage_result.get("needs_clarification"):
            logger.info(f"❓ [Triage Agent Result] Needs clarification. Asking: '{triage_result.get('question')}'")
            return {"status": "clarify", "message": triage_result.get("question")}
            
        parsed_data = triage_result["data"]
        logger.info(f"✅ [Triage Agent Result] Extracted structured data: {parsed_data}")
    
    logger.info(f"⚙️ [Matchmaker Tool Calling] Scoring & filtering database using 6-factor algorithm...")
    # 2. Find mathematically top 5 providers using Matchmaker
    match_result = await six_factor_match(parsed_data, excluded_ids=request.excluded_providers)
    top_5 = match_result.get("top_5", [])
    
    if not top_5:
        logger.warning(f"❌ [Matchmaker Tool Result] No valid providers found for criteria.")
        return {"status": "no_providers", "message": "Sorry, no other providers found for this service in your area."}
        
    logger.info(f"✅ [Matchmaker Tool Result] Found {len(top_5)} candidate providers. Passing to LLM...")
    
    logger.info(f"⚖️ [Reasoning Agent Calling] Deep evaluating {len(top_5)} candidates to pick Top 2 & generate tradeoffs...")
    # 3. Use LLM Reasoning Agent to pick top 2 and generate explanations
    reasoning_result = await llm_reasoning(top_5, parsed_data)
    
    # Extract the top 2 provider details to send back to Flutter UI
    recommended_providers = []
    if "recommended_two" in reasoning_result:
        selected_ids = [r.get("provider_id") for r in reasoning_result["recommended_two"]]
        logger.info(f"✅ [Reasoning Agent Result] Selected Providers: {selected_ids}")
        logger.info(f"💡 [Reasoning Agent Logic] Why others excluded: '{reasoning_result.get('why_others_excluded', 'N/A')}'")
        
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
    
    logger.info(f"🏁 [Workflow Complete] Sending final payload to client UI.\n{'='*50}")
    return {
        "status": "success",
        "parsed_request": parsed_data,
        "recommended_providers": recommended_providers,
        "reasoning": reasoning_result
    }
