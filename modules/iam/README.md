# GCP IAM Module

This module instantiates a dedicated GCP Service Account and binds specified IAM roles following the Principle of Least Privilege.

## Official Documentation
- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs)
- [Understanding Service Accounts](https://cloud.google.com/iam/docs/service-accounts)

## Summary of Provisioned Resources
- **`google_service_account`**: Managed Service Account.
- **`google_project_iam_member`**: IAM role bindings iterated using `for_each`.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `sa_id` | Unique ID for the Service Account | `string` |
| `project_id` | Target GCP Project ID | `string` |
| `roles` | List of IAM roles to assign | `list(string)` |

## Outputs
| Name | Description |
| :--- | :--- |
| `sa_email` | Email address of the generated Service Account |

---

## 20 Essential GCP CLI Commands & Syntax (IAM & Security)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud iam service-accounts list` | List all Service Accounts in the active project. |
| `gcloud iam service-accounts create <SA_NAME>` | Create a new Service Account. |
| `gcloud iam service-accounts describe <SA_EMAIL>` | Display metadata for a specific Service Account. |
| `gcloud iam service-accounts keys list --iam-account=<SA_EMAIL>` | List active keys associated with a Service Account. |
| `gcloud iam service-accounts keys create key.json --iam-account=<SA_EMAIL>` | Generate and download a private JSON key file. |
| `gcloud projects get-iam-policy <PROJECT_ID>` | Export the project-level IAM policy in YAML/JSON format. |
| `gcloud projects add-iam-policy-binding <PROJECT_ID> --member=... --role=...` | Add an IAM role binding to a user, group, or Service Account. |
| `gcloud projects remove-iam-policy-binding <PROJECT_ID> --member=... --role=...` | Remove an IAM role binding from a member. |
| `gcloud iam roles list` | List all predefined GCP IAM roles. |
| `gcloud iam roles describe <ROLE_NAME>` | View individual permissions granted by a specific role. |
| `gcloud auth list` | Display active user accounts and Service Accounts authenticated locally. |
| `gcloud auth application-default login` | Generate Application Default Credentials (ADC) for local dev. |
| `gcloud config set account <ACCOUNT_EMAIL>` | Switch active gcloud account context. |
| `gcloud iam service-accounts disable <SA_EMAIL>` | Temporarily disable a Service Account. |
| `gcloud iam service-accounts delete <SA_EMAIL>` | Permanently delete a Service Account. |
| `--member="serviceAccount:<SA_EMAIL>"` | Member syntax for targeting a Service Account in IAM bindings. |
| `--member="user:<USER_EMAIL>"` | Member syntax for targeting a Google user account. |
| `--member="group:<GROUP_EMAIL>"` | Member syntax for targeting a Google Group. |
| `--role="roles/viewer"` | Role assignment syntax for the predefined Viewer role. |
| `gcloud services enable iam.googleapis.com` | Enable the Identity and Access Management (IAM) API. |