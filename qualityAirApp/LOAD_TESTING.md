# QualityAirApp - Request Execution & Load Testing Guide

This guide details how to query, test, and inject high-concurrency traffic into `QualityAirApp` without hardcoding any IP addresses.

---

## 📌 1. Resolving the Target URL Dynamically

Never hardcode IP addresses in your scripts or test commands. Depending on where your application is running, choose one of the options below:

### Option A: GCP Load Balancer (Terraform output)
From the repository root (or within `qualityAirApp` using `-chdir=..`):
```bash
# Retrieve the external HTTP Load Balancer IP automatically
export TARGET_URL="http://$(terraform -chdir=.. output -raw lb_ip_address)"
echo "Target URL: $TARGET_URL"
```

### Option B: Google Cloud CLI (`gcloud`)
If you deployed outside Terraform or want to fetch the forwarding rule IP directly:
```bash
export TARGET_URL="http://$(gcloud compute forwarding-rules list --filter="name ~ quality-air" --format="value(IPAddress)" | head -n1)"
echo "Target URL: $TARGET_URL"
```

### Option C: Manual Variable (GCP Load Balancer or VM)
If you know your Load Balancer or VM external IP:
```bash
export TARGET_URL="http://<YOUR_LOAD_BALANCER_OR_VM_IP>"
```

### Option D: Local Development Server
When running `python app.py` or Docker locally on port `8080`:
```bash
export TARGET_URL="http://localhost:8080"
```

---

## 🎯 2. Available Endpoints Overview

| Endpoint | HTTP Method | Expected Status | Description & Use Case |
| :--- | :--- | :--- | :--- |
| `/health` | `GET` | `200 OK` | Ultra-fast JSON health probe (`{"status":"healthy"}`). Ideal for stress-testing server throughput and autoscaling. |
| `/healthz` | `GET` | `200 OK` | Kubernetes / container probe alias for `/health`. |
| `/api/city?name=<city>` | `GET` | `200 OK` / `404` | Dynamic geocoding & live weather/AQI lookup. Cached for major cities. |
| `/api/air-quality` | `GET` | `200 OK` | JSON payload containing all default featured cities. |
| `/` | `GET` | `200 OK` | Full HTML dashboard rendering air quality cards and infrastructure indicators. |

---

## 🔍 3. Sending Single Requests with `curl`

Verify connectivity and inspect HTTP headers:

### Health Check Probe
```bash
curl -i "${TARGET_URL}/health"
```
*Expected output:* `HTTP/1.1 200 OK` with JSON `{"service":"qualityAirApp","status":"healthy"}`.

### Dynamic City Search
```bash
# Search for Paris
curl -s "${TARGET_URL}/api/city?name=Paris" | jq .

# Search for Nairobi
curl -s "${TARGET_URL}/api/city?name=Nairobi" | jq .

# Search for New York
curl -s "${TARGET_URL}/api/city?name=New+York" | jq .
```

### Full Featured Cities API
```bash
curl -s "${TARGET_URL}/api/air-quality" | jq .
```

### Main HTML Dashboard & Server Headers
```bash
# Check HTTP status, Content-Type, and server headers
curl -I "${TARGET_URL}/"
```

---

## ⚡ 4. High-Concurrency Traffic Injection (`load_generator.py`)

The included Python load generator [`load_generator.py`](file:///Users/benjixxx/gcp-revision/qualityAirApp/load_generator.py) requires **zero external dependencies** and provides live terminal metrics (RPS, status code counters, and latency percentiles).

Navigate to the `qualityAirApp` directory:
```bash
cd qualityAirApp
```

### Scenario 1: Quick Sanity Test (10 Workers, 30 Seconds)
Simulates realistic user traffic (mixed distribution across `/`, `/health`, and `/api/city`):
```bash
python3 load_generator.py -u "$TARGET_URL" -c 10 -d 30
```

### Scenario 2: High-RPS CPU Stress Test (Trigger MIG Autoscaling)
Directs 100% of traffic to the lightweight `/health` probe. Generates maximum RPS and VM CPU utilization without triggering external API rate limits:
```bash
python3 load_generator.py -u "$TARGET_URL" -c 30 -d 120 --mode stress-fast
```

### Scenario 3: Heavy City Search Traffic
Simulates users actively querying random international cities:
```bash
python3 load_generator.py -u "$TARGET_URL" -c 15 -d 60 --mode cities
```

### Scenario 4: Indefinite Background Load
Runs continuously until you press `Ctrl+C`:
```bash
python3 load_generator.py -u "$TARGET_URL" -c 20 -d 0
```

---

## 📊 5. Lightweight Bash One-Liners (No Python)

If you need a quick bash loop directly from terminal:

### Simple Sequential Traffic Loop
```bash
while true; do
  curl -s -o /dev/null -w "HTTP %{http_code} | Latency: %{time_total}s\n" "${TARGET_URL}/health"
  sleep 0.1
done
```

### Parallel Background Curl Loop (10 Concurrent Streams)
```bash
for i in {1..10}; do
  (
    while true; do
      curl -s -o /dev/null "${TARGET_URL}/health"
    done
  ) &
done

# Stop all background curl jobs when done:
# kill $(jobs -p)
```

---

## 📈 6. Observing Infrastructure Under Load

When generating load against your GCP deployment, observe the real-time reaction across the stack:

1. **Compute Engine MIG Autoscaling**:
   ```bash
   # Watch active VM instance count in the MIG
   watch -n 2 'gcloud compute instance-groups managed list-instances <MIG_NAME> --region=europe-west1'
   ```
2. **Backend Service Health & Traffic**:
   - In GCP Console, navigate to **Network services > Load balancing**.
   - Click on your HTTP Load Balancer backend service.
   - Inspect the **Monitoring** tab to view live request counts, frontend latency, and backend distribution.
3. **VM CPU Utilization**:
   - Navigate to **Monitoring > Dashboards** or **Compute Engine > VM instances**.
   - Look at the CPU utilization curve climbing past the autoscaler target (e.g., 60%), causing new instances to spawn automatically.
