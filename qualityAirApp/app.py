import os
import sys
import json
import socket
import time
import logging
import threading
from datetime import datetime, timezone
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

POD_NAME = socket.gethostname()

def load_app_version():
    """Retrieve app version from env var, VERSION file, or fallback to 1.0.0."""
    env_ver = os.environ.get("APP_VERSION")
    if env_ver:
        return env_ver.strip()
    version_file = os.path.join(os.path.dirname(__file__), "VERSION")
    if os.path.exists(version_file):
        try:
            with open(version_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return "1.0.0"

APP_VERSION = load_app_version()

# Persistent HTTP session with connection pooling and retries
http_session = requests.Session()
_retries = Retry(total=2, backoff_factor=0.3, status_forcelist=[500, 502, 503, 504])
http_session.mount("https://", HTTPAdapter(pool_connections=10, pool_maxsize=20, max_retries=_retries))
http_session.mount("http://", HTTPAdapter(pool_connections=10, pool_maxsize=20, max_retries=_retries))

# Thread-safe In-Memory Cache (TTL: 5 minutes for AQI, 1 hour for Geocoding)
CACHE_TTL_SECONDS = 300
_cache_lock = threading.Lock()
_air_quality_cache = {}  # key -> {"data": dict, "timestamp": float}
_geocode_cache = {}      # key -> {"data": dict, "timestamp": float}

@app.before_request
def record_start_time():
    request._start_time = time.perf_counter()

@app.after_request
def log_json_request(response):
    """Output structured JSON log entries formatted for GCP Cloud Logging and kubectl."""
    start_time = getattr(request, "_start_time", None)
    if start_time is not None:
        duration_sec = time.perf_counter() - start_time
        duration_ms = round(duration_sec * 1000.0, 2)
    else:
        duration_sec = 0.0
        duration_ms = 0.0

    # Extract client IP (respecting GCP Load Balancer X-Forwarded-For header)
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        client_ip = forwarded_for.split(",")[0].strip()
    else:
        client_ip = request.remote_addr or "127.0.0.1"

    status_code = response.status_code
    severity = "INFO"
    if status_code >= 500:
        severity = "ERROR"
    elif status_code >= 400:
        severity = "WARNING"

    try:
        response_size = response.calculate_content_length() or len(response.get_data())
    except Exception:
        response_size = 0

    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "severity": severity,
        "message": f"{request.method} {request.full_path.rstrip('?')} - {status_code} ({duration_ms}ms)",
        "httpRequest": {
            "requestMethod": request.method,
            "requestUrl": request.url,
            "requestSize": request.content_length or 0,
            "status": status_code,
            "responseSize": response_size,
            "userAgent": request.headers.get("User-Agent", ""),
            "remoteIp": client_ip,
            "latency": f"{duration_sec:.6f}s",
            "protocol": request.environ.get("SERVER_PROTOCOL", "HTTP/1.1")
        },
        "jsonPayload": {
            "method": request.method,
            "path": request.path,
            "query_string": request.query_string.decode("utf-8", errors="replace"),
            "status_code": status_code,
            "latency_ms": duration_ms,
            "client_ip": client_ip,
            "pod_name": POD_NAME,
            "service": "qualityAirApp"
        }
    }

    # Write single-line JSON directly to stdout
    sys.stdout.write(json.dumps(log_entry) + "\n")
    sys.stdout.flush()

    return response

# Preset featured cities (Nairobi and New York prominently included)
DEFAULT_CITIES = [
    {"name": "Nairobi", "country": "Kenya", "lat": -1.286389, "lon": 36.817223},
    {"name": "New York", "country": "United States", "lat": 40.7128, "lon": -74.0060},
    {"name": "Paris", "country": "France", "lat": 48.8566, "lon": 2.3522},
    {"name": "London", "country": "United Kingdom", "lat": 51.5074, "lon": -0.1278},
    {"name": "Tokyo", "country": "Japan", "lat": 35.6762, "lon": 139.6503},
    {"name": "Berlin", "country": "Germany", "lat": 52.5200, "lon": 13.4050},
    {"name": "Madrid", "country": "Spain", "lat": 40.4168, "lon": -3.7038},
    {"name": "Rome", "country": "Italy", "lat": 41.9028, "lon": 12.4964},
]

# Quick coordinates lookup for instant resolution
CITY_COORDINATES = {
    "nairobi": {"name": "Nairobi", "country": "Kenya", "lat": -1.286389, "lon": 36.817223},
    "new york": {"name": "New York", "country": "United States", "lat": 40.7128, "lon": -74.0060},
    "paris": {"name": "Paris", "country": "France", "lat": 48.8566, "lon": 2.3522},
    "london": {"name": "London", "country": "United Kingdom", "lat": 51.5074, "lon": -0.1278},
    "tokyo": {"name": "Tokyo", "country": "Japan", "lat": 35.6762, "lon": 139.6503},
    "berlin": {"name": "Berlin", "country": "Germany", "lat": 52.5200, "lon": 13.4050},
    "madrid": {"name": "Madrid", "country": "Spain", "lat": 40.4168, "lon": -3.7038},
    "rome": {"name": "Rome", "country": "Italy", "lat": 41.9028, "lon": 12.4964},
    "sydney": {"name": "Sydney", "country": "Australia", "lat": -33.8688, "lon": 151.2093},
    "dakar": {"name": "Dakar", "country": "Senegal", "lat": 14.7167, "lon": -17.4677},
    "cairo": {"name": "Cairo", "country": "Egypt", "lat": 30.0444, "lon": 31.2357},
    "dubai": {"name": "Dubai", "country": "United Arab Emirates", "lat": 25.2048, "lon": 55.2708},
    "beijing": {"name": "Beijing", "country": "China", "lat": 39.9042, "lon": 116.4074},
    "mumbai": {"name": "Mumbai", "country": "India", "lat": 19.0760, "lon": 72.8777},
    "sao paulo": {"name": "São Paulo", "country": "Brazil", "lat": -23.5505, "lon": -46.6333},
    "los angeles": {"name": "Los Angeles", "country": "United States", "lat": 34.0522, "lon": -118.2437},
    "toronto": {"name": "Toronto", "country": "Canada", "lat": 43.6532, "lon": -79.3832},
    "johannesburg": {"name": "Johannesburg", "country": "South Africa", "lat": -26.2041, "lon": 28.0473},
}

def evaluate_aqi_level(aqi):
    """Categorize European Air Quality Index value with high-contrast badge classes."""
    if aqi is None:
        return {
            "level": "Unknown",
            "badge_class": "badge-unknown",
            "color": "#94a3b8",
            "description": "Live air quality data currently unavailable"
        }
    if aqi <= 20:
        return {
            "level": "Very Good",
            "badge_class": "badge-very-good",
            "color": "#22c55e",
            "description": "Air quality is ideal for outdoor activities"
        }
    elif aqi <= 40:
        return {
            "level": "Good",
            "badge_class": "badge-good",
            "color": "#38bdf8",
            "description": "Air quality is satisfactory and poses little risk"
        }
    elif aqi <= 60:
        return {
            "level": "Moderate",
            "badge_class": "badge-moderate",
            "color": "#eab308",
            "description": "Acceptable quality; sensitive individuals should take care"
        }
    elif aqi <= 80:
        return {
            "level": "Poor",
            "badge_class": "badge-poor",
            "color": "#f97316",
            "description": "May cause breathing discomfort for sensitive groups"
        }
    elif aqi <= 100:
        return {
            "level": "Very Poor",
            "badge_class": "badge-very-poor",
            "color": "#ef4444",
            "description": "Health alert: members of the general public may be affected"
        }
    else:
        return {
            "level": "Hazardous",
            "badge_class": "badge-hazardous",
            "color": "#a855f7",
            "description": "Emergency warning: serious health risk for all populations"
        }

def get_city_air_quality(city):
    """Fetch live air quality for a single city object {name, country, lat, lon} with caching and resilient fallback."""
    cache_key = f"{round(city['lat'], 3)},{round(city['lon'], 3)}"
    now = time.time()

    # 1. Check in-memory TTL cache (valid for 5 minutes)
    with _cache_lock:
        cached_entry = _air_quality_cache.get(cache_key)
        if cached_entry and (now - cached_entry["timestamp"]) < CACHE_TTL_SECONDS:
            data = cached_entry["data"].copy()
            data["status"] = "CACHED"
            return data

    base_url = "https://air-quality-api.open-meteo.com/v1/air-quality"
    params = {
        "latitude": city["lat"],
        "longitude": city["lon"],
        "current": "european_aqi,us_aqi,pm10,pm2_5,nitrogen_dioxide,ozone",
        "timezone": "auto"
    }

    try:
        # Relaxed timeout: 3.5s connect, 8.0s read (handles Open-Meteo latency without dropping)
        resp = http_session.get(base_url, params=params, timeout=(3.5, 8.0))
        if resp.status_code == 200:
            data = resp.json()
            current = data.get("current", {})
            aqi = current.get("european_aqi")
            eval_info = evaluate_aqi_level(aqi)

            result = {
                "name": city["name"],
                "country": city.get("country", ""),
                "lat": city["lat"],
                "lon": city["lon"],
                "time": current.get("time", "Now"),
                "european_aqi": aqi if aqi is not None else "--",
                "us_aqi": current.get("us_aqi", "--"),
                "pm10": current.get("pm10", "--"),
                "pm2_5": current.get("pm2_5", "--"),
                "no2": current.get("nitrogen_dioxide", "--"),
                "ozone": current.get("ozone", "--"),
                "level": eval_info["level"],
                "badge_class": eval_info["badge_class"],
                "color": eval_info["color"],
                "description": eval_info["description"],
                "status": "LIVE"
            }

            # Store in cache
            with _cache_lock:
                _air_quality_cache[cache_key] = {"data": result, "timestamp": now}

            return result
        else:
            logging.warning(f"Open-Meteo returned HTTP {resp.status_code} for {city['name']}: {resp.text[:120]}")
    except Exception as e:
        logging.warning(f"Failed to fetch AQI for {city['name']}: {e}")

    # 2. Resilient Stale-While-Revalidate: Return last known cached data if API is down
    with _cache_lock:
        stale_entry = _air_quality_cache.get(cache_key)
        if stale_entry:
            data = stale_entry["data"].copy()
            age_min = round((now - stale_entry["timestamp"]) / 60, 1)
            data["status"] = "STALE"
            data["description"] = f"Using cached metrics ({age_min}m ago) while provider recovers"
            return data

    # 3. Final Fallback if API is unreachable and no previous cache exists
    return {
        "name": city["name"],
        "country": city.get("country", ""),
        "lat": city["lat"],
        "lon": city["lon"],
        "time": "Now",
        "european_aqi": "--",
        "us_aqi": "--",
        "pm10": "--",
        "pm2_5": "--",
        "no2": "--",
        "ozone": "--",
        "level": "Unavailable",
        "badge_class": "badge-unknown",
        "color": "#94a3b8",
        "description": "Unable to connect to air quality provider",
        "status": "FALLBACK"
    }

def geocode_city(city_name):
    """Resolve any city name to coordinates via built-in dictionary, cache, or Open-Meteo Geocoding API."""
    key = city_name.strip().lower()
    if key in CITY_COORDINATES:
        return CITY_COORDINATES[key]

    now = time.time()
    # Check geocode cache (valid for 1 hour)
    with _cache_lock:
        cached_geo = _geocode_cache.get(key)
        if cached_geo and (now - cached_geo["timestamp"]) < 3600:
            return cached_geo["data"]

    url = "https://geocoding-api.open-meteo.com/v1/search"
    params = {"name": city_name, "count": 1, "language": "en", "format": "json"}
    try:
        res = http_session.get(url, params=params, timeout=(3.5, 6.0))
        if res.status_code == 200:
            data = res.json()
            results = data.get("results")
            if results and len(results) > 0:
                first = results[0]
                result = {
                    "name": first.get("name", city_name.capitalize()),
                    "country": first.get("country", ""),
                    "lat": first.get("latitude"),
                    "lon": first.get("longitude")
                }
                with _cache_lock:
                    _geocode_cache[key] = {"data": result, "timestamp": now}
                return result
        else:
            logging.warning(f"Geocoding API returned HTTP {res.status_code} for '{city_name}': {res.text[:120]}")
    except Exception as e:
        logging.error(f"Geocoding error for '{city_name}': {e}")

    # Fallback to stale geocode if present
    with _cache_lock:
        stale_geo = _geocode_cache.get(key)
        if stale_geo:
            return stale_geo["data"]

    return None

def fetch_all_default_cities():
    """Fetch live data for the default featured cities."""
    results = []
    for city in DEFAULT_CITIES:
        results.append(get_city_air_quality(city))
    return results

@app.route("/")
def index():
    """Main clean dashboard page."""
    cities_data = fetch_all_default_cities()
    last_updated = datetime.now(timezone.utc).strftime("%H:%M:%S UTC")
    return render_template(
        "index.html",
        cities=cities_data,
        last_updated=last_updated,
        version=APP_VERSION
    )

@app.route("/api/city")
def api_city():
    """Search for any city dynamically (e.g., /api/city?name=nairobi)."""
    city_name = request.args.get("name", "").strip()
    if not city_name:
        return jsonify({"error": "Missing 'name' query parameter"}), 400

    city_obj = geocode_city(city_name)
    if not city_obj:
        return jsonify({"error": f"City '{city_name}' could not be located"}), 404

    city_data = get_city_air_quality(city_obj)
    return jsonify(city_data), 200

@app.route("/api/air-quality")
def api_air_quality():
    """REST endpoint returning full JSON air quality data for featured cities."""
    cities_data = fetch_all_default_cities()
    return jsonify({
        "version": APP_VERSION,
        "cities": cities_data,
        "fetched_at": datetime.now(timezone.utc).isoformat()
    }), 200

@app.route("/health")
@app.route("/healthz")
def health():
    """Load Balancer Health Check endpoint (always HTTP 200)."""
    return jsonify({
        "status": "healthy",
        "service": "qualityAirApp",
        "version": APP_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logging.info(f"Starting QualityAirApp on 0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port)
