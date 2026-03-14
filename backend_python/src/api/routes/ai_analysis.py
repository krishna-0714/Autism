from fastapi import APIRouter
from src.models.schemas import SentimentRequest, SentimentResponse
from textblob import TextBlob

router = APIRouter()

@router.post("/analyze-sentiment", response_model=SentimentResponse)
async def analyze_sentiment(request: SentimentRequest):
    """
    Analyzes the text from the child for signs of distress or negative emotion.
    Returns a score from -1.0 (very negative) to 1.0 (very positive).
    """
    analysis = TextBlob(request.text)
    score = analysis.sentiment.polarity
    
    # Logic: If the score is negative enough, flag it as distressed
    is_distressed = score < -0.2
    
    # Generate a simple recommendation based on the score
    if score < -0.5:
        recommendation = "High distress detected. Immediate caregiver attention recommended. Suggest sensory safe-room."
    elif score < -0.2:
        recommendation = "Mild frustration detected. Monitor closely. Suggesting a break or calming activity."
    elif score > 0.5:
        recommendation = "Positive emotion detected. Positive reinforcement recommended."
    else:
        recommendation = "Neutral or calm state. Normal routine can continue."

    return SentimentResponse(
        original_text=request.text,
        sentiment_score=score,
        is_distressed=is_distressed,
        ai_recommendation=recommendation
    )
