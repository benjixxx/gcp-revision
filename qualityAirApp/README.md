# Quality Air Application (qualityAirApp)

A lightweight, resilient Python Flask application designed specifically to test and validate Google Cloud Platform infrastructure:
1. **Network Egress / Cloud NAT Validation:** Calls the external [Open-Meteo Air Quality API](https://open-meteo.com/) (no API key required) to verify outbound internet connectivity from private Compute Engine instances.
2. **HTTP(S) Load Balancer & Managed Instance Groups (MIG):** Prominently displays the serving instance hostname, zone, and request counts to visually confirm traffic distribution. Includes an HTTP health check endpoint for GCP Backend Services.
3. **Compute Engine Telemetry & Monitoring:** Displays instance identity, load averages (1m, 5m, 15m), and memory usage.

---

## 🚀 Application Endpoints

| Endpoint | Method | Purpose | Typical GCP Usage |
| :--- | :--- | :--- | :--- |
| `/` | `GET` | HTML Air Quality & Infrastructure Dashboard | Visual testing of Load Balancing and Egress status |
| `/health` | `GET` | JSON health probe (`{"status": "healthy", ...}`) | GCP Load Balancer Health Check & Autoscaling probes |
| `/healthz` | `GET` | JSON health probe (Kubernetes standard alias) | GKE / Container health checks |
| `/api/air-quality` | `GET` | Returns real-time JSON air quality data for all cities | Automated testing & programmatic checks |
| `/api/info` | `GET` | Returns instance metadata, IP, and system metrics | Telemetry & instance diagnostics |

---

## 💻 Local Quickstart

### 1. Set Up Virtual Environment & Dependencies
```bash
cd qualityAirApp
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Run Locally
```bash
python app.py
```
By default, the server listens on `http://0.0.0.0:8080`. You can override the port using the `PORT` environment variable:
```bash
PORT=5000 python app.py
```

### 3. Run with Production WSGI Server (Gunicorn)
```bash
gunicorn --workers 3 --bind 0.0.0.0:8080 app:app
```

---

## ☁️ Google Cloud Infrastructure Testing Guide

### 1. Testing Cloud NAT / Outbound Egress
* **Scenario:** Your Compute Engine instances reside in a private subnet without public external IPs.
* **Observation:**
  * **Without Cloud NAT:** The web dashboard displays a yellow/red warning: `Network Egress: BLOCKED OR TIMED OUT`. The app will not crash and serves fallback city placeholders.
  * **With Cloud NAT:** The web dashboard turns green: `Network Egress: CONNECTED` with measured API latency in milliseconds.

### 2. Testing HTTP(S) Load Balancer
* **Scenario:** Multiple instances running in a Managed Instance Group behind an External or Internal HTTP(S) Load Balancer.
* **Observation:**
  * In your GCP Load Balancer backend service configuration:
    * **Protocol:** `HTTP`
    * **Port:** `8080` (or `80` if forwarded)
    * **Health Check Request Path:** `/health`
  * When opening the Load Balancer IP in your browser, hit **Refresh** (`Cmd+R` / `F5`).
  * The **Serving Compute Instance** badge in the header will switch to display the hostname of whichever VM answered the request (`my-mig-instance-1`, `my-mig-instance-2`, etc.), proving round-robin or least-connections distribution.
  * The **Client / Proxy IP** box will display the Load Balancer IP and client IP via the `X-Forwarded-For` header.

### 3. Compute Engine Deployment via Startup Script
You can supply `startup-script.sh` when launching VMs or defining an Instance Template:
```bash
gcloud compute instances create air-quality-vm \
    --zone=europe-west9-a \
    --machine-type=e2-micro \
    --tags=http-server,allow-health-check \
    --metadata-from-file=startup-script=startup-script.sh
```

Ensure your VPC firewall rules allow ingress traffic on TCP port `8080` (especially from Google Cloud Health Check IP ranges `35.191.0.0/16` and `130.211.0.0/22`).

---

## 🐳 Docker Deployment (Optional)

Build and run locally or in Container-Optimized OS:
```bash
docker build -t quality-air-app .
docker run -p 8080:8080 quality-air-app
```

