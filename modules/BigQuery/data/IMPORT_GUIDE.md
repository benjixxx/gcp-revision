# BigQuery Dataset Import Guide

This guide walks you through importing the sample datasets into **Google BigQuery** using the `bq` CLI tool or Cloud Storage.

---

## 1. Dataset Overview

The sample datasets are provided in two formats:
* [`transactions.csv`](./transactions.csv) (Standard CSV with headers)
* [`transactions.jsonl`](./transactions.jsonl) (Newline-delimited JSON)

### Schema Definition
Matches the Terraform definition in [`modules/BigQuery/main.tf`](../main.tf):

| Column Name | Type | Mode | Role |
| :--- | :--- | :--- | :--- |
| `transaction_id` | `STRING` | `REQUIRED` | Unique transaction ID |
| `customer_id` | `STRING` | `REQUIRED` | Clustered field |
| `amount` | `NUMERIC` | `REQUIRED` | Transaction amount |
| `status` | `STRING` | `NULLABLE` | Clustered field (`COMPLETED`, `PENDING`, `FAILED`) |
| `transaction_timestamp`| `TIMESTAMP`| `REQUIRED` | **Day-partitioning field** |

---

## 2. Step-by-Step Import with `bq` CLI

### Step 2.1 Set Environment Variables
```bash
cd modules/BigQuery/data

export PROJECT_ID=$(gcloud config get-value project)
export DATASET_ID="analytics_dw"
export TABLE_ID="transactions"
export LOCATION="EU"
```

### Step 2.2 Create the BigQuery Dataset (If Not Already Created)
```bash
bq mk --dataset \
  --location=${LOCATION} \
  --description="Sample analytics data warehouse" \
  ${PROJECT_ID}:${DATASET_ID}
```

### Step 2.3 Option A: Import CSV File Directly (Local File)
Run this command from `modules/BigQuery/data`:

```bash
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --time_partitioning_field=transaction_timestamp \
  --time_partitioning_type=DAY \
  --clustering_fields=customer_id,status \
  ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID} \
  ./transactions.csv \
  transaction_id:STRING,customer_id:STRING,amount:NUMERIC,status:STRING,transaction_timestamp:TIMESTAMP
```

### Step 2.4 Option B: Import JSONL File Directly (Local File)
```bash
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --time_partitioning_field=transaction_timestamp \
  --time_partitioning_type=DAY \
  --clustering_fields=customer_id,status \
  ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID} \
  ./transactions.jsonl \
  transaction_id:STRING,customer_id:STRING,amount:NUMERIC,status:STRING,transaction_timestamp:TIMESTAMP
```

---

## 3. Option C: Import via Google Cloud Storage (Production Pattern)

If importing large datasets or files already hosted in GCS:

1. **Upload file to Cloud Storage**:
   ```bash
   gsutil cp ./transactions.csv gs://YOUR_BUCKET_NAME/data/transactions.csv
   ```

2. **Load into BigQuery**:
   ```bash
   bq load \
     --source_format=CSV \
     --skip_leading_rows=1 \
     --time_partitioning_field=transaction_timestamp \
     --clustering_fields=customer_id,status \
     ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID} \
     gs://YOUR_BUCKET_NAME/data/transactions.csv \
     transaction_id:STRING,customer_id:STRING,amount:NUMERIC,status:STRING,transaction_timestamp:TIMESTAMP
   ```

---

## 4. Verification & Testing Query Optimization

### 4.1 Verify Loaded Rows
```bash
bq query --use_legacy_sql=false \
  "SELECT count(*) as total_rows FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`"
```

### 4.2 Preview Table Data for Free ($0 cost)
```bash
bq head -n 5 ${DATASET_ID}.${TABLE_ID}
```

### 4.3 Test Partition Pruning (Simulate Cost Savings)
Run a dry run to check bytes scanned when filtering on the partition date:

```bash
bq query --use_legacy_sql=false --dry_run \
  "SELECT customer_id, sum(amount) as total_spent
   FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`
   WHERE DATE(transaction_timestamp) = '2026-09-15'
     AND status = 'COMPLETED'
   GROUP BY customer_id"
```
*(Notice how BigQuery only scans data from the 2026-09-15 partition!)*

