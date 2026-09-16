# GCP Certification Exam Notes & Key Topics

This document is a consolidated revision guide covering specific GCP exam topics, edge cases, and architectural best practices.

---

## Table of Contents
1. [Resource Management: Project Liens](#1-resource-management-project-liens)
2. [Serverless Compute: App Engine (Standard vs. Flexible)](#2-serverless-compute-app-engine-standard-vs-flexible)
3. [Data Analytics: BigQuery Pricing & Query Caching](#3-data-analytics-bigquery-pricing--query-caching)

---

## 1. Resource Management: Project Liens

### 1.1 What is a Lien?
A **Lien** is a protective lock placed on a Google Cloud project to **prevent accidental deletion**. 

When a lien is active on a project, any attempt to delete the project (via Cloud Console, `gcloud projects delete`, or the API) will immediately fail, **even if the user has the `Owner` or `Project Deleter` role**.

---

### 1.2 Key Exam Concepts & Behaviors

| Feature | Behavior / Limitation |
| :--- | :--- |
| **Primary Restriction** | `resourcemanager.projects.delete` (prevents project deletion). |
| **Does NOT Protect Against** | Deleting individual resources *inside* the project (e.g., deleting VMs, Cloud Storage buckets, BigQuery datasets), nor does it prevent stopping instances or disabling billing. |
| **Who can delete a locked project?** | Nobody. The lien **must be explicitly deleted first** before the project can be shut down. |
| **Common Exam Scenario** | *"You have a critical production project and want to guarantee that no user—even a Project Owner—can accidentally delete it. What should you do?"* <br>👉 **Answer:** Apply a project lien (`resourcemanager.projects.delete`). |

---

### 1.3 IAM Roles & Permissions

To work with liens, specific IAM roles are required:

| Role Name | Role ID | Allowed Actions |
| :--- | :--- | :--- |
| **Lien Modifier** | `roles/resourcemanager.lienModifier` | Create and delete liens (`createLien`, `deleteLien`). |
| **Lien Viewer** | `roles/resourcemanager.lienViewer` | View active liens on a project (`getLiens`). |
| **Project Owner** | `roles/owner` | Has lien permissions by default, but **cannot delete the project until the lien itself is removed**. |

---

### 1.4 Essential `gcloud` Commands

#### 1. Create a Lien
```bash
gcloud resource-manager liens create \
  --project="PROJECT_ID" \
  --restrictions="resourcemanager.projects.delete" \
  --reason="Prevent accidental deletion of critical production project"
```

#### 2. List Active Liens on a Project
```bash
gcloud resource-manager liens list --project="PROJECT_ID"
```
*Output will give you the unique lien name, e.g., `liens/p123456789-l987654321`.*

#### 3. Delete a Lien (to allow project deletion)
```bash
gcloud resource-manager liens delete LIEN_NAME
```
*(Example: `gcloud resource-manager liens delete liens/p123456789-l987654321`)*

---

### 1.5 Exam Cheatsheet / Pitfalls
* **Lien vs. Organization Policy:**
  * Use **Organization Policies** to enforce configuration constraints across projects, folders, or orgs (e.g., restrict public IPs, define allowed resource locations).
  * Use **Project Liens** specifically to block project deletion.
* **Lien vs. IAM:**
  * Removing `roles/resourcemanager.projectDeleter` prevents specific users from deleting a project, but a rogue/compromised Owner could still do it. A **Lien blocks everyone**, including Owners, until the lien is deliberately removed.

---

## 2. Serverless Compute: App Engine (Standard vs. Flexible)

### 2.1 Core Architectural Differences

| Feature | Standard Environment | Flexible Environment |
| :--- | :--- | :--- |
| **Underlying Host** | Sandbox container | **Configurable Compute Engine VMs** |
| **Startup Speed** | Milliseconds / Seconds | Minutes |
| **Scale to Zero?** | **Yes** (0 instances when idle) | **No** (minimum 1 VM instance) |
| **Custom Dockerfile** | No | **Yes** (any runtime, custom OS libraries) |
| **SSH Access** | No | **Yes** |
| **Pricing** | Instance hours + Free Tier | Compute Engine VM pricing (vCPU, RAM, disk) |

---

### 2.2 Exam Question & Answer Example

**Question 60:**
> Google App Engine has a second hosting option, called App Engine Flexible Environment. Which of the following best describes App Engine Flexible Environment?
>
> - **A. (Correct)** The Flexible Environment supports App Engine applications on configurable Compute Engine instances.
> - **B.** The Flexible Environment supports App Engine instances on third-party networks.
> - **C.** The Flexible Environment supports applications on configurable GKE containers.
> - **D.** The Flexible Environment supports managed functions as well as managed instances.

**Correct Answer:** **A**

**Explanation:**
* App Engine Flexible runs containers on top of **configurable Compute Engine virtual machines (VMs)**.
* This allows users to configure custom CPU, memory, and disk options, as well as install native OS packages.
* **Distractor analysis:**
  * **B** is incorrect because App Engine runs on GCP VPC networks.
  * **C** is incorrect because App Engine Flexible runs on Compute Engine VMs, not GKE clusters.
  * **D** is incorrect because managed functions belong to Cloud Functions / Cloud Run functions.

* Official Documentation: [Google App Engine Flexible Environment](https://cloud.google.com/appengine/docs/flexible/)

---

## 3. Data Analytics: BigQuery Pricing & Query Caching

### 3.1 BigQuery Query Pricing Foundations

BigQuery separates compute (query processing) from storage. Under the standard **On-Demand** pricing model:

| Cost Component | Pricing Rule | Key Exam Detail |
| :--- | :--- | :--- |
| **Query Processing** | Billed per byte scanned by selected columns | Rate is ~$6.25 per TB scanned (varies slightly by region). |
| **Free Tier** | **1 TB of query processing per month** | **Not 10 TB** (a common exam trap). |
| **Columnar Scanning** | BigQuery stores data in Capacitor (columnar format) | Selecting 2 columns scans *only* those 2 columns, regardless of table row count. |
| **Table Metadata / DDL** | Schema queries, table creation, and DDL queries are **free** | Queries that return only metadata scan 0 bytes. |

---

### 3.2 Query Caching Mechanics

When you run a query, BigQuery caches the exact result in a temporary table for **24 hours**.

* **Cost of Cached Queries:** **$0.00 (0 bytes scanned)**. If a subsequent query can be served from the cache, you are **not charged**.
* **Cache Requirements:**
  * The query string must be an exact character-for-character match.
  * The underlying table data must not have changed.
  * The destination table and configuration must be identical.
* **When Caching Fails / Is Bypassed:**
  * **Non-deterministic functions:** Using functions like `CURRENT_TIMESTAMP()`, `CURRENT_DATE()`, `NOW()`, or `RAND()` disables caching because the output varies per second.
  * **External data sources:** Queries targeting external tables (Cloud Storage, Google Drive, Cloud Bigtable) are never cached.
  * **Table modifications:** Any streaming inserts or DML updates invalidate the cache.
  * **Row-Level Security:** Queries against tables with row-level access policies cannot use cached results.
  * **Manual override:** Unchecking "Use cached results" in the console or passing `--nouse_cache` in the CLI.

---

### 3.3 Real Exam Question & Explanation

**Question 62:**
> Which statement regarding the cost of querying with Google BigQuery is correct?
>
> - **A.** BigQuery charges for processing the data in queries and for reading it.
> - **B.** Querying data stored within BigQuery is less expensive than querying data stored outside of it, such as in Cloud Storage.
> - **C. (Correct)** You are not charged for querying data that is cached within BigQuery.
> - **D.** The first 10 TB of data queries per month are free.

**Correct Answer:** **C**

**Explanation:**
* **Why C is correct:** BigQuery automatically caches query results for 24 hours. When a query hits the cache, BigQuery scans 0 bytes, making the query completely free of charge.
* **Why the other options are wrong:**
  * **A is incorrect:** BigQuery does not charge two separate fees for reading vs. processing. Under on-demand pricing, you pay once for the total bytes scanned by the columns selected in the query.
  * **B is incorrect:** Querying external data (federated queries) charges the standard BigQuery per-TB query rate for data read, but internal tables do not have a lower per-TB query rate. (External tables are actually less efficient because they cannot leverage BigQuery columnar storage optimizations or query caching).
  * **D is incorrect:** The BigQuery free tier provides the first **1 TB** of query data processed per month for free, **not 10 TB**.

* Official Reference: [BigQuery Query Pricing](https://cloud.google.com/bigquery/pricing#queries)

---

### 3.4 Top 5 BigQuery Cost Optimization Exam Traps

1. **The `LIMIT` Clause Trap:**
   * **Rule:** Adding `LIMIT 10` to a query **DOES NOT reduce the query cost or bytes scanned**.
   * **Why:** BigQuery is a columnar store. It must scan the entire column across all rows/partitions before truncating the output to 10 rows.
   * **Exam Solution:** To inspect table data for free, use the **Table Preview** tab in the console or `bq head` in the CLI (reads table metadata at 0 cost).

2. **The `SELECT *` Anti-Pattern:**
   * **Rule:** Never use `SELECT *` in production queries.
   * **Why:** BigQuery charges for every column scanned. Select only the exact columns your application needs.

3. **Partitioning vs. Clustering:**
   * **Partitioning:** Divides a table by date, timestamp, or integer range. Queries filtering on the partition column in the `WHERE` clause prune unneeded partitions, directly reducing the bytes scanned and cost.
   * **Clustering:** Sorts data within partitions based on up to 4 columns. Colocates related data to skip irrelevant blocks, improving performance and further lowering query cost.

4. **Query Cost Validation (Dry Run):**
   * Use the `--dry_run` flag with the `bq` CLI tool to validate query syntax and preview the exact number of bytes scanned **without executing the query or incurring any cost**:
     ```bash
     bq query --use_legacy_sql=false --dry_run "SELECT user_id, amount FROM \`myproject.sales.transactions\` WHERE date = '2026-01-01'"
     ```

5. **Maximum Bytes Billed Safety Guard:**
   * Prevent runaway costs from expensive queries by configuring the `maximum_bytes_billed` setting. If a query scans more than this threshold, it fails before executing:
     ```bash
     bq query --maximum_bytes_billed=10737418240 "SELECT * FROM \`myproject.dataset.huge_table\`"
     ```

---

### 3.5 Additional Practice Exam Questions

#### Practice Question 1 (The `LIMIT` Misconception)
> A junior data analyst wants to review the schema and sample rows of a 50 TB transactions table in BigQuery without incurring any query costs. Which method should they use?
>
> - **A.** Run `SELECT * FROM \`transactions\` LIMIT 10;`
> - **B.** Run `SELECT * FROM \`transactions\` WHERE date = CURRENT_DATE() LIMIT 10;`
> - **C. (Correct)** Use the Table Preview feature in the BigQuery Cloud Console or run `bq head -n 10 transactions`.
> - **D.** Run `SELECT transaction_id FROM \`transactions\` LIMIT 10;`

**Answer:** **C**  
**Explanation:** `LIMIT 10` still scans the entire table's columns and will charge for scanning 50 TB of data. The **Table Preview** tab in the console reads metadata directly and does **not** run a query job, meaning it processes 0 bytes and is completely free.

---

#### Practice Question 2 (Partitioning & Cost Control)
> Your organization queries a 100 TB log dataset daily. Queries almost always filter by the log timestamp over a 3-day window and filter by `severity` (e.g., `ERROR`, `WARNING`). Query costs are escalating. What should you recommend?
>
> - **A.** Set a `LIMIT 1000` clause on all daily queries.
> - **B. (Correct)** Partition the table by the timestamp column and cluster the table by `severity`.
> - **C.** Export the logs to Cloud Storage and query them using an external table.
> - **D.** Use `SELECT *` with a `WHERE` clause filtering by timestamp.

**Answer:** **B**  
**Explanation:** Partitioning by timestamp ensures queries only scan the blocks corresponding to the 3-day window rather than all 100 TB. Clustering by `severity` co-locates rows with the same severity level within each partition, further eliminating unneeded block reads and maximizing cost savings.


