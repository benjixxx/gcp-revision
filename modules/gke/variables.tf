variable "cluster_name" {
  type        = string
  default     = "main-gke-cluster"
  description = "Name of the GKE cluster"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region for regional GKE cluster"
}

variable "network_id" {
  type        = string
  description = "Host VPC network ID"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnetwork where GKE nodes will be provisioned"
}

variable "pods_range_name" {
  type        = string
  default     = "gke-pods"
  description = "Secondary range name for Pods"
}

variable "services_range_name" {
  type        = string
  default     = "gke-services"
  description = "Secondary range name for Services"
}

variable "service_account_email" {
  type        = string
  description = "Service Account email assigned to the worker nodes"
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Number of nodes per zone in the node pool"
}

variable "machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Machine type for the worker nodes"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

