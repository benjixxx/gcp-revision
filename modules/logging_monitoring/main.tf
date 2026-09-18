# ==============================================================================
# Logging & Monitoring Module - Main
# Provisions:
# 1. BigQuery Dataset for GKE Container Logs
# 2. Cloud Logging Project Sink with Date Partitioning
# 3. IAM Role Binding granting BigQuery Data Editor to the Sink Writer Identity
# ==============================================================================

# 1. BigQuery Dataset
resource "google_bigquery_dataset" "k8s_logs" {
  dataset_id                  = var.dataset_id
  friendly_name               = var.dataset_name
  description                 = "Streamed GKE container logs from Cloud Logging for SRE observability"
  location                    = var.location
  default_table_expiration_ms = var.default_table_expiration_days != null ? var.default_table_expiration_days * 86400000 : null
  delete_contents_on_destroy  = var.delete_contents_on_destroy

  labels = {
    env = var.environment
  }
}

# 2. Cloud Logging Project Sink
resource "google_logging_project_sink" "k8s_sink" {
  name        = var.sink_name
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.k8s_logs.dataset_id}"
  filter      = var.log_filter

  # Generates a dedicated service account for writing to the destination
  unique_writer_identity = true

  bigquery_options {
    # Partitioned tables create a single daily partitioned table (k8s_container)
    # instead of legacy date-sharded tables (k8s_container_YYYYMMDD)
    use_partitioned_tables = true
  }
}

# 3. IAM Binding: Grant Sink Writer Identity permission to insert rows into BigQuery
resource "google_project_iam_member" "sink_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.k8s_sink.writer_identity
}

