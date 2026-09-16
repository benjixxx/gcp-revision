# GCP Storage Module

This module provisions a secure Google Cloud Storage (GCS) bucket featuring object versioning, public access prevention, and Uniform Bucket-Level Access.

## Official Documentation
- [Google Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Securing Cloud Storage Buckets](https://cloud.google.com/storage/docs/security-controls)

## Summary of Provisioned Resources
- **`google_storage_bucket`**: Secured and encrypted Cloud Storage bucket.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `bucket_name` | Globally unique name for the storage bucket | `string` |
| `location` | Geographic location (e.g., `europe-west1`) | `string` |

## Outputs
| Name | Description |
| :--- | :--- |
| `bucket_name` | Name of the provisioned GCS bucket |

---

## 20 Essential GCP CLI Commands & Syntax (Cloud Storage)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud storage buckets list` | List all GCS buckets in the project. |
| `gcloud storage buckets create gs://<BUCKET_NAME>` | Create a new Cloud Storage bucket. |
| `gcloud storage buckets describe gs://<BUCKET_NAME>` | View bucket details (location, storage class, IAM). |
| `gcloud storage ls gs://<BUCKET_NAME>` | List objects and folders at the bucket root. |
| `gcloud storage cp <LOCAL_FILE> gs://<BUCKET_NAME>` | Upload a local file to a GCS bucket. |
| `gcloud storage cp gs://<BUCKET_NAME>/file.txt .` | Download a file from GCS to the local directory. |
| `gcloud storage rsync -r <LOCAL_DIR> gs://<BUCKET_NAME>` | Mirror a local directory with a GCS bucket. |
| `gcloud storage rm gs://<BUCKET_NAME>/<FILE>` | Delete a specific file from a bucket. |
| `gcloud storage rm -r gs://<BUCKET_NAME>` | Recursively delete a bucket and all its contents. |
| `gcloud storage buckets update gs://<BUCKET_NAME> --versioning` | Enable object versioning on a bucket. |
| `gcloud storage buckets update gs://<BUCKET_NAME> --no-public-access-prevention` | Manage public access prevention settings. |
| `gcloud storage buckets add-iam-policy-binding gs://<BUCKET_NAME> --member=... --role=...` | Bind an IAM role directly to a bucket. |
| `gcloud storage cat gs://<BUCKET_NAME>/<FILE>` | Output text file content directly to stdout without saving locally. |
| `gcloud storage du -s gs://<BUCKET_NAME>` | Display total disk usage of a bucket. |
| `gsutil ls -a gs://<BUCKET_NAME>` | List all archived object versions (legacy `gsutil` tool). |
| `gs://<BUCKET_NAME>/<PATH>` | Universal GCS URI scheme format. |
| `--location=europe-west1` | Flag setting the regional placement of data. |
| `--default-storage-class=NEARLINE` | Set default storage class (Standard, Nearline, Coldline, Archive). |
| `--recursive` or `-r` | Execution flag for folder-level operations. |
| `gcloud services enable storage.googleapis.com` | Enable the Cloud Storage API. |