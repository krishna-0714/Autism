from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from src.api.routes import ai_analysis, context_routing, training

app = FastAPI(
    title="Autism Assist AI Microservice",
    description="Python backend providing AI processing for the Autism Assist App.",
    version="1.0.0"
)

print("Starting Autism Assist AI Microservice...")


# Custom middleware to add security headers
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response: Response = await call_next(request)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Content-Security-Policy"] = "default-src 'self'"
        return response


app.add_middleware(SecurityHeadersMiddleware)

# Strict CORS for the mobile app only (Allow local testing and future production)
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://127.0.0.1",
    "http://api.autismassist.com",
    "capacitor://localhost",
    "http://localhost:8080"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# Include the AI routes
app.include_router(ai_analysis.router, prefix="/api/v1", tags=["Sentiment Analysis"])
app.include_router(context_routing.router, prefix="/api/v1", tags=["Spatial Context AI"])
app.include_router(training.router, prefix="/api/v1", tags=["Model Training"])


@app.get("/")
def read_root():
    return {"message": "Autism Assist AI Microservice is running!"}


@app.get("/health")
def health_check():
    # Used by Railway to verify the server started correctly
    return {"status": "ok", "version": "1.0.0"}
