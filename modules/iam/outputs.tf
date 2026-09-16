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

