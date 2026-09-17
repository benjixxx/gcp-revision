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

