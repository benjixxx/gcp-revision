#!/usr/bin/env bash
# ==============================================================================
# Compute Engine Startup Script for Air Quality Application
# Pulls application code from Google Cloud Storage and runs via Gunicorn & systemd
# ==============================================================================

set -euo pipefail

APP_DIR="/opt/qualityAirApp"
PORT=8080

# 1. Determine Bucket Name (from GCP metadata or fallback)
METADATA_BUCKET=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/bucket_name" 2>/dev/null || true)
BUCKET_NAME="${METADATA_BUCKET:-myproject-329912-app-storage}"

echo "=== [1/4] Installing Python prerequisites ==="
apt-get update -y
apt-get install -y python3 python3-pip python3-venv curl

echo "=== [2/4] Downloading application from Cloud Storage (gs://${BUCKET_NAME}/qualityAirApp) ==="
mkdir -p "${APP_DIR}"
gcloud storage cp --recursive "gs://${BUCKET_NAME}/qualityAirApp/*" "${APP_DIR}/" || \
gsutil -m cp -r "gs://${BUCKET_NAME}/qualityAirApp/*" "${APP_DIR}/"

echo "=== [3/4] Setting up Python virtual environment and dependencies ==="
cd "${APP_DIR}"
if [ ! -d "${APP_DIR}/venv" ]; then
    python3 -m venv "${APP_DIR}/venv"
fi

source "${APP_DIR}/venv/bin/activate"
pip install --upgrade pip
pip install -r "${APP_DIR}/requirements.txt"

echo "=== [4/4] Creating Systemd Service and Starting Application ==="
cat <<EOF > /etc/systemd/system/quality-air-app.service
[Unit]
Description=Air Quality Monitoring Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=${APP_DIR}
Environment="PORT=${PORT}"
ExecStart=${APP_DIR}/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:${PORT} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable quality-air-app.service
systemctl restart quality-air-app.service

echo "=== Application deployment complete! Listening on port ${PORT} ==="
