import pytest
import numpy as np
from src.core.ai_processor import AIProcessor

@pytest.fixture(autouse=True)
def mock_supabase(monkeypatch):
    # Ensure supabase doesn't try to connect during tests
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_KEY", "")

def test_ai_processor_initialization():
    processor = AIProcessor("test_user")
    assert processor.model is None
    assert processor.is_trained is False
    assert processor.features == []

def test_ai_processor_vectorization_empty_features():
    processor = AIProcessor("test_user")
    fp_data = [{"bssid": "aa:bb:cc", "level": -45}]
    vector = processor._vectorize_fingerprints(fp_data)
    assert vector.size == 0

def test_ai_processor_mock_training_and_prediction():
    processor = AIProcessor("test_user")
    
    # Mock data [BSSID 1, BSSID 2]
    X_train = [
        [{"bssid": "A", "level": -30}, {"bssid": "B", "level": -90}], # Close to A (Living Room)
        [{"bssid": "A", "level": -90}, {"bssid": "B", "level": -40}], # Close to B (Bedroom)
    ]
    y_train = ["Living Room", "Bedroom"]
    
    # Train
    processor.update_model(X_train, y_train)
    
    # Assert features learned dynamically
    assert processor.features == ["A", "B"]
    assert processor.is_trained is True

    # Test Prediction Vector 1 -> Expecting Living Room
    test_scan_1 = [{"bssid": "A", "level": -35}]
    prediction_1 = processor.predict_room(test_scan_1)
    assert prediction_1 == "Living Room"

    # Test Prediction Vector 2 -> Expecting Bedroom
    test_scan_2 = [{"bssid": "B", "level": -45}]
    prediction_2 = processor.predict_room(test_scan_2)
    assert prediction_2 == "Bedroom"
