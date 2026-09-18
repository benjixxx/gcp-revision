output "terraform_service_account_email" {
  description = "Email address of the provisioned Terraform Service Account"
  value       = google_service_account.terraform_sa.email
}

output "terraform_service_account_name" {
  description = "Full resource name of the Terraform Service Account"
  value       = google_service_account.terraform_sa.name
}

output "assigned_roles" {
  description = "Complete list of IAM roles bound across the specified services"
  value       = local.terraform_roles
}

output "bound_personal_user" {
  description = "Personal Google user account bound to the roles"
  value       = var.personal_user_email
}

output "github_service_account_email" {
  description = "Email of the GitHub Actions Service Account"
  value       = google_service_account.github_sa.email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider resource name for keyless GitHub Actions auth"
  value       = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id}"
}

