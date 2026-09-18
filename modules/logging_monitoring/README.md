# Cloud Logging & BigQuery SRE Observability Module

This module automates the streaming of GKE container logs into **Google BigQuery**, enabling real-time SRE analytics, SQL queries, and visual dashboards with **zero third-party dependencies**.

---

## 🏛️ Architecture

```
  [ GKE quality-air-app Pods ]
   (Emits structured JSON logs to stdout)
               │
               ▼
     [ Cloud Logging Router ]
               │
               ▼  Log Sink Filter:
                  resource.type="k8s_container"
                  AND resource.labels.namespace_name="quality-air"
               │
               ▼  Real-Time Streaming (Partitioned by Day)
    [ BigQuery Dataset: `k8s_logs` ]
   ┌────────────────────────────────────────────────────────┐
   │ • Partitioned Tables: `stdout` (JSON) & `stderr` (text)│
   │ • Native JSON Columns: status_code, latency_ms, etc.   │
   │ • Partitioned by `timestamp` column                    │
   │ • Fast Standard SQL Queries                            │
   │ • 1-Click Looker Studio Visual Dashboards              │
   └────────────────────────────────────────────────────────┘
```

---

## 🎯 GCP Certification Key Concepts (ACE / PCA / DevOps)

| Topic | Exam Requirement & Rule |
| :--- | :--- |
| **Log Router & Sinks** | Sinks filter logs at ingestion and stream them to external destinations (BigQuery, Cloud Storage, Pub/Sub). |
| **Unique Writer Identity** | Every sink generates a unique Google service account (`serviceAccount:service-...@gcp-sa-logging.iam.gserviceaccount.com`). |
| **The IAM Sink SA Trap** | **You must grant `roles/bigquery.dataEditor`** to the sink's writer identity on the destination dataset, otherwise export silently fails! |
| **Table Partitioning** | Setting `use_partitioned_tables = true` creates daily partitioned tables (`stdout`, `stderr`) partitioned on the log's **`timestamp`** column, avoiding legacy date-sharded tables (`stdout_YYYYMMDD`). |
| **Cost Optimization** | Querying with `WHERE DATE(timestamp) = CURRENT_DATE()` prunes partitions and limits data scanned, keeping query costs at near \$0. |

---

## 🚀 Quickstart: Setup & Deployment

### Option A: Via Terraform (Recommended)

Include the module in your root `main.tf`:

```terraform
module "logging_monitoring" {
  source = "./modules/logging_monitoring"

  project_id = var.project_id
  location   = "EU"
  dataset_id = "k8s_logs"
  sink_name  = "k8s-to-bigquery"
  log_filter = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"quality-air\""
}
```

Apply with:
```bash
terraform apply -target=module.logging_monitoring
```

---

### Option B: Via `gcloud` CLI (Manual Setup)

```bash
# 1. Create BigQuery Dataset in EU
bq --location=EU mk --dataset myproject-329912:k8s_logs

# 2. Create the Partitioned Log Sink
gcloud logging sinks create k8s-to-bigquery \
  bigquery.googleapis.com/projects/myproject-329912/datasets/k8s_logs \
  --log-filter='resource.type="k8s_container" AND resource.labels.namespace_name="quality-air"' \
  --use-partitioned-tables \
  --project=myproject-329912

# 3. Grant BigQuery Data Editor to the Sink SA
export SINK_SA=$(gcloud logging sinks describe k8s-to-bigquery --project=myproject-329912 --format="value(writerIdentity)")

gcloud projects add-iam-policy-binding myproject-329912 \
  --member="${SINK_SA}" \
  --role="roles/bigquery.dataEditor"
```

---

## ⚡ Generating Traffic for Testing

Inject traffic into your GKE pods using the built-in load generator:

```bash
# Fetch Load Balancer IP dynamically
export GKE_IP=$(kubectl get svc quality-air-service -n quality-air -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Launch 30 seconds of concurrent traffic
python3 qualityAirApp/load_generator.py -u "http://${GKE_IP}" -c 15 -d 30
```

---

## 📊 SRE SQL Queries (Run in BigQuery Studio)

Cloud Logging automatically splits container streams into two partitioned tables:
- **`stdout`**: Contains structured JSON request logs (`jsonPayload`) from our application.
- **`stderr`**: Contains system messages, uncaught exceptions, and stack traces (`textPayload`).

> [!NOTE]
> All tables use the native **`timestamp`** column for partitioning (instead of `_PARTITIONTIME`).
> You can replace `DATE(timestamp) = CURRENT_DATE()` with `timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)` to query the last 2 hours.

---

### 1. Traffic Breakdown & Status Codes (`stdout`)
See request counts, HTTP response statuses, and average latencies:
```sql
SELECT
  STRING(jsonPayload.method) AS method,
  STRING(jsonPayload.path) AS endpoint,
  CAST(jsonPayload.status_code AS INT64) AS status_code,
  COUNT(*) AS total_requests,
  ROUND(AVG(CAST(jsonPayload.latency_ms AS FLOAT64)), 2) AS avg_latency_ms
FROM
  `myproject-329912.k8s_logs.stdout`
WHERE
  DATE(timestamp) = CURRENT_DATE()
GROUP BY
  1, 2, 3
ORDER BY
  total_requests DESC;
```

---

### 2. Pod Load Balancing Distribution (`stdout`)
Verify that traffic is evenly distributed across your pods:
```sql
SELECT
  STRING(jsonPayload.pod_name) AS pod_name,
  COUNT(*) AS requests_handled,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS traffic_percentage,
  ROUND(AVG(CAST(jsonPayload.latency_ms AS FLOAT64)), 2) AS avg_pod_latency_ms
FROM
  `myproject-329912.k8s_logs.stdout`
WHERE
  DATE(timestamp) = CURRENT_DATE()
GROUP BY
  1
ORDER BY
  requests_handled DESC;
```

---

### 3. Latency Percentiles (p50, p90, p99, Max) (`stdout`)
Detect slow queries and tail-latency degradation:
```sql
SELECT
  STRING(jsonPayload.path) AS endpoint,
  COUNT(*) AS request_count,
  ROUND(AVG(CAST(jsonPayload.latency_ms AS FLOAT64)), 2) AS avg_ms,
  ROUND(APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS FLOAT64), 100)[OFFSET(50)], 2) AS p50_median_ms,
  ROUND(APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS FLOAT64), 100)[OFFSET(90)], 2) AS p90_ms,
  ROUND(APPROX_QUANTILES(CAST(jsonPayload.latency_ms AS FLOAT64), 100)[OFFSET(99)], 2) AS p99_ms,
  ROUND(MAX(CAST(jsonPayload.latency_ms AS FLOAT64)), 2) AS max_ms
FROM
  `myproject-329912.k8s_logs.stdout`
WHERE
  DATE(timestamp) = CURRENT_DATE()
GROUP BY
  1
ORDER BY
  request_count DESC;
```

---

### 4. Most Searched Cities (`stdout`)
Application business intelligence extracted directly from container JSON logs:
```sql
SELECT
  REGEXP_EXTRACT(STRING(jsonPayload.query_string), r'name=([^&]+)') AS city_searched,
  COUNT(*) AS search_count,
  ROUND(AVG(CAST(jsonPayload.latency_ms AS FLOAT64)), 2) AS avg_latency_ms
FROM
  `myproject-329912.k8s_logs.stdout`
WHERE
  STRING(jsonPayload.path) = '/api/city'
  AND DATE(timestamp) = CURRENT_DATE()
GROUP BY
  1
HAVING
  city_searched IS NOT NULL
ORDER BY
  search_count DESC;
```

---

### 5. Application Errors & Stack Traces (`stderr`)
Inspect recent container errors or unhandled exceptions:
```sql
SELECT
  timestamp,
  resource.labels.pod_name AS pod_name,
  textPayload AS error_message
FROM
  `myproject-329912.k8s_logs.stderr`
WHERE
  DATE(timestamp) = CURRENT_DATE()
ORDER BY
  timestamp DESC
LIMIT 50;
```

---

## 📈 1-Click Looker Studio Visual Dashboard

To visualize these queries as interactive charts:
1. Run any query above in **BigQuery Studio**.
2. Click the **"Explore data"** dropdown button above the results table.
3. Select **"Explore with Looker Studio"**.
4. Looker Studio automatically creates interactive bar charts, time series, and tables with zero configuration!

