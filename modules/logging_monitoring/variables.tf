# ==============================================================================
# Logging & Monitoring Module - Variables
# ==============================================================================

variable "project_id" {
  type        = string
  description = "Target Google Cloud Project ID"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment tag (dev, staging, prod)"
}

variable "location" {
  type        = string
  default     = "EU"
  description = "Geographic location for the BigQuery dataset (e.g., EU, US, europe-west1)"
}

variable "dataset_id" {
  type        = string
  default     = "k8s_logs"
  description = "Unique identifier for the BigQuery dataset storing GKE logs"
}

variable "dataset_name" {
  type        = string
  default     = "GKE Container Logs"
  description = "Human-readable display name for the BigQuery dataset"
}

variable "default_table_expiration_days" {
  type        = number
  default     = 30
  description = "Number of days before partitioned log tables expire (null for indefinite retention)"
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = true
  description = "Whether to delete all tables and data in the dataset when destroying via Terraform"
}

variable "sink_name" {
  type        = string
  default     = "k8s-to-bigquery"
  description = "Name of the Cloud Logging project-level sink"
}

variable "log_filter" {
  type        = string
  default     = "resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"quality-air\""
  description = "Cloud Logging query filter selecting which logs are routed to BigQuery"
}

