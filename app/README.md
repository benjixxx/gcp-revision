# GCP Serverless Python Application

A production-ready lightweight Python application (FastAPI) configured for Google Cloud Serverless services like **Cloud Run** and **Cloud Run functions**.

---

## Project Structure

```
app/
├── Dockerfile           # Optimized multi-layer Dockerfile for Cloud Run
├── .dockerignore        # Build context exclusions
├── main.py              # FastAPI app with health check & root endpoints
├── requirements.txt     # Dependencies (fastapi, uvicorn)
└── README.md            # Documentation & deployment instructions
```

---

## 1. Local Development (Without Docker)

Create a virtual environment and start the app:

```bash
cd app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run directly
python main.py
# Or with auto-reload:
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

Access the API:
- Root endpoint: http://localhost:8080/
- Health check: http://localhost:8080/health
- Interactive Swagger docs: http://localhost:8080/docs

---

## 2. Test Locally with Docker

Build and run the container locally:

```bash
cd app

# Build Docker image
docker build -t gcp-python-app .

# Run container (listening on port 8080)
docker run --rm -p 8080:8080 -e PORT=8080 gcp-python-app
```

Test it in another terminal:
```bash
curl http://localhost:8080/
curl http://localhost:8080/health
```

---

## 3. Deploy to GCP Cloud Run

### Prerequisites
Make sure you are authenticated and have configured your GCP project:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
```

### Option A: Direct Source Deployment (Simplest)
Cloud Run can build and deploy the container in one step using Cloud Build:

```bash
cd app

gcloud run deploy gcp-python-app \
  --source . \
  --region europe-west1 \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 5
```

### Option B: Build to Artifact Registry & Deploy
If your workflow separates image building from service deployment:

1. **Create an Artifact Registry repository** (one-time setup):
   ```bash
   gcloud artifacts repositories create cloud-run-repo \
     --repository-format=docker \
     --location=europe-west1 \
     --description="Docker repository for Cloud Run services"
   ```

2. **Build and push image with Cloud Build**:
   ```bash
   cd app
   gcloud builds submit --tag europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/cloud-run-repo/gcp-python-app:v1
   ```

3. **Deploy the image to Cloud Run**:
   ```bash
   gcloud run deploy gcp-python-app \
     --image europe-west1-docker.pkg.dev/YOUR_PROJECT_ID/cloud-run-repo/gcp-python-app:v1 \
     --region europe-west1 \
     --allow-unauthenticated \
     --set-env-vars ENVIRONMENT=prod
   ```

---

## GCP Cloud Run Architecture Checklist

| Cloud Run Requirement | How It Is Handled |
| :--- | :--- |
| **Port Binding** | Cloud Run sets `$PORT` (default 8080). `main.py` reads `PORT` from the environment and binds to `0.0.0.0`. |
| **Unbuffered Logging** | `ENV PYTHONUNBUFFERED=1` in `Dockerfile` ensures all `print` and `logger` outputs are instantly streamed to Google Cloud Logging. |
| **Non-Root User** | Container runs as unprivileged user `appuser` (UID 1000) for security compliance. |
| **Graceful Shutdown** | `CMD ["python", "main.py"]` receives the OS `SIGTERM` signal directly, allowing in-flight requests to complete before termination. |
| **Health Probes** | `/health` endpoint is available for startup/liveness probes. |
| **Statelessness** | No state is stored in memory or disk, enabling scaling to zero and rapid scale-out. |

