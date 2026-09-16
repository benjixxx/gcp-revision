variable "project_id" {
  type        = string
  description = "ID project GCP"

}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Région principale pour les ressources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environnement de déploiement"
}

variable "sa_id" {
  description = "Terraform service account ID"
  type        = string
}

variable "personal_user_email" {
  description = "Personal user email authorized to impersonate the service account"
  type        = string
}

variable "additional_roles" {
  description = "Additional IAM roles assigned to the Terraform service account"
  type        = list(string)
  default     = []
}