# ==============================================================================
# Logging & Monitoring Module - Outputs
# ==============================================================================

output "sink_name" {
  description = "The name of the Cloud Logging sink"
  value       = google_logging_project_sink.k8s_sink.name
}

output "sink_writer_identity" {
  description = "The service account identity created by Cloud Logging to write logs into BigQuery"
  value       = google_logging_project_sink.k8s_sink.writer_identity
}

output "destination_table" {
  description = "The full BigQuery table path where partitioned GKE container logs are written"
  value       = "${var.project_id}.${var.dataset_id}.k8s_container"
}
