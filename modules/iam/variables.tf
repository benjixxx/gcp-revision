variable "project_id" {
  type        = string
  description = "Target GCP Project ID where roles and Service Account are provisioned"
}

variable "sa_id" {
  type        = string
  description = "Unique ID / name for the Terraform Service Account"
}

variable "personal_user_email" {
  type        = string
  description = "Personal Google account email to receive direct role bindings and impersonation permissions"
}

variable "additional_roles" {
  type        = list(string)
  default     = []
  description = "Optional additional roles to bind to the Terraform SA and personal account"
}

