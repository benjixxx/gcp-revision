#!/usr/bin/env bash
# ==============================================================================
# Compute Engine Startup Script for Air Quality Application
# Usage:
#   Pass as metadata startup-script in Compute Engine Instance / Instance Template:
#   gcloud compute instances create my-instance \
#       --metadata-from-file=startup-script=startup-script.sh
# ==============================================================================

set -euo pipefail

APP_DIR="/opt/qualityAirApp"
PORT=8080

echo "=== [1/5] Updating packages and installing prerequisites ==="
apt-get update -y
apt-get install -y python3 python3-pip python3-venv git curl

echo "=== [2/5] Setting up application directory at ${APP_DIR} ==="
mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

# If repo is not cloned, create virtualenv and install requirements
if [ ! -d "${APP_DIR}/venv" ]; then
    python3 -m venv "${APP_DIR}/venv"
fi

# Activate virtualenv
source "${APP_DIR}/venv/bin/activate"

# If requirements.txt exists locally, install it
if [ -f "${APP_DIR}/requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r "${APP_DIR}/requirements.txt"
else
    pip install --upgrade pip
    pip install "flask>=3.0.0" "requests>=2.31.0" "gunicorn>=21.2.0"
fi

echo "=== [3/5] Creating Systemd Service ==="
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

echo "=== [4/5] Reloading Systemd and Starting Service ==="
systemctl daemon-reload
systemctl enable quality-air-app.service
systemctl restart quality-air-app.service

echo "=== [5/5] Checking service status ==="
sleep 2
systemctl status quality-air-app.service --no-pager

echo "=== Application deployment complete! Accessible on port ${PORT} ==="

