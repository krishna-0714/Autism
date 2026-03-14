import os
import warnings
from dotenv import load_dotenv

load_dotenv()


class Settings:
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")

    def __init__(self):
        if not self.SUPABASE_URL:
            warnings.warn(
                "SUPABASE_URL is not set. Supabase features will be unavailable.",
                RuntimeWarning,
                stacklevel=2,
            )
        if not self.SUPABASE_KEY:
            warnings.warn(
                "SUPABASE_KEY is not set. Supabase features will be unavailable.",
                RuntimeWarning,
                stacklevel=2,
            )


settings = Settings()
