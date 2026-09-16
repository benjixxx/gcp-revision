# GCP IAM Module
# GCP IAM & Service Account Module

This module instantiates a dedicated GCP Service Account and binds specified IAM roles following the Principle of Least Privilege.
This module provisions a dedicated **Terraform Service Account** and grants full administrative role bindings across essential GCP services for both the **Service Account** and a **Personal Google Account**, implementing non-authoritative bindings (`google_project_iam_member`) and Service Account Impersonation.

---

## Official Documentation
- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs)
- [Understanding Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [Service Account Impersonation](https://cloud.google.com/iam/docs/impersonating-service-accounts)

## Summary of Provisioned Resources
- **`google_service_account`**: Managed Service Account.
- **`google_project_iam_member`**: IAM role bindings iterated using `for_each`.
---

## Inputs
| Name | Description | Type |
## Provisioned Resources & Services Covered

### 1. Provisioned Resources
- **`google_service_account`**: Dedicated Terraform automation Service Account.
- **`google_project_iam_member`**: Non-authoritative project IAM role bindings for the Service Account and your personal Google account.
- **`google_service_account_iam_member`**: Grants `roles/iam.serviceAccountTokenCreator` and `roles/iam.serviceAccountUser` to your personal account for keyless impersonation.

### 2. Services & Predefined IAM Roles Bound

| GCP Service | Predefined Role | Role Description & Purpose |
| :--- | :--- | :--- |
| `sa_id` | Unique ID for the Service Account | `string` |
| `project_id` | Target GCP Project ID | `string` |
| `roles` | List of IAM roles to assign | `list(string)` |
| **Cloud Storage** | `roles/storage.admin` | Full control over buckets and objects (state storage, data lakes). |
| **BigQuery** | `roles/bigquery.admin` | Full control over datasets, tables, queries, and jobs. |
| **IAM Administration** | `roles/resourcemanager.projectIamAdmin` | Ability to administer and modify project IAM policies and bindings. |
| **Service Accounts** | `roles/iam.serviceAccountAdmin` | Create, update, and manage Service Accounts. |
| **Service Account User** | `roles/iam.serviceAccountUser` | Attach Service Accounts to VMs, Cloud Run, GKE, and Cloud Functions. |
| **GKE (Kubernetes)** | `roles/container.admin` | Full management of Kubernetes clusters, node pools, and workloads. |
| **Pub/Sub** | `roles/pubsub.admin` | Full management of topics, subscriptions, schemas, and message queues. |
| **Cloud Run (Serverless)**| `roles/run.admin` | Full control over Cloud Run services, jobs, and revisions. |
| **Cloud Functions** | `roles/cloudfunctions.admin` | Full control over Cloud Functions deployment and management. |
| **Compute Engine** | `roles/compute.admin` | Full control over Virtual Machines, disks, networks, firewalls, and MIGs. |

## Outputs
---

## Inputs & Outputs

### Inputs
| Name | Description | Type | Default |
| :--- | :--- | :--- | :--- |
| `project_id` | Target GCP Project ID | `string` | *(Required)* |
| `sa_id` | Unique account ID for the Terraform Service Account | `string` | `"terraform-sa"` |
| `personal_user_email` | Personal Google user email to bind to roles & impersonation | `string` | `"benjamin.laurent59@gmail.com"` |
| `additional_roles` | Optional list of extra roles to bind | `list(string)` | `[]` |

### Outputs
| Name | Description |
| :--- | :--- |
| `sa_email` | Email address of the generated Service Account |
| `terraform_service_account_email` | Email address of the generated Terraform Service Account |
| `terraform_service_account_name` | Full resource name of the Service Account |
| `assigned_roles` | Complete list of all bound IAM roles |
| `bound_personal_user` | The personal account email receiving the bindings |

---

## 20 Essential GCP CLI Commands & Syntax (IAM & Security)
## Best Practice: Using Service Account Impersonation

Instead of generating and downloading vulnerable static JSON keys (`key.json`), use **Service Account Impersonation**.

### How to Authenticate with Impersonation

1. Log in with your personal Google account:
   ```bash
   gcloud auth login
   ```

2. Configure gcloud or Terraform to impersonate the Terraform Service Account:
   ```bash
   # Run gcloud commands as the Terraform Service Account:
   gcloud compute instances list --impersonate-service-account=terraform-sa@<PROJECT_ID>.iam.gserviceaccount.com
   ```

3. In Terraform, configure the Google provider to impersonate the Service Account:
   ```hcl
   provider "google" {
     impersonate_service_account = "terraform-sa@<PROJECT_ID>.iam.gserviceaccount.com"
   }
   ```

---

## 20 Essential GCP CLI Commands (IAM & Security)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud iam service-accounts list` | List all Service Accounts in the active project. |
| `gcloud iam service-accounts create <SA_NAME>` | Create a new Service Account. |
| `gcloud iam service-accounts describe <SA_EMAIL>` | Display metadata for a specific Service Account. |
| `gcloud iam service-accounts keys list --iam-account=<SA_EMAIL>` | List active keys associated with a Service Account. |
| `gcloud iam service-accounts keys create key.json --iam-account=<SA_EMAIL>` | Generate and download a private JSON key file. |
| `gcloud projects get-iam-policy <PROJECT_ID>` | Export the project-level IAM policy in YAML/JSON format. |
| `gcloud projects add-iam-policy-binding <PROJECT_ID> --member=... --role=...` | Add an IAM role binding to a user, group, or Service Account. |
| `gcloud projects add-iam-policy-binding <PROJECT_ID> --member="serviceAccount:<SA_EMAIL>" --role="roles/storage.admin"` | Add an IAM role binding to a Service Account. |
| `gcloud projects add-iam-policy-binding <PROJECT_ID> --member="user:<USER_EMAIL>" --role="roles/run.admin"` | Add an IAM role binding to your personal Google account. |
| `gcloud projects remove-iam-policy-binding <PROJECT_ID> --member=... --role=...` | Remove an IAM role binding from a member. |
| `gcloud iam service-accounts add-iam-policy-binding <SA_EMAIL> --member="user:<USER_EMAIL>" --role="roles/iam.serviceAccountTokenCreator"` | Grant impersonation rights to a user without JSON keys. |
| `gcloud iam roles list` | List all predefined GCP IAM roles. |
| `gcloud iam roles describe <ROLE_NAME>` | View individual permissions granted by a specific role. |
| `gcloud auth list` | Display active user accounts and Service Accounts authenticated locally. |
| `gcloud auth list` | Display active accounts authenticated locally. |
| `gcloud auth application-default login` | Generate Application Default Credentials (ADC) for local dev. |
| `gcloud config set account <ACCOUNT_EMAIL>` | Switch active gcloud account context. |
| `gcloud iam service-accounts disable <SA_EMAIL>` | Temporarily disable a Service Account. |
| `gcloud iam service-accounts delete <SA_EMAIL>` | Permanently delete a Service Account. |
| `--member="serviceAccount:<SA_EMAIL>"` | Member syntax for targeting a Service Account in IAM bindings. |
| `--member="user:<USER_EMAIL>"` | Member syntax for targeting a Google user account. |
| `--member="group:<GROUP_EMAIL>"` | Member syntax for targeting a Google Group. |
| `--role="roles/viewer"` | Role assignment syntax for the predefined Viewer role. |
| `gcloud services enable iam.googleapis.com` | Enable the Identity and Access Management (IAM) API. |
| `gcloud asset search-all-iam-policies --scope=projects/<PROJECT_ID> --query="policy:<USER_EMAIL>"` | Search all IAM policies assigned to a specific user. |