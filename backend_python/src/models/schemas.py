from pydantic import BaseModel
from typing import Optional

class SentimentRequest(BaseModel):
    text: str
    child_id: Optional[str] = None
    context: Optional[str] = None

class SentimentResponse(BaseModel):
    original_text: str
    sentiment_score: float
    is_distressed: bool
    ai_recommendation: str
