# ==============================================================================
# Logging & Monitoring Module - Main
# Provisions:
# 1. Cloud Logging Project Sink with Date Partitioning (routes to BigQuery)
# 2. IAM Role Binding granting BigQuery Data Editor to the Sink Writer Identity
# ==============================================================================

# 1. Cloud Logging Project Sink
resource "google_logging_project_sink" "k8s_sink" {
  name        = var.sink_name
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${var.dataset_id}"
  filter      = var.log_filter

  # Generates a dedicated service account for writing to the destination
  unique_writer_identity = true

  bigquery_options {
    # Partitioned tables create a single daily partitioned table (k8s_container)
    # instead of legacy date-sharded tables (k8s_container_YYYYMMDD)
    use_partitioned_tables = true
  }
}

# 2. IAM Binding: Grant Sink Writer Identity permission to insert rows into BigQuery
resource "google_project_iam_member" "sink_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.k8s_sink.writer_identity
}
