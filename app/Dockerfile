# 1. Base image: lightweight Python runtime
FROM python:3.11-slim

# 2. Environment variables:
# - PYTHONUNBUFFERED=1: Sends logs straight to stdout/stderr (essential for GCP Cloud Logging)
# - PYTHONDONTWRITEBYTECODE=1: Avoids writing .pyc files
# - PORT=8080: Default port expected by GCP Cloud Run
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

# 3. Set application working directory
WORKDIR /app

# 4. Install dependencies (cached in Docker layer)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 5. Copy application code
COPY . .

# 6. Security best practice: run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# 7. Document the default port (informational)
EXPOSE 8080

# 8. Start the application
# python main.py dynamically reads the $PORT env var set by GCP Cloud Run
# and receives SIGTERM directly for graceful shutdowns.
CMD ["python", "main.py"]

