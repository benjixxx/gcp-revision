output "dataset_id" {
  description = "The ID of the BigQuery analytics dataset"
  value       = google_bigquery_dataset.dataset.dataset_id
}

output "table_id" {
  description = "The ID of the BigQuery table"
  value       = google_bigquery_table.table.table_id
}

output "table_self_link" {
  description = "URI of the created table"
  value       = google_bigquery_table.table.self_link
}

output "logging_dataset_id" {
  description = "The ID of the BigQuery dataset dedicated to GKE container logs"
  value       = google_bigquery_dataset.k8s_logs.dataset_id
}

output "logging_dataset_location" {
  description = "Geographic location of the logging BigQuery dataset"
  value       = google_bigquery_dataset.k8s_logs.location
}
