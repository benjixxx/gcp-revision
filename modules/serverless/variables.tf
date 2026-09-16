variable "service_name" {
  type        = string
  default     = "serverless-api"
  description = "Name of the Cloud Run service"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Target GCP region"
}

variable "container_image" {
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
  description = "Docker image URI to deploy to Cloud Run"
}

variable "service_account_email" {
  type        = string
  description = "Runtime identity Service Account email"
}

variable "allow_unauthenticated" {
  type        = bool
  default     = true
  description = "Whether to allow unauthenticated public HTTP requests"
}

variable "min_instances" {
  type        = number
  default     = 0
  description = "Minimum number of container instances (0 for scale-to-zero)"
}

variable "max_instances" {
  type        = number
  default     = 3
  description = "Maximum number of container instances"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

