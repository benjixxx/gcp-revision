variable "project_id" {
  type        = string
  default= "myproject-329912"
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