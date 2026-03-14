import os
import pickle
import hmac
import hashlib
import time
import numpy as np
from typing import List, Dict, Optional
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import StandardScaler
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

class AIProcessor:
    """
    Core AI logic for processing Wi-Fi fingerprints to determine room context.
    Uses K-Nearest Neighbors (KNN) for robust spatial classification.
    Automatically serializes/deserializes the trained model.
    """

    def __init__(self, user_id: str):
        self.scaler = StandardScaler()
        self.features: List[str] = []
        self.model: Optional[KNeighborsClassifier] = None
        self.is_trained = False
        self.user_id = user_id
        
        url: str = os.getenv("SUPABASE_URL", "")
        key: str = os.getenv("SUPABASE_KEY", "")
        if url and key:
            self.supabase: Client = create_client(url, key)
        else:
            self.supabase = None

        self._load_model()

    def _load_model(self):
        if not self.supabase:
            return
        try:
            response = self.supabase.table('user_models').select('model_bytes').eq('user_id', self.user_id).execute()
            if response.data and len(response.data) > 0:
                model_blob = response.data[0]['model_bytes']
                if model_blob:
                    payload_hex = model_blob
                    is_legacy_payload = False
                    if ":" not in model_blob:
                        if not self._accept_legacy_models():
                            print("Rejected unsigned model payload.")
                            return
                        is_legacy_payload = True
                    else:
                        signature, payload_hex = model_blob.split(":", 1)
                        if not self._verify_signature(payload_hex, signature):
                            print("Rejected model payload with invalid signature.")
                            return
                    model_bytes = bytes.fromhex(payload_hex)
                    data = pickle.loads(model_bytes)
                    if data.get("model") is not None:
                        self.model = data["model"]
                        self.scaler = data["scaler"]
                        self.features = data["features"]
                        self.is_trained = True
                        if is_legacy_payload and self._sign_payload(payload_hex):
                            # Upgrade legacy unsigned payloads in place after successful load.
                            self._save_model()
        except Exception as e:
            print(f"Error loading model from DB: {e}")

    def _save_model(self):
        if not self.supabase:
            return
        try:
            model_bytes = pickle.dumps(
                {"model": self.model, "scaler": self.scaler, "features": self.features}
            )
            model_hex = model_bytes.hex()
            signature = self._sign_payload(model_hex)
            if not signature:
                print("Skipping model save because signing key is missing.")
                return
            model_blob = f"{signature}:{model_hex}"
            
            self.supabase.table('user_models').upsert({
                "user_id": self.user_id,
                "model_bytes": model_blob,
                "updated_at": int(time.time()),
            }).execute()
        except Exception as e:
            print(f"Error saving model to DB: {e}")

    def _get_signing_key(self) -> bytes:
        key = os.getenv("MODEL_SIGNING_KEY") or os.getenv("SUPABASE_KEY", "")
        return key.encode("utf-8")

    def _sign_payload(self, payload_hex: str) -> str:
        key = self._get_signing_key()
        if not key:
            return ""
        return hmac.new(key, payload_hex.encode("utf-8"), hashlib.sha256).hexdigest()

    def _verify_signature(self, payload_hex: str, signature: str) -> bool:
        expected = self._sign_payload(payload_hex)
        if not expected:
            return False
        return hmac.compare_digest(signature, expected)

    def _accept_legacy_models(self) -> bool:
        raw_value = os.getenv("ALLOW_LEGACY_UNSIGNED_MODELS", "true")
        return raw_value.lower() in {"1", "true", "yes", "on"}

    def _vectorize_fingerprints(self, user_fingerprints: List[Dict]) -> np.ndarray:
        """
        Converts the dynamic length BSSID list into a fixed-length feature vector.
        Unseen BSSIDs are ignored; missing BSSIDs default to -100 dBm.
        """
        if not self.features:
            return np.array([])

        vector = np.full(len(self.features), -100.0)
        fp_dict = {fp["bssid"]: fp["level"] for fp in user_fingerprints}
        for i, bssid in enumerate(self.features):
            if bssid in fp_dict:
                vector[i] = fp_dict[bssid]

        return vector.reshape(1, -1)

    def predict_room(self, user_fingerprints: List[Dict]) -> Optional[str]:
        """
        Predicts the closest room based on the KNN model.
        Falls back gracefully if the model is not trained yet.
        """
        if not user_fingerprints:
            return None

        if not self.is_trained or self.model is None:
            sorted_networks = sorted(
                user_fingerprints, key=lambda x: x.get("level", -100), reverse=True
            )
            if sorted_networks[0].get("level", -100) > -50:
                return "Living Room (Heuristic)"
            return "Unknown Context"

        vector = self._vectorize_fingerprints(user_fingerprints)
        if vector.size == 0:
            return "Unknown Context"

        vector_scaled = self.scaler.transform(vector)
        if self.model is not None:
            prediction = self.model.predict(vector_scaled)
            return prediction[0]
        return "Unknown Context"

    def update_model(self, X_train: List[List[Dict]], y_train: List[str]):
        """
        Trains the KNN model dynamically using labeled environmental data.
        n_neighbors is capped at the number of training samples to avoid
        ValueError when the dataset is small.
        """
        if not X_train or not y_train:
            raise ValueError("Training data and labels are required.")
        if len(X_train) != len(y_train):
            raise ValueError("Training data and labels length mismatch.")

        bssid_set: set = set()
        for scan in X_train:
            for fp in scan:
                bssid_set.add(fp["bssid"])

        self.features = sorted(list(bssid_set))
        if not self.features:
            raise ValueError("No valid BSSID features found in training data.")

        matrix = []
        for scan in X_train:
            vector = np.full(len(self.features), -100.0)
            fp_dict = {fp["bssid"]: fp["level"] for fp in scan}
            for i, bssid in enumerate(self.features):
                if bssid in fp_dict:
                    vector[i] = fp_dict[bssid]
            matrix.append(vector)

        X_matrix = np.array(matrix)
        y_array = np.array(y_train)

        # Cap n_neighbors to avoid ValueError when training set is small
        n_neighbors = min(3, len(X_train))
        if self.model is None or not self.is_trained:
             self.model = KNeighborsClassifier(n_neighbors=n_neighbors, weights="distance")

        X_scaled = self.scaler.fit_transform(X_matrix)
        if self.model is not None:
            self.model.fit(X_scaled, y_array)
            self.is_trained = True

        self._save_model()
