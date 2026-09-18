# ==============================================================================
# Logging & Monitoring Module - Variables
# ==============================================================================

variable "project_id" {
  type        = string
  description = "Target Google Cloud Project ID"
}

variable "dataset_id" {
  type        = string
  default     = "k8s_logs"
  description = "ID of the BigQuery destination dataset (managed by the BigQuery module)"
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
