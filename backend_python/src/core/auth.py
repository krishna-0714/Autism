from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
import logging
from supabase import create_client, Client

security = HTTPBearer()
logger = logging.getLogger(__name__)

def get_current_user_id(credentials: HTTPAuthorizationCredentials = Security(security)) -> str:
    token = credentials.credentials
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_KEY", "")
    
    if not url or not key:
        raise HTTPException(status_code=500, detail="Missing Supabase configuration")
        
    try:
        supabase: Client = create_client(url, key)
        user_response = supabase.auth.get_user(token)
        if user_response and user_response.user:
            return user_response.user.id
        raise HTTPException(status_code=401, detail="Invalid token")
    except HTTPException:
        raise
    except Exception:
        logger.exception("Supabase authentication failed")
        raise HTTPException(status_code=401, detail="Authentication failed")
