variable "dataset_id" {
  type        = string
  default     = "analytics_dw"
  description = "Unique ID for the BigQuery dataset"
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

