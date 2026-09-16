# GCP Artifact Registry & Cloud Run Commands

A complete reference guide for building, pushing Docker images to **Google Cloud Artifact Registry**, and deploying them onto **Cloud Run**.

---

## 0. Initial Setup

Set your working environment variables in your terminal:

```bash
# Navigate to the application directory
cd app

# Set environment variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export REPO_NAME="my-docker-repo"
export IMAGE_NAME="gcp-python-app"
export TAG="v1"
```

---

## 1. Enable APIs & Create the Repository (One-Time Setup)

### 1.1 Enable Required GCP Services
```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com
```

### 1.2 Create the Docker Repository in Artifact Registry
```bash
gcloud artifacts repositories create ${REPO_NAME} \
  --repository-format=docker \
  --location=${REGION} \
  --description="Docker repository for serverless applications"
```

---

## 2. Method 1: Build & Push with Cloud Build (Recommended)

> **Key Advantage:** Does not require Docker or Docker Desktop to be installed or running locally. Google Cloud handles the container compilation and push remotely in the cloud.

```bash
cd app

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG} .
```

---

## 3. Method 2: Build & Push with Local Docker

If you have Docker Desktop or Colima running on your local machine:

### 3.1 Authenticate Docker with Artifact Registry
```bash
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

### 3.2 Build the Docker Image Locally
```bash
cd app

docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG} .
```

### 3.3 Push the Image to Artifact Registry
```bash
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG}
```

---

## 4. Verify Images in Artifact Registry

List all images and tags stored in your repository:

```bash
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}
```

---

## 5. Deploy Image to Cloud Run (Serverless)

Deploy the Cloud Run service directly from the container image hosted in Artifact Registry:

```bash
gcloud run deploy gcp-python-service \
  --image ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG} \
  --region ${REGION} \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars ENVIRONMENT=dev \
  --min-instances 0 \
  --max-instances 3
```

---

## 6. Useful Monitoring & Maintenance Commands

| Action | Command |
| :--- | :--- |
| **Get Service URL** | `gcloud run services describe gcp-python-service --region=${REGION} --format="value(status.url)"` |
| **Read Live Logs** | `gcloud run services logs read gcp-python-service --region=${REGION} --limit=50` |
| **Delete Container Image** | `gcloud artifacts docker images delete ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${TAG} --quiet` |
| **Delete Cloud Run Service** | `gcloud run services delete gcp-python-service --region=${REGION} --quiet` |
