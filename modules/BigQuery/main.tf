# ==============================================================================
# 1. Analytics Dataset & Table
# ==============================================================================
resource "google_bigquery_dataset" "dataset" {
  dataset_id                  = var.dataset_id
  friendly_name               = "Analytics Dataset"
  description                 = "Central dataset for analytics and reporting"
  location                    = var.location
  default_table_expiration_ms = null
  delete_contents_on_destroy  = var.delete_contents_on_destroy

  labels = {
    env = var.environment
  }
}

resource "google_bigquery_table" "table" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = var.table_id
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = var.partition_field
  }

  clustering = var.clustering_fields

  schema = <<EOF
[
  {
    "name": "transaction_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Unique transaction identifier"
  },
  {
    "name": "customer_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Customer identifier"
  },
  {
    "name": "amount",
    "type": "NUMERIC",
    "mode": "REQUIRED",
    "description": "Transaction amount in EUR"
  },
  {
    "name": "status",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Transaction status (COMPLETED, PENDING, FAILED)"
  },
  {
    "name": "transaction_timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Timestamp of the transaction"
  }
]
EOF
}

# ==============================================================================
# 2. GKE Container Logs Dataset (Observability & SRE Sink Target)
# ==============================================================================
resource "google_bigquery_dataset" "k8s_logs" {
  dataset_id                  = var.logging_dataset_id
  friendly_name               = var.logging_dataset_name
  description                 = "Streamed GKE container logs from Cloud Logging for SRE observability"
  location                    = var.location
  default_table_expiration_ms = var.logging_table_expiration_days != null ? var.logging_table_expiration_days * 86400000 : null
  delete_contents_on_destroy  = var.delete_contents_on_destroy

  labels = {
    env = var.environment
  }
}
