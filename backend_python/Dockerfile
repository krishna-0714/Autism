# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
ENV WEB_CONCURRENCY=1

# Set work directory
WORKDIR /app

# Install system dependencies (needed for compiling some python extensions, ML libraries, and healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY backend_python/requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the actual project
COPY backend_python/src/ /app/src/
COPY backend_python/main.py /app/main.py

# Create a non-root user for security (Prevents container breakout)
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose the API port
EXPOSE 8000

# Railway healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD sh -c "curl -fsS http://localhost:${PORT:-8000}/health || exit 1"

# Command to run the application using Gunicorn to handle concurrent Uvicorn workers
CMD gunicorn main:app --workers ${WEB_CONCURRENCY:-1} --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
