# GCP Certification Exam Notes & Key Topics

This document is a consolidated revision guide covering specific GCP exam topics, edge cases, and architectural best practices.

---

## Table of Contents
1. [Resource Management: Project Liens](#1-resource-management-project-liens)
2. [Serverless Compute: App Engine (Standard vs. Flexible)](#2-serverless-compute-app-engine-standard-vs-flexible)

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
