#!/usr/bin/env bash
# ==============================================================================
# Compute Engine Startup Script for Air Quality Application
# Automatically provisions Python, application code, templates, and systemd service.
# ==============================================================================

set -euo pipefail

APP_DIR="/opt/qualityAirApp"
PORT=8080

echo "=== [1/5] Updating packages and installing prerequisites ==="
apt-get update -y
apt-get install -y python3 python3-pip python3-venv curl

echo "=== [2/5] Creating application files at ${APP_DIR} ==="
mkdir -p "${APP_DIR}/templates"
cd "${APP_DIR}"

cat <<'EOF' > "${APP_DIR}/app.py"
import os
import time
import socket
import logging
from datetime import datetime, timezone
import requests
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Application Start Time & Request Counter
START_TIME = time.time()
REQUEST_COUNT = 0

# Target cities for Air Quality tracking
CITIES = [
    {"name": "Paris", "country": "France", "lat": 48.8566, "lon": 2.3522},
    {"name": "London", "country": "United Kingdom", "lat": 51.5074, "lon": -0.1278},
    {"name": "New York", "country": "United States", "lat": 40.7128, "lon": -74.0060},
    {"name": "Tokyo", "country": "Japan", "lat": 35.6762, "lon": 139.6503},
    {"name": "Berlin", "country": "Germany", "lat": 52.5200, "lon": 13.4050},
    {"name": "Madrid", "country": "Spain", "lat": 40.4168, "lon": -3.7038},
    {"name": "Rome", "country": "Italy", "lat": 41.9028, "lon": 12.4964},
]

def get_gcp_metadata(path, timeout=0.4):
    """Query GCP Metadata server (only available inside GCP Compute Engine)."""
    url = f"http://metadata.google.internal/computeMetadata/v1/{path}"
    headers = {"Metadata-Flavor": "Google"}
    try:
        res = requests.get(url, headers=headers, timeout=timeout)
        if res.status_code == 200:
            return res.text
    except Exception:
        pass
    return None

def get_instance_info():
    """Retrieve instance identity and deployment metadata."""
    hostname = socket.gethostname()
    instance_name = get_gcp_metadata("instance/name") or hostname
    zone_raw = get_gcp_metadata("instance/zone")
    zone = zone_raw.split("/")[-1] if zone_raw else "local / non-GCP"
    machine_type_raw = get_gcp_metadata("instance/machine-type")
    machine_type = machine_type_raw.split("/")[-1] if machine_type_raw else "local"
    
    # Try resolving internal IP
    try:
        internal_ip = socket.gethostbyname(hostname)
    except Exception:
        internal_ip = "127.0.0.1"

    return {
        "hostname": hostname,
        "instance_name": instance_name,
        "zone": zone,
        "machine_type": machine_type,
        "internal_ip": internal_ip,
        "uptime_seconds": int(time.time() - START_TIME)
    }

def get_system_metrics():
    """Read Linux system load and memory info without heavy dependencies."""
    load_avg = [0.0, 0.0, 0.0]
    mem_used_pct = 0.0
    
    # Read Load Avg
    try:
        if hasattr(os, "getloadavg"):
            load_avg = [round(x, 2) for x in os.getloadavg()]
    except Exception:
        pass

    # Read Memory on Linux
    try:
        if os.path.exists("/proc/meminfo"):
            meminfo = {}
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        meminfo[parts[0].strip()] = int(parts[1].strip().split()[0])
            total = meminfo.get("MemTotal", 0)
            avail = meminfo.get("MemAvailable", meminfo.get("MemFree", 0))
            if total > 0:
                mem_used_pct = round(((total - avail) / total) * 100, 1)
    except Exception:
        pass

    return {
        "load_avg_1m": load_avg[0],
        "load_avg_5m": load_avg[1],
        "load_avg_15m": load_avg[2],
        "memory_used_pct": mem_used_pct
    }

def evaluate_aqi_level(aqi):
    """Categorize European Air Quality Index value."""
    if aqi is None:
        return {"level": "Unknown", "badge_class": "badge-secondary", "description": "Data unavailable"}
    if aqi <= 20:
        return {"level": "Very Good", "badge_class": "badge-success", "description": "Air quality is ideal"}
    elif aqi <= 40:
        return {"level": "Good", "badge_class": "badge-info", "description": "Air quality is satisfactory"}
    elif aqi <= 60:
        return {"level": "Moderate", "badge_class": "badge-warning", "description": "Acceptable air quality"}
    elif aqi <= 80:
        return {"level": "Poor", "badge_class": "badge-orange", "description": "May affect sensitive groups"}
    elif aqi <= 100:
        return {"level": "Very Poor", "badge_class": "badge-danger", "description": "Health alert: general public affected"}
    else:
        return {"level": "Hazardous", "badge_class": "badge-dark", "description": "Emergency warning: entire population affected"}

def fetch_air_quality_data():
    """Fetch live air quality data from Open-Meteo API with timeout and error handling."""
    base_url = "https://air-quality-api.open-meteo.com/v1/air-quality"
    results = []
    egress_success = True
    error_message = None
    t0 = time.time()

    for city in CITIES:
        params = {
            "latitude": city["lat"],
            "longitude": city["lon"],
            "current": "european_aqi,us_aqi,pm10,pm2_5,nitrogen_dioxide,ozone",
            "timezone": "auto"
        }
        try:
            # 3-second timeout to quickly detect egress failure if Cloud NAT is missing
            resp = requests.get(base_url, params=params, timeout=3.0)
            if resp.status_code == 200:
                data = resp.json()
                current = data.get("current", {})
                aqi = current.get("european_aqi")
                eval_info = evaluate_aqi_level(aqi)

                results.append({
                    "name": city["name"],
                    "country": city["country"],
                    "lat": city["lat"],
                    "lon": city["lon"],
                    "time": current.get("time", "N/A"),
                    "european_aqi": aqi,
                    "us_aqi": current.get("us_aqi", "N/A"),
                    "pm10": current.get("pm10", "N/A"),
                    "pm2_5": current.get("pm2_5", "N/A"),
                    "no2": current.get("nitrogen_dioxide", "N/A"),
                    "ozone": current.get("ozone", "N/A"),
                    "level": eval_info["level"],
                    "badge_class": eval_info["badge_class"],
                    "description": eval_info["description"],
                    "status": "LIVE"
                })
            else:
                egress_success = False
                error_message = f"API responded with HTTP {resp.status_code}"
                results.append(fallback_city_entry(city, "API Error"))
        except requests.exceptions.RequestException as e:
            egress_success = False
            error_message = (
                f"Outbound network request failed: {type(e).__name__}. "
                "Verify Compute Engine egress infrastructure (e.g. Cloud NAT or External IP)."
            )
            results.append(fallback_city_entry(city, "Egress Timeout/Failure"))

    duration_ms = round((time.time() - t0) * 1000, 1)
    return {
        "cities": results,
        "egress_ok": egress_success,
        "error_message": error_message,
        "api_latency_ms": duration_ms,
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    }

def fallback_city_entry(city, reason):
    """Fallback entry returned when outbound API cannot be reached."""
    return {
        "name": city["name"],
        "country": city["country"],
        "lat": city["lat"],
        "lon": city["lon"],
        "time": "N/A",
        "european_aqi": "--",
        "us_aqi": "--",
        "pm10": "--",
        "pm2_5": "--",
        "no2": "--",
        "ozone": "--",
        "level": "Unavailable",
        "badge_class": "badge-secondary",
        "description": reason,
        "status": "FALLBACK"
    }

@app.before_request
def count_requests():
    global REQUEST_COUNT
    # Only count user dashboard requests, skip health checks
    if request.path == "/":
        REQUEST_COUNT += 1

@app.route("/")
def index():
    instance_info = get_instance_info()
    system_metrics = get_system_metrics()
    aqi_data = fetch_air_quality_data()

    # Client networking info from Load Balancer / Proxy
    forwarded_for = request.headers.get("X-Forwarded-For", request.remote_addr)
    user_agent = request.headers.get("User-Agent", "Unknown")

    return render_template(
        "index.html",
        instance=instance_info,
        metrics=system_metrics,
        request_count=REQUEST_COUNT,
        client_ip=forwarded_for,
        user_agent=user_agent,
        aqi_data=aqi_data
    )

@app.route("/health")
@app.route("/healthz")
def health():
    """GCP Load Balancer & GKE Health Check endpoint."""
    instance_info = get_instance_info()
    return jsonify({
        "status": "healthy",
        "service": "qualityAirApp",
        "hostname": instance_info["hostname"],
        "instance_name": instance_info["instance_name"],
        "zone": instance_info["zone"],
        "uptime_seconds": instance_info["uptime_seconds"],
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200

@app.route("/api/air-quality")
def api_air_quality():
    """REST endpoint returning air quality JSON data."""
    data = fetch_air_quality_data()
    return jsonify(data), 200 if data["egress_ok"] else 503

@app.route("/api/info")
def api_info():
    """Diagnostic endpoint returning instance and system metrics."""
    return jsonify({
        "instance": get_instance_info(),
        "metrics": get_system_metrics(),
        "total_requests_served": REQUEST_COUNT,
        "client_ip": request.headers.get("X-Forwarded-For", request.remote_addr),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logging.info(f"Starting qualityAirApp on 0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port)


EOF

cat <<'EOF' > "${APP_DIR}/templates/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Global Air Quality Dashboard | GCP Compute Engine & LB Monitor</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css">
    <style>
        :root {
            --bg-color: #0f172a;
            --card-bg: #1e293b;
            --card-border: #334155;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent-blue: #38bdf8;
            --accent-green: #22c55e;
            --accent-orange: #f97316;
            --accent-red: #ef4444;
        }

        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            min-height: 100vh;
            padding-bottom: 3rem;
        }

        .navbar-custom {
            background-color: #0b1120;
            border-bottom: 1px solid var(--card-border);
        }

        .card-custom {
            background-color: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -2px rgba(0, 0, 0, 0.3);
            transition: transform 0.2s ease, border-color 0.2s ease;
        }

        .card-custom:hover {
            border-color: var(--accent-blue);
            transform: translateY(-2px);
        }

        .badge-success { background-color: #15803d; color: #fff; }
        .badge-info { background-color: #0284c7; color: #fff; }
        .badge-warning { background-color: #d97706; color: #fff; }
        .badge-orange { background-color: #ea580c; color: #fff; }
        .badge-danger { background-color: #dc2626; color: #fff; }
        .badge-dark { background-color: #7f1d1d; color: #fff; }
        .badge-secondary { background-color: #475569; color: #fff; }

        .stat-value {
            font-size: 2rem;
            font-weight: 700;
            letter-spacing: -0.05em;
        }

        .stat-label {
            font-size: 0.825rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
        }

        .metric-pill {
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            padding: 0.5rem 0.75rem;
        }

        .node-highlight {
            background: linear-gradient(135deg, #1e3a8a, #0284c7);
            color: #ffffff;
            border-radius: 8px;
            padding: 0.4rem 0.8rem;
            font-weight: 600;
            font-family: monospace;
            display: inline-block;
        }

        .progress-thin {
            height: 6px;
            background-color: #334155;
        }
    </style>
</head>
<body>

    <!-- Header Navbar -->
    <nav class="navbar navbar-custom navbar-dark py-3 mb-4">
        <div class="container">
            <a class="navbar-brand d-flex align-items-center gap-2" href="/">
                <i class="bi bi-clouds-fill text-info fs-3"></i>
                <div>
                    <span class="fw-bold">AirQuality<span class="text-info">App</span></span>
                    <small class="d-block text-secondary" style="font-size: 0.75rem;">GCP Compute Engine &amp; Load Balancer Target</small>
                </div>
            </a>
            <div class="d-flex align-items-center gap-2">
                <a href="/health" class="btn btn-sm btn-outline-success" target="_blank">
                    <i class="bi bi-heart-pulse-fill me-1"></i>/health
                </a>
                <a href="/api/air-quality" class="btn btn-sm btn-outline-info" target="_blank">
                    <i class="bi bi-code-slash me-1"></i>/api/air-quality
                </a>
                <button class="btn btn-sm btn-primary" onclick="window.location.reload();">
                    <i class="bi bi-arrow-clockwise me-1"></i>Refresh
                </button>
            </div>
        </div>
    </nav>

    <div class="container">

        <!-- Top Row: Load Balancer & Compute Engine Diagnostic Bar -->
        <div class="row g-3 mb-4">
            <!-- Node Identification Card -->
            <div class="col-lg-7">
                <div class="card card-custom p-3 h-100">
                    <div class="d-flex justify-content-between align-items-start mb-2">
                        <span class="stat-label"><i class="bi bi-server me-1"></i>Serving Compute Instance (Load Balancer Node)</span>
                        <span class="badge bg-primary">HTTP 200</span>
                    </div>
                    <div class="d-flex align-items-center gap-3 mb-3 flex-wrap">
                        <span class="node-highlight fs-5">
                            <i class="bi bi-cpu me-1"></i>{{ instance.instance_name }}
                        </span>
                        <span class="badge bg-secondary">Zone: {{ instance.zone }}</span>
                        <span class="badge bg-secondary">IP: {{ instance.internal_ip }}</span>
                        <span class="badge bg-dark border border-secondary">Node Requests: {{ request_count }}</span>
                    </div>
                    <div class="row g-2 text-secondary small pt-2 border-top border-secondary">
                        <div class="col-sm-6">
                            <strong>Client / Proxy IP:</strong> <code>{{ client_ip }}</code>
                        </div>
                        <div class="col-sm-6 text-sm-end">
                            <strong>Node Uptime:</strong> {{ instance.uptime_seconds }}s
                        </div>
                    </div>
                </div>
            </div>

            <!-- Compute Engine Resource Metrics Card -->
            <div class="col-lg-5">
                <div class="card card-custom p-3 h-100">
                    <div class="d-flex justify-content-between align-items-start mb-2">
                        <span class="stat-label"><i class="bi bi-speedometer2 me-1"></i>Compute Engine Telemetry</span>
                        <span class="text-secondary small">{{ instance.machine_type }}</span>
                    </div>
                    <div class="row g-2 mb-2">
                        <div class="col-4">
                            <div class="metric-pill text-center">
                                <small class="text-secondary d-block">Load 1m</small>
                                <span class="fw-bold fs-6">{{ metrics.load_avg_1m }}</span>
                            </div>
                        </div>
                        <div class="col-4">
                            <div class="metric-pill text-center">
                                <small class="text-secondary d-block">Load 5m</small>
                                <span class="fw-bold fs-6">{{ metrics.load_avg_5m }}</span>
                            </div>
                        </div>
                        <div class="col-4">
                            <div class="metric-pill text-center">
                                <small class="text-secondary d-block">Load 15m</small>
                                <span class="fw-bold fs-6">{{ metrics.load_avg_15m }}</span>
                            </div>
                        </div>
                    </div>
                    <div>
                        <div class="d-flex justify-content-between text-secondary small mb-1">
                            <span>RAM Usage</span>
                            <span>{{ metrics.memory_used_pct }}%</span>
                        </div>
                        <div class="progress progress-thin">
                            <div class="progress-bar bg-info" role="progressbar" style="width: {{ metrics.memory_used_pct }}%"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Outbound Network Egress Diagnostics Banner -->
        <div class="row mb-4">
            <div class="col-12">
                {% if aqi_data.egress_ok %}
                <div class="alert alert-success d-flex align-items-center justify-content-between m-0 border-0 bg-opacity-25 bg-success text-white py-2 px-3 rounded-3" role="alert">
                    <div class="d-flex align-items-center gap-2">
                        <i class="bi bi-check-circle-fill text-success fs-5"></i>
                        <div>
                            <strong>Network Egress: CONNECTED</strong> — Outbound API calls to Open-Meteo succeeded (Latency: {{ aqi_data.api_latency_ms }} ms).
                        </div>
                    </div>
                    <small class="text-light opacity-75">Updated: {{ aqi_data.fetched_at }}</small>
                </div>
                {% else %}
                <div class="alert alert-warning border-0 bg-opacity-25 bg-warning text-white py-3 px-3 rounded-3" role="alert">
                    <div class="d-flex align-items-center gap-2 mb-1">
                        <i class="bi bi-exclamation-triangle-fill text-warning fs-5"></i>
                        <strong class="text-warning">Network Egress: BLOCKED OR TIMED OUT</strong>
                    </div>
                    <div class="small text-light">
                        {{ aqi_data.error_message }}
                        <br>
                        <strong>Troubleshooting tip:</strong> If this Compute Engine VM only has a private IP, ensure a <strong>Cloud NAT gateway</strong> and default route (<code>0.0.0.0/0 &rarr; default-internet-gateway</code>) are configured on your VPC.
                    </div>
                </div>
                {% endif %}
            </div>
        </div>

        <!-- Main Title & Instructions -->
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h4 class="m-0 fw-bold"><i class="bi bi-globe-europe-africa text-info me-2"></i>Global Air Quality Overview</h4>
            <div class="text-secondary small">
                Source: <a href="https://open-meteo.com/" target="_blank" class="text-decoration-none text-info">Open-Meteo Air Quality API</a> (No API key required)
            </div>
        </div>

        <!-- City Cards Grid -->
        <div class="row g-3 mb-4">
            {% for city in aqi_data.cities %}
            <div class="col-md-6 col-lg-4">
                <div class="card card-custom h-100 p-3">
                    <div class="d-flex justify-content-between align-items-start mb-2">
                        <div>
                            <h5 class="fw-bold mb-0">{{ city.name }}</h5>
                            <small class="text-secondary">{{ city.country }}</small>
                        </div>
                        <span class="badge {{ city.badge_class }} py-2 px-2">{{ city.level }}</span>
                    </div>

                    <div class="d-flex align-items-baseline gap-2 my-2">
                        <div class="stat-value text-white">{{ city.european_aqi }}</div>
                        <div class="stat-label">European AQI</div>
                        {% if city.status == 'FALLBACK' %}
                        <span class="badge bg-danger ms-auto" style="font-size: 0.65rem;">NO EGRESS</span>
                        {% else %}
                        <span class="badge bg-success ms-auto" style="font-size: 0.65rem;">LIVE</span>
                        {% endif %}
                    </div>

                    <p class="text-secondary small mb-3">{{ city.description }}</p>

                    <!-- Pollutants Grid -->
                    <div class="row g-2 pt-2 border-top border-secondary small">
                        <div class="col-6">
                            <span class="text-secondary">PM2.5:</span> <strong>{{ city.pm2_5 }}</strong> <span class="text-secondary">μg/m³</span>
                        </div>
                        <div class="col-6">
                            <span class="text-secondary">PM10:</span> <strong>{{ city.pm10 }}</strong> <span class="text-secondary">μg/m³</span>
                        </div>
                        <div class="col-6">
                            <span class="text-secondary">NO₂:</span> <strong>{{ city.no2 }}</strong> <span class="text-secondary">μg/m³</span>
                        </div>
                        <div class="col-6">
                            <span class="text-secondary">O₃:</span> <strong>{{ city.ozone }}</strong> <span class="text-secondary">μg/m³</span>
                        </div>
                    </div>
                </div>
            </div>
            {% endfor %}
        </div>

        <!-- Load Balancer Testing Help Card -->
        <div class="card card-custom p-4 mt-4">
            <h5 class="fw-bold text-info"><i class="bi bi-lightbulb me-2"></i>Infrastructure Testing Checklist</h5>
            <div class="row g-3 mt-1">
                <div class="col-md-4">
                    <div class="p-3 rounded-2 bg-dark border border-secondary h-100">
                        <strong class="text-white d-block mb-1">1. Outbound Egress / Cloud NAT</strong>
                        <p class="text-secondary small m-0">
                            When VMs run without public external IPs, they require <strong>Cloud NAT</strong> to reach the external Open-Meteo API. Watch the green/yellow banner above to verify egress connectivity.
                        </p>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="p-3 rounded-2 bg-dark border border-secondary h-100">
                        <strong class="text-white d-block mb-1">2. Load Balancer Distribution</strong>
                        <p class="text-secondary small m-0">
                            Deploy this app across a Managed Instance Group (MIG). Refresh the page through the Load Balancer IP to observe the <strong>Serving Instance</strong> hostname switch between VM instances.
                        </p>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="p-3 rounded-2 bg-dark border border-secondary h-100">
                        <strong class="text-white d-block mb-1">3. Health Checks & Monitoring</strong>
                        <p class="text-secondary small m-0">
                            Configure your Load Balancer Health Check on <strong>HTTP /health</strong> on port <strong>8080</strong> (or 80). Monitor uptime and system load telemetry.
                        </p>
                    </div>
                </div>
            </div>
        </div>

    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>


EOF

cat <<'EOF' > "${APP_DIR}/requirements.txt"
flask>=3.0.0
requests>=2.31.0
gunicorn>=21.2.0
EOF

# Set up virtual environment
if [ ! -d "${APP_DIR}/venv" ]; then
    python3 -m venv "${APP_DIR}/venv"
fi

source "${APP_DIR}/venv/bin/activate"
pip install --upgrade pip
pip install -r "${APP_DIR}/requirements.txt"

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
