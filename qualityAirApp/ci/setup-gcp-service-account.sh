#!/usr/bin/env bash
# ==============================================================================
# Setup Script: GCP Service Account & Artifact Registry for GitHub Actions CI
# ==============================================================================

set -euo pipefail

# 1. Configuration Variables
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "myproject-329912")
REGION="europe-west1"
REPO_NAME="quality-air-repo"
SA_NAME="github-actions-sa"
SA_DISPLAY_NAME="GitHub Actions CI/CD Service Account"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="github-actions-sa-key.json"

echo "================================================================="
echo " Configuring GCP for GitHub Actions CI"
echo " Project ID:       ${PROJECT_ID}"
echo " Region:           ${REGION}"
echo " Artifact Repo:    ${REPO_NAME}"
echo " Service Account:  ${SA_EMAIL}"
echo "================================================================="

# 2. Enable Required APIs
echo "[1/5] Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com --project="${PROJECT_ID}"

# 3. Create Artifact Registry Docker Repository (if not already created)
echo "[2/5] Checking/Creating Artifact Registry repository '${REPO_NAME}'..."
if ! gcloud artifacts repositories describe "${REPO_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud artifacts repositories create "${REPO_NAME}" \
        --repository-format=docker \
        --location="${REGION}" \
        --description="Docker repository for QualityAirApp" \
        --project="${PROJECT_ID}"
    echo "Created Artifact Registry repository: ${REPO_NAME}"
else
    echo "Repository '${REPO_NAME}' already exists in ${REGION}."
fi

# 4. Create Dedicated Service Account (if not already created)
echo "[3/5] Checking/Creating Service Account '${SA_NAME}'..."
if ! gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud iam service-accounts create "${SA_NAME}" \
        --display-name="${SA_DISPLAY_NAME}" \
        --project="${PROJECT_ID}"
    echo "Created Service Account: ${SA_EMAIL}"
else
    echo "Service Account '${SA_EMAIL}' already exists."
fi

# 5. Grant Least-Privilege IAM Role (roles/artifactregistry.writer)
echo "[4/5] Granting 'roles/artifactregistry.writer' on repository '${REPO_NAME}'..."
gcloud artifacts repositories add-iam-policy-binding "${REPO_NAME}" \
    --location="${REGION}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/artifactregistry.writer" \
    --project="${PROJECT_ID}"

# 6. Generate Service Account JSON Key
echo "[5/5] Generating Service Account Key (${KEY_FILE})..."
gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account="${SA_EMAIL}" \
    --project="${PROJECT_ID}"

echo ""
echo "================================================================="
echo " ✅ SETUP COMPLETE!"
echo "================================================================="
echo ""
echo "Next Steps to activate GitHub Actions CI:"
echo ""
echo "1. Copy the contents of '${KEY_FILE}':"
echo "   cat ${KEY_FILE}"
echo ""
echo "2. Go to your GitHub Repository:"
echo "   Settings -> Secrets and variables -> Actions -> 'New repository secret'"
echo ""
echo "3. Add Secret:"
echo "   Name:  GCP_SA_KEY"
echo "   Value: <Paste the entire contents of ${KEY_FILE}>"
echo ""
echo "4. (Security best practice) Delete the local key file after copying:"
echo "   rm ${KEY_FILE}"
echo "================================================================="

