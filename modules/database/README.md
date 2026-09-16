# GCP Database & Analytics Module (BigQuery Focus)

This module provisions Google Cloud Database and Analytics resources, focusing on **Google BigQuery** (Dataset & Tables with Partitioning and Clustering), along with an exam-focused architectural reference guide for all GCP database options.

---

## Official Documentation
- [Google BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [BigQuery Query Pricing](https://cloud.google.com/bigquery/pricing#queries)
- [BigQuery Partitioned Tables](https://cloud.google.com/bigquery/docs/partitioned-tables)
- [BigQuery Clustered Tables](https://cloud.google.com/bigquery/docs/clustered-tables)

---

## Provisioned Terraform Resources
- **`google_bigquery_dataset`**: Fully managed analytical dataset.
- **`google_bigquery_table`**: Columnar table configured with **time-unit partitioning** and **multi-column clustering**.

### Inputs
| Name | Description | Type | Default |
| :--- | :--- | :--- | :--- |
| `dataset_id` | Unique ID for the BigQuery dataset | `string` | `"analytics_dw"` |
| `location` | Location for data storage (e.g., `EU`, `US`) | `string` | `"EU"` |
| `table_id` | BigQuery table name | `string` | `"transactions"` |
| `partition_field` | Timestamp/Date column used for table partitioning | `string` | `"transaction_timestamp"` |
| `clustering_fields` | List of up to 4 columns used for clustering | `list(string)` | `["customer_id", "status"]` |

### Outputs
| Name | Description |
| :--- | :--- |
| `dataset_id` | The ID of the created dataset |
| `table_id` | The ID of the partitioned and clustered table |

---

## GCP Database Decision Tree (Exam Reference)

| Database Service | Type | Best For | Typical Use Cases |
| :--- | :--- | :--- | :--- |
| **BigQuery** | Serverless Data Warehouse / OLAP | Petabyte-scale SQL analytics, BI reporting, columnar queries | Enterprise analytics, log analysis, ML training data |
| **Cloud SQL** | Managed Relational (OLTP) | MySQL, PostgreSQL, SQL Server (up to 64 TB) | Traditional web apps, ERP, CRM, lift-and-shift |
| **Cloud Spanner** | Globally Distributed Relational (OLTP) | Global horizontal scale, ACID compliance, 99.999% SLA | Global financial systems, multi-region transactions |
| **Firestore** | Serverless NoSQL Document Store | Real-time synchronization, offline mobile/web sync | Mobile backends, user profiles, gaming leaderboards |
| **Cloud Bigtable** | Managed Wide-Column NoSQL | High throughput, sub-10ms latency writes at petabyte scale | IoT telemetry, time-series, clickstream analysis |

---

## BigQuery Deep-Dive: Pricing & Query Optimization

### 1. On-Demand Pricing Model
* Billed strictly by the **total bytes scanned** by the columns selected in the query (~$6.25 per TB).
* **Free Tier:** The first **1 TB of query processing per month is completely free** (not 10 TB).
* **Table Metadata & DDL:** Queries scanning only metadata (or schema inspection) process 0 bytes and are free.

### 2. Query Caching Mechanics
* Query results are cached in temporary tables for **24 hours**.
* **Cost:** **$0.00 (0 bytes processed)** when a query is served from the cache.
* **Cache invalidation rules:**
  * Using non-deterministic functions (`CURRENT_TIMESTAMP()`, `NOW()`, `RAND()`) disables caching.
  * Streaming inserts or DML table updates invalidate the cache.
  * External federated tables (e.g. Cloud Storage, Drive) cannot use cached results.

### 3. Cost-Optimization Best Practices

| Technique | How It Works | Impact on Cost |
| :--- | :--- | :--- |
| **Avoid `SELECT *`** | Only select columns your query actually uses | Drastically cuts scanned bytes in columnar storage. |
| **Avoid `LIMIT` for Cost** | `LIMIT 10` does **NOT** reduce query cost | BigQuery still scans the entire column before truncating. Use **Table Preview** for free sampling. |
| **Partitioning** | Splits tables by Date, Timestamp, or Integer range | Scans only the partitions requested in the `WHERE` clause. |
| **Clustering** | Sorts and co-locates data within partitions (up to 4 columns) | Skips irrelevant storage blocks, speeding queries and lowering cost. |
| **Dry-Run Validation** | `bq query --dry_run ...` calculates exact bytes scanned | Tests syntax and cost with **zero charges**. |
| **Max Bytes Billed** | Set `--maximum_bytes_billed` limit | Automatically aborts runaway expensive queries before execution. |

---

## Real Exam Questions & Answers

### Question 1: BigQuery Query Cost
> **Question:** Which statement regarding the cost of querying with Google BigQuery is correct?
> - **A.** BigQuery charges for processing the data in queries and for reading it.
> - **B.** Querying data stored within BigQuery is less expensive than querying data stored outside of it, such as in Cloud Storage.
> - **C. (Correct)** You are not charged for querying data that is cached within BigQuery.
> - **D.** The first 10 TB of data queries per month are free.

**Correct Answer:** **C**  
**Explanation:** Cached query results are served at $0.00 (0 bytes scanned). The free tier is 1 TB (not 10 TB).

---

### Question 2: Inspecting Data Without Costs
> **Question:** A data engineer needs to inspect sample rows of a 20 TB dataset to verify column contents without incurring query charges. What should they do?
> - **A.** Run `SELECT * FROM \`dataset.table\` LIMIT 5;`
> - **B. (Correct)** Use the Table Preview feature in the Google Cloud Console or run `bq head -n 5 dataset.table`.
> - **C.** Export 5 rows to Cloud Storage.
> - **D.** Run `SELECT * FROM \`dataset.table\` WHERE _PARTITIONDATE = CURRENT_DATE() LIMIT 5;`

**Correct Answer:** **B**  
**Explanation:** `LIMIT 5` will still scan the entire 20 TB table and incur charges. **Table Preview** reads table metadata directly and processes 0 bytes for free.

---

## 20 Essential GCP CLI Commands (`bq` & Cloud SQL)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM dataset.table'` | Run a standard SQL query in BigQuery. |
| `bq query --dry_run --use_legacy_sql=false 'SELECT ...'` | Estimate query cost and bytes scanned without running it. |
| `bq query --maximum_bytes_billed=10737418240 'SELECT ...'` | Run query with a strict 10 GB scan ceiling to prevent budget overruns. |
| `bq head -n 10 dataset.table` | Preview the first 10 rows of a table for **free** (0 bytes scanned). |
| `bq ls --project_id=<PROJECT_ID>` | List all datasets in a GCP project. |
| `bq ls dataset_name` | List all tables and views inside a dataset. |
| `bq show dataset.table` | View schema, partition status, row count, and size in bytes. |
| `bq mk --dataset --location=EU <PROJECT_ID>:dataset_name` | Create a new BigQuery dataset in the EU region. |
| `bq mk --table dataset.table schema.json` | Create a table with a predefined JSON schema. |
| `bq rm -r -f dataset_name` | Recursively and forcefully delete a dataset and its contents. |
| `bq load --source_format=CSV dataset.table gs://bucket/data.csv` | Ingest data from Cloud Storage into a BigQuery table (free ingestion). |
| `bq extract --destination_format=CSV dataset.table gs://bucket/out.csv` | Export BigQuery table to Cloud Storage. |
| `bq cp dataset.table_source dataset.table_dest` | Copy a table within or across datasets. |
| `gcloud sql instances list` | List all Cloud SQL database instances in the project. |
| `gcloud sql instances describe <INSTANCE>` | View IP, tier, state, and replication settings of Cloud SQL. |
| `gcloud sql databases create <DB_NAME> --instance=<INSTANCE>` | Create a database inside a Cloud SQL instance. |
| `gcloud sql backups create --instance=<INSTANCE>` | Trigger an on-demand backup of a Cloud SQL instance. |
| `gcloud sql users create <USER> --instance=<INSTANCE> --password=<PASS>` | Create a database user in Cloud SQL. |
| `gcloud spanner instances list` | List Cloud Spanner instances and node counts. |
| `gcloud services enable bigquery.googleapis.com sqladmin.googleapis.com` | Enable BigQuery and Cloud SQL APIs. |

