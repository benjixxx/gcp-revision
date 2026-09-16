import os
import socket
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException

app = FastAPI(
    title="GCP Serverless Python App",
    description="A lightweight production-ready Python API tailored for GCP Cloud Run.",
    version="1.0.0",
)


@app.get("/", tags=["General"])
def read_root() -> Dict[str, Any]:
    """Root endpoint providing service metadata and environment info."""
    return {
        "message": "Hello from Google Cloud Serverless!",
        "service": "cloud-run-python-app",
        "container_id": socket.gethostname(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": os.getenv("ENVIRONMENT", "dev"),
    }


@app.get("/health", tags=["Health"])
def health_check() -> Dict[str, str]:
    """Liveness and readiness health check probe."""
    return {"status": "healthy"}


@app.get("/items/{item_id}", tags=["Sample"])
def get_item(item_id: int, q: Optional[str] = None) -> Dict[str, Any]:
    """Sample parameterised endpoint."""
    if item_id <= 0:
        raise HTTPException(status_code=400, detail="Item ID must be positive")
    return {"item_id": item_id, "query": q}


if __name__ == "__main__":
    import uvicorn

    # Cloud Run injects the PORT environment variable (defaults to 8080)
    port = int(os.environ.get("PORT", 8080))
    # Listen on 0.0.0.0 so Cloud Run can route external requests to the container
    uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info")

