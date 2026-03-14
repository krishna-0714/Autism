from fastapi import APIRouter, Depends
from src.core.ai_processor import AIProcessor
from src.core.auth import get_current_user_id
from pydantic import BaseModel, Field
from typing import List, Annotated

router = APIRouter()

class FingerprintInput(BaseModel):
    bssid: str
    ssid: str
    level: int
    frequency: int
    timestamp: int

class ContextRequest(BaseModel):
    fingerprints: Annotated[List[FingerprintInput], Field(min_length=1, max_length=200)]

class ContextResponse(BaseModel):
    room: str

@router.post("/process-context", response_model=ContextResponse)
async def process_context(request: ContextRequest, user_id: str = Depends(get_current_user_id)):
    """
    Receives raw Wi-Fi fingerprints from Flutter and feeds them into the KNN ML Model.
    """
    ai_engine = AIProcessor(user_id)
    
    # Convert Pydantic models back to simple dicts for the AIProcessor
    fp_dicts = [fp.model_dump() for fp in request.fingerprints]
    
    predicted_room = ai_engine.predict_room(fp_dicts)
    
    # If the model couldn't determine, or isn't trained, fallback
    if not predicted_room:
         predicted_room = "Unknown Context"
         
    return ContextResponse(room=predicted_room)
