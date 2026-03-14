#!/bin/sh
# Shell script to quickly boot the FastAPI backend for production testing

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting Autism Assist AI Microservice..."

# Determine the port to bind to (Defaults to 8000)
PORT=${PORT:-8000}
WEB_CONCURRENCY=${WEB_CONCURRENCY:-1}

# Start the application using Gunicorn with Uvicorn workers
# This provides process management and handles multiple concurrent requests securely.
exec gunicorn main:app \
  --workers "$WEB_CONCURRENCY" \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:$PORT \
  --timeout 120 \
  --log-level info
