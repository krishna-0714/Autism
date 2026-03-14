from fastapi import APIRouter, HTTPException, Depends
from src.core.ai_processor import AIProcessor
from src.core.auth import get_current_user_id
from pydantic import BaseModel, Field, field_validator
from typing import List, Annotated

router = APIRouter()

class WifiFingerprintSample(BaseModel):
    bssid: str
    level: int


class TrainingRequest(BaseModel):
    scans: Annotated[List[List[WifiFingerprintSample]], Field(min_length=2, max_length=100)]  # List of labeled Wi-Fi scans
    labels: Annotated[List[str], Field(min_length=2, max_length=100)]  # Room label for each scan

    @field_validator("scans")
    @classmethod
    def validate_scan_sizes(cls, scans: List[List[WifiFingerprintSample]]) -> List[List[WifiFingerprintSample]]:
        for scan in scans:
            if len(scan) == 0:
                raise ValueError("Each scan must include at least one fingerprint.")
            if len(scan) > 200:
                raise ValueError("Each scan must include at most 200 fingerprints.")
        return scans


class TrainingResponse(BaseModel):
    success: bool
    message: str
    rooms_learned: List[str]


@router.post("/train-model", response_model=TrainingResponse)
async def train_model(request: TrainingRequest, user_id: str = Depends(get_current_user_id)):
    """
    Trains the KNN model with labeled Wi-Fi scan data.
    Send multiple scans with their corresponding room labels.
    The model is persisted securely to Supabase for each user.
    """
    ai_engine = AIProcessor(user_id)
    
    if len(request.scans) != len(request.labels):
        raise HTTPException(
            status_code=400,
            detail="Number of scans must equal number of labels.",
        )

    if len(request.scans) < 2:
        raise HTTPException(
            status_code=400,
            detail="At least 2 labeled scans are required to train the model.",
        )

    # Convert Pydantic models to plain dicts for AIProcessor
    x_train = [
        [fp.model_dump() for fp in scan]
        for scan in request.scans
    ]

    try:
        ai_engine.update_model(x_train, request.labels)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Training failed: {str(e)}")

    unique_rooms = sorted(set(request.labels))

    return TrainingResponse(
        success=True,
        message=f"Model trained successfully on {len(request.scans)} scans.",
        rooms_learned=unique_rooms,
    )
