variable "dataset_id" {
  type        = string
  default     = "analytics_dw"
  description = "Unique ID for the BigQuery analytics dataset"
}

variable "location" {
  type        = string
  default     = "EU"
  description = "Geographic location for data storage"
}

variable "table_id" {
  type        = string
  default     = "transactions"
  description = "BigQuery table identifier"
}

variable "partition_field" {
  type        = string
  default     = "transaction_timestamp"
  description = "Timestamp/Date column used for table partitioning"
}

variable "clustering_fields" {
  type        = list(string)
  default     = ["customer_id", "status"]
  description = "Columns used for clustering (up to 4)"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

variable "logging_dataset_id" {
  type        = string
  default     = "k8s_logs"
  description = "Unique ID for the BigQuery dataset storing GKE container logs"
}

variable "logging_dataset_name" {
  type        = string
  default     = "GKE Container Logs"
  description = "Human-readable display name for the logging dataset"
}

variable "logging_table_expiration_days" {
  type        = number
  default     = 30
  description = "Number of days before partitioned log tables expire (null for indefinite retention)"
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = true
  description = "Whether to delete all tables in datasets upon destruction"
}
