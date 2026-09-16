output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.name
}

output "service_url" {
  description = "Generated HTTPS endpoint URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_id" {
  description = "Unique resource identifier of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.id
}

