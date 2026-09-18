# GCP Certification Exam Notes & Key Topics

This document is a consolidated revision guide covering specific GCP exam topics, edge cases, and architectural best practices.

---

## Table of Contents
1. [Resource Management: Project Liens](#1-resource-management-project-liens)
2. [Serverless Compute: App Engine (Standard vs. Flexible)](#2-serverless-compute-app-engine-standard-vs-flexible)
3. [Observability: Cloud Logging & Cloud Monitoring](#3-observability-cloud-logging--cloud-monitoring)

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

## 3. Observability: Cloud Logging & Cloud Monitoring

### 3.1 Cloud Logging Architecture & Exam Essentials

Cloud Logging is Google Cloud's fully managed, real-time log management service.

```
       Sources                         Log Router                         Destinations
 ┌─────────────────┐             ┌─────────────────────┐             ┌─────────────────────┐
 │ GKE Containers  │             │                     │ ── Filter ──► Cloud Storage (Archive)
 │ Compute Engine  │ ── Logs ──► │  Inclusion Filters  │ ── Filter ──► BigQuery (SQL Analysis)
 │ Cloud Run       │             │  Exclusion Filters  │ ── Filter ──► Pub/Sub (SIEM/Splunk)
 │ Audit Logs      │             │                     │ ── Default ─► Log Bucket (_Default)
 └─────────────────┘             └─────────────────────┘             └─────────────────────┘
```

#### 1. Default Log Buckets
| Bucket Name | Contents | Retention | Deletable? | Cost |
| :--- | :--- | :--- | :--- | :--- |
| **`_Required`** | Admin Activity audit logs, System Events, Access Transparency | **400 days** | **No** (Cannot be modified, disabled, or deleted) | Free |
| **`_Default`** | Data Access audit logs, GKE stdout/stderr, Compute Engine syslog, VPC Flow Logs | **30 days** (configurable from 1 to 3,650 days) | No (but can disable sinks) | Free tier then \$0.50/GiB |

> [!IMPORTANT]
> **Exam Golden Rule:** You **cannot delete or alter** the `_Required` bucket. It retains security and compliance audit logs for 400 days guaranteed.

#### 2. Log Sinks & Routing
A **Log Sink** exports logs from the Log Router to external storage or tools:
| Destination | Primary Use Case | Required IAM Role for Sink SA |
| :--- | :--- | :--- |
| **Cloud Storage** | Long-term archival, legal compliance (e.g. 7-year audit requirements), lowest cost | `roles/storage.objectCreator` |
| **BigQuery** | Interactive SQL queries, real-time data analytics, Looker Studio dashboards | `roles/bigquery.dataEditor` |
| **Pub/Sub** | Streaming to third-party SIEM (Splunk, Datadog, Elastic) or event-driven Cloud Functions | `roles/pubsub.publisher` |
| **Log Bucket** | Centralized log analysis across multiple GCP projects | `roles/logging.bucketWriter` |

> [!WARNING]
> **Exam Pitfall:** Creating a Log Sink automatically generates a **unique Google service account** (`serviceAccount:service-PROJECT_NUMBER@gcp-sa-logging.iam.gserviceaccount.com`). You **must grant this service account write access** to the destination bucket, dataset, or topic, or log export will silently fail!

#### 3. Log Exclusion Filters (Cost Optimization)
- By default, all ingested logs in `_Default` cost money after the monthly 50 GiB free tier.
- You can create an **Exclusion Filter** to drop high-volume, low-value logs (e.g., debug logs, successful HTTP 200 health checks) before ingestion to save costs while still routing them to a Cloud Storage sink if needed.

---

### 3.2 Log-Based Metrics

When you want to alert on a specific log event (e.g., alert when an application throws `HTTP 500` or a database connection error):

| Metric Type | What It Does | Common Exam Use Case |
| :--- | :--- | :--- |
| **Counter Metric** | Counts the number of matching log entries over time. | Alerting when `jsonPayload.status_code >= 500` occurs more than 5 times in 5 minutes. |
| **Distribution Metric** | Extracts a numerical value from a log field and tracks statistical distributions (p50, p95, p99). | Tracking request latencies from `jsonPayload.latency_ms` or payload sizes. |

---

### 3.3 Cloud Monitoring Architecture & Alerting

#### 1. Core Concepts
- **Metrics Scope (formerly Workspace):** Can monitor up to **375 GCP projects** from a single central host project.
- **Uptime Checks:** Probes configured endpoints from **multiple geographic regions** (Americas, Europe, Asia Pacific) to detect global availability outages. Can check HTTP, HTTPS, or TCP.
- **Alerting Policies:** Composed of:
  1. **Condition:** Threshold (metric exceeds value), Metric Absence (data stops arriving for X minutes), or Rate of change.
  2. **Notification Channel:** Email, PagerDuty, Slack, Webhook, SMS.
  3. **Documentation:** Markdown instructions embedded in the alert to help on-call engineers resolve incidents.

---

### 3.4 Practice Exam Scenarios (ACE & PCA Focus)

#### Question 1 (Log Export & Retention)
> Your company is required by financial regulators to store all Kubernetes container logs and audit logs for 5 years. Logs older than 30 days are rarely accessed. How should you configure your environment with the lowest possible cost?
>
> - **A.** Change the retention period of the `_Default` log bucket to 1,825 days.
> - **B. (Correct)** Create a Log Sink routing all logs to a Cloud Storage bucket configured with Coldline/Archive storage classes and a Lifecycle Rule.
> - **C.** Export all logs to BigQuery and set partition expiration to 5 years.
> - **D.** Deploy a Fluentd daemonset on GKE that writes logs directly to Persistent Volumes.

**Explanation:**
* **B is correct:** Cloud Storage (Coldline / Archive) is the most cost-effective solution for long-term compliance storage where data is rarely accessed.
* **A is incorrect:** Storing logs in Cloud Logging for 5 years is substantially more expensive than Cloud Storage Archive.
* **C is incorrect:** BigQuery storage is more expensive than Cloud Storage Archive and intended for analytics, not cold compliance storage.

---

#### Question 2 (Alerting on Application Errors)
> Your microservice running in GKE logs errors in JSON format with `"severity": "ERROR"`. You want your DevOps team to receive an immediate email whenever more than 10 error entries appear within a 5-minute window. What should you do?
>
> - **A.** Write a bash script on a Compute Engine instance that runs `kubectl logs` every 5 minutes and sends an email via Sendgrid.
> - **B.** Create a Pub/Sub sink that pushes logs to a Cloud Function to send emails.
> - **C. (Correct)** In Cloud Logging, create a user-defined **Counter Log-based Metric** with the filter `severity="ERROR"`. Then create a **Cloud Monitoring Alerting Policy** with a threshold of > 10 for 5 minutes with an Email notification channel.
> - **D.** Configure GKE Horizontal Pod Autoscaler to send an alert email when pods scale up.

**Explanation:**
* **C is correct:** The standard Google Cloud pattern to alert on log content is: **Logs Explorer Filter $\rightarrow$ Log-based Metric $\rightarrow$ Cloud Monitoring Alerting Policy**.
