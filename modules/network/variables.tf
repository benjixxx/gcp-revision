variable "network_name" {
  type        = string
  default     = "main-vpc"
  description = "Name of the VPC network"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for subnetwork and router"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/20"
  description = "Primary CIDR block for the subnetwork"
}

variable "pods_range_name" {
  type        = string
  default     = "gke-pods"
  description = "Name of the secondary range for GKE pods"
}

variable "pods_cidr" {
  type        = string
  default     = "10.4.0.0/14"
  description = "Secondary CIDR block for GKE pods"
}

variable "services_range_name" {
  type        = string
  default     = "gke-services"
  description = "Name of the secondary range for GKE services"
}

variable "services_cidr" {
  type        = string
  default     = "10.8.0.0/20"
  description = "Secondary CIDR block for GKE services"
}

