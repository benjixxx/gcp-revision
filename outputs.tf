# ==============================================================================
# Root Outputs: Aggregated Module Exports
# ==============================================================================

# IAM
output "terraform_service_account_email" {
  description = "Email of the Terraform service account"
  value       = module.iam.terraform_service_account_email
}

output "bound_personal_user" {
  description = "Personal user bound to the IAM roles"
  value       = module.iam.bound_personal_user
}

# Network
output "network_id" {
  description = "VPC Network ID"
  value       = module.network.network_id
}

output "subnet_id" {
  description = "Primary Subnet ID"
  value       = module.network.subnet_id
}

# Cloud Storage (Disabled)
# output "storage_bucket_url" {
#   description = "Cloud Storage Bucket URI"
#   value       = module.cloud_storage.bucket_url
# }

# Compute Engine
output "compute_instance_internal_ip" {
  description = "Internal IP address of the Compute Engine instance"
  value       = module.compute_engine.internal_ip
}

output "load_balancer_ip" {
  description = "Permanent Public Frontend IP address of the Cloud Load Balancer"
  value       = module.compute_engine.load_balancer_ip
}

# GKE (Disabled)
# output "gke_cluster_endpoint" {
#   description = "Kubernetes master API endpoint"
#   value       = module.gke.cluster_endpoint
# }

# Serverless (Cloud Run) (Disabled)
# output "serverless_service_url" {
#   description = "Cloud Run service URL"
#   value       = module.serverless.service_url
# }

# BigQuery (Disabled)
# output "bigquery_dataset_id" {
#   description = "BigQuery dataset ID"
#   value       = module.bigquery.dataset_id
# }

# output "bigquery_table_id" {
#   description = "BigQuery table ID"
#   value       = module.bigquery.table_id
# }

