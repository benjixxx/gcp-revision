output "bucket_name" {
  description = "Name of the provisioned GCS bucket"
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "The URI of the bucket in the format gs://<bucket_name>"
  value       = google_storage_bucket.bucket.url
}

output "bucket_self_link" {
  description = "The URI of the created resource"
  value       = google_storage_bucket.bucket.self_link
}

