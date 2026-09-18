# Analytics Module (BigQuery Focus)
# Google BigQuery Module

This module provisions Google Cloud Database and Analytics resources, focusing on **Google BigQuery** (Dataset & Tables with Partitioning and Clustering), along with an exam-focused architectural reference guide for all GCP database options.
This module provisions and configures **Google BigQuery** data warehousing resources, featuring dataset management, time-unit partitioning, multi-column clustering, query cost-optimization strategies, and exam-critical architecture references.

---

## Official Documentation
- [Google BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [BigQuery Query Pricing](https://cloud.google.com/bigquery/pricing#queries)
- [BigQuery Query & Storage Pricing](https://cloud.google.com/bigquery/pricing)
- [BigQuery Partitioned Tables](https://cloud.google.com/bigquery/docs/partitioned-tables)
- [BigQuery Clustered Tables](https://cloud.google.com/bigquery/docs/clustered-tables)

---

## Provisioned Terraform Resources
- **`google_bigquery_dataset.dataset`**: Fully managed analytical dataset in the specified location.
- **`google_bigquery_table.table`**: Columnar table configured with **time-unit partitioning** (Day) and **multi-column clustering**.
- **`google_bigquery_dataset.k8s_logs`**: Dedicated partitioned dataset for GKE container logs routed by Cloud Logging.

### Inputs
| Name | Description | Type | Default |
| :--- | :--- | :--- | :--- |
| `dataset_id` | Unique ID for the BigQuery analytics dataset | `string` | `"analytics_dw"` |
| `location` | Geographic location for data storage (`EU`, `US`, etc.) | `string` | `"EU"` |
| `table_id` | BigQuery analytics table name | `string` | `"transactions"` |
| `partition_field` | Timestamp/Date column used for table partitioning | `string` | `"transaction_timestamp"` |
| `clustering_fields` | List of up to 4 columns used for clustering | `list(string)` | `["customer_id", "status"]` |
| `logging_dataset_id` | Unique ID for the BigQuery dataset storing GKE logs | `string` | `"k8s_logs"` |
| `logging_table_expiration_days` | Days before partitioned log tables expire | `number` | `30` |

### Outputs
| Name | Description |
| :--- | :--- |
| `dataset_id` | The ID of the analytics BigQuery dataset |
| `table_id` | The ID of the partitioned and clustered table |
| `table_self_link` | URI of the provisioned BigQuery table |
| `logging_dataset_id` | The ID of the GKE container logs dataset |
| `logging_dataset_location` | Geographic location of the logging dataset |

---

## GCP Database Decision Tree (Exam Reference)
## BigQuery Architecture & Storage Model

| Database Service | Type | Best For | Typical Use Cases |
| :--- | :--- | :--- | :--- |
| **BigQuery** | Serverless Data Warehouse / OLAP | Petabyte-scale SQL analytics, BI reporting, columnar queries | Enterprise analytics, log analysis, ML training data |
| **Cloud SQL** | Managed Relational (OLTP) | MySQL, PostgreSQL, SQL Server (up to 64 TB) | Traditional web apps, ERP, CRM, lift-and-shift |
| **Cloud Spanner** | Globally Distributed Relational (OLTP) | Global horizontal scale, ACID compliance, 99.999% SLA | Global financial systems, multi-region transactions |
| **Firestore** | Serverless NoSQL Document Store | Real-time synchronization, offline mobile/web sync | Mobile backends, user profiles, gaming leaderboards |
| **Cloud Bigtable** | Managed Wide-Column NoSQL | High throughput, sub-10ms latency writes at petabyte scale | IoT telemetry, time-series, clickstream analysis |
BigQuery separates compute from storage completely:

```
+-------------------------------------------------------------+
|                  BigQuery Compute Engine                    |
|         Dynamic Query Slots (Borg Engine Allocations)       |
+-------------------------------------------------------------+
                               |
                   Petabit Jupiter Network
                               |
+-------------------------------------------------------------+
|                  BigQuery Storage (Colossus)                |
|           Stored in Columnar Format: "Capacitor"            |
+-------------------------------------------------------------+
```

* **Capacitor (Columnar Format):** Data is organized by column rather than by row. When executing a query, BigQuery reads and scans **only the specific columns referenced** in the query.
* **Active vs. Long-Term Storage:**
  * **Active Storage:** Tables or partitions modified in the last 90 days.
  * **Long-Term Storage:** Tables or partitions untouched for 90 consecutive days automatically receive a **~50% price reduction** with zero impact on query performance.

---

## BigQuery Deep-Dive: Pricing & Query Optimization
## Pricing & Query Caching Mechanics

### 1. On-Demand Pricing Model
* Billed strictly by the **total bytes scanned** by the columns selected in the query (~$6.25 per TB).
* **Free Tier:** The first **1 TB of query processing per month is completely free** (not 10 TB).
* **Table Metadata & DDL:** Queries scanning only metadata (or schema inspection) process 0 bytes and are free.
* **Table Metadata & DDL:** Queries that only read metadata (or schema inspection) process 0 bytes and are free.

### 2. Query Caching Mechanics
* Query results are cached in temporary tables for **24 hours**.
* **Cost:** **$0.00 (0 bytes processed)** when a query is served from the cache.
* **Cache invalidation rules:**
  * Using non-deterministic functions (`CURRENT_TIMESTAMP()`, `NOW()`, `RAND()`) disables caching.
  * Streaming inserts or DML table updates invalidate the cache.
  * External federated tables (e.g. Cloud Storage, Drive) cannot use cached results.
* **Cache Invalidation Rules:**
  * **Non-deterministic functions:** Using functions like `CURRENT_TIMESTAMP()`, `CURRENT_DATE()`, `NOW()`, or `RAND()` disables caching because the output varies per run.
  * **Table modifications:** Streaming inserts or DML table updates invalidate the cache.
  * **External data sources:** Queries targeting external federated tables (e.g., Cloud Storage, Google Drive) cannot use cached results.
  * **Row-Level Security:** Tables with row access policies bypass cached results.

### 3. Cost-Optimization Best Practices
---

## Top Cost-Optimization Best Practices

| Technique | How It Works | Impact on Cost |
| :--- | :--- | :--- |
| **Avoid `SELECT *`** | Only select columns your query actually uses | Drastically cuts scanned bytes in columnar storage. |
| **Avoid `SELECT *`** | Only select columns your query actually needs | Drastically cuts scanned bytes in columnar storage. |
| **Avoid `LIMIT` for Cost** | `LIMIT 10` does **NOT** reduce query cost | BigQuery still scans the entire column before truncating. Use **Table Preview** for free sampling. |
| **Partitioning** | Splits tables by Date, Timestamp, or Integer range | Scans only the partitions requested in the `WHERE` clause. |
| **Clustering** | Sorts and co-locates data within partitions (up to 4 columns) | Skips irrelevant storage blocks, speeding queries and lowering cost. |
| **Dry-Run Validation** | `bq query --dry_run ...` calculates exact bytes scanned | Tests syntax and cost with **zero charges**. |
| **Dry-Run Validation** | `bq query --dry_run ...` calculates exact bytes scanned | Tests syntax and estimates cost with **zero charges**. |
| **Max Bytes Billed** | Set `--maximum_bytes_billed` limit | Automatically aborts runaway expensive queries before execution. |

---

## Real Exam Questions & Answers

### Question 1: BigQuery Query Cost
> **Question:** Which statement regarding the cost of querying with Google BigQuery is correct?
### Question 1: BigQuery Query Cost & Caching
> **Question (62):** Which statement regarding the cost of querying with Google BigQuery is correct?
> - **A.** BigQuery charges for processing the data in queries and for reading it.
> - **B.** Querying data stored within BigQuery is less expensive than querying data stored outside of it, such as in Cloud Storage.
> - **C. (Correct)** You are not charged for querying data that is cached within BigQuery.
> - **D.** The first 10 TB of data queries per month are free.

**Correct Answer:** **C**  
**Explanation:** Cached query results are served at $0.00 (0 bytes scanned). The free tier is 1 TB (not 10 TB).

---

### Question 2: Inspecting Data Without Costs
### Question 2: Inspecting Data Without Incurring Costs
> **Question:** A data engineer needs to inspect sample rows of a 20 TB dataset to verify column contents without incurring query charges. What should they do?
> - **A.** Run `SELECT * FROM \`dataset.table\` LIMIT 5;`
> - **B. (Correct)** Use the Table Preview feature in the Google Cloud Console or run `bq head -n 5 dataset.table`.
> - **C.** Export 5 rows to Cloud Storage.
> - **D.** Run `SELECT * FROM \`dataset.table\` WHERE _PARTITIONDATE = CURRENT_DATE() LIMIT 5;`

**Correct Answer:** **B**  
**Explanation:** `LIMIT 5` will still scan the entire 20 TB table and incur charges. **Table Preview** reads table metadata directly and processes 0 bytes for free.

---

## 20 Essential GCP CLI Commands (`bq` & Cloud SQL)
## 20 Essential `bq` CLI Commands

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM dataset.table'` | Run a standard SQL query in BigQuery. |
| `bq query --dry_run --use_legacy_sql=false 'SELECT ...'` | Estimate query cost and bytes scanned without running it. |
| `bq query --maximum_bytes_billed=10737418240 'SELECT ...'` | Run query with a strict 10 GB scan ceiling to prevent budget overruns. |
| `bq query --dry_run --use_legacy_sql=false 'SELECT ...'` | Estimate query cost and bytes scanned without running it ($0). |
| `bq query --maximum_bytes_billed=10737418240 'SELECT ...'` | Set a strict 10 GB scan ceiling to prevent budget overruns. |
| `bq head -n 10 dataset.table` | Preview the first 10 rows of a table for **free** (0 bytes scanned). |
| `bq ls --project_id=<PROJECT_ID>` | List all datasets in a GCP project. |
| `bq ls dataset_name` | List all tables and views inside a dataset. |
| `bq show dataset.table` | View schema, partition status, row count, and size in bytes. |
| `bq show --format=prettyjson dataset.table` | View detailed table metadata and schema in JSON format. |
| `bq mk --dataset --location=EU <PROJECT_ID>:dataset_name` | Create a new BigQuery dataset in the EU region. |
| `bq mk --table dataset.table schema.json` | Create a table with a predefined JSON schema. |
| `bq rm -r -f dataset_name` | Recursively and forcefully delete a dataset and its contents. |
| `bq load --source_format=CSV dataset.table gs://bucket/data.csv` | Ingest data from Cloud Storage into a BigQuery table (free ingestion). |
| `bq extract --destination_format=CSV dataset.table gs://bucket/out.csv` | Export BigQuery table to Cloud Storage. |
| `bq mk --table dataset.table schema.json` | Create a table with a predefined JSON schema file. |
| `bq rm -r -f dataset_name` | Recursively and forcefully delete a dataset and its tables. |
| `bq rm -t dataset.table` | Delete a single table. |
| `bq load --source_format=CSV dataset.table gs://bucket/data.csv` | Ingest data from Cloud Storage into BigQuery (batch ingestion is free). |
| `bq load --source_format=NEWLINE_DELIMITED_JSON dataset.table ./data.jsonl` | Ingest local JSONL file into a BigQuery table. |
| `bq extract --destination_format=CSV dataset.table gs://bucket/out.csv` | Export BigQuery table data to Cloud Storage. |
| `bq cp dataset.table_source dataset.table_dest` | Copy a table within or across datasets. |
| `gcloud sql instances list` | List all Cloud SQL database instances in the project. |
| `gcloud sql instances describe <INSTANCE>` | View IP, tier, state, and replication settings of Cloud SQL. |
| `gcloud sql databases create <DB_NAME> --instance=<INSTANCE>` | Create a database inside a Cloud SQL instance. |
| `gcloud sql backups create --instance=<INSTANCE>` | Trigger an on-demand backup of a Cloud SQL instance. |
| `gcloud sql users create <USER> --instance=<INSTANCE> --password=<PASS>` | Create a database user in Cloud SQL. |
| `gcloud spanner instances list` | List Cloud Spanner instances and node counts. |
| `gcloud services enable bigquery.googleapis.com sqladmin.googleapis.com` | Enable BigQuery and Cloud SQL APIs. |
| `bq update --description="Updated table description" dataset.table` | Update table metadata. |
| `bq cancel <JOB_ID>` | Cancel a running query or load job. |
| `bq version` | Display BigQuery CLI version. |
| `gcloud services enable bigquery.googleapis.com` | Enable the BigQuery API in your GCP project. |

---

## Hands-On Lab: Sample Dataset & Import

Sample datasets matching this module's schema are stored in [`data/`](./data):
* [`data/transactions.csv`](./data/transactions.csv) (CSV format)
* [`data/transactions.jsonl`](./data/transactions.jsonl) (Newline-delimited JSON)

### One-Liner Import Command
Run from the `modules/BigQuery` directory:

```bash
cd modules/BigQuery

# 1. Create dataset (if needed)
bq mk --dataset --location=EU $(gcloud config get-value project):analytics_dw

# 2. Load CSV directly with Partitioning and Clustering
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --time_partitioning_field=transaction_timestamp \
  --time_partitioning_type=DAY \
  --clustering_fields=customer_id,status \
  $(gcloud config get-value project):analytics_dw.transactions \
  ./data/transactions.csv \
  transaction_id:STRING,customer_id:STRING,amount:NUMERIC,status:STRING,transaction_timestamp:TIMESTAMP
```
