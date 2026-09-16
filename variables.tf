variable "project_id" {
  type        = string
  description = "myproject-329912"
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