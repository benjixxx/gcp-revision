# ==============================================================================
# Global & Provider Variables
# ==============================================================================
variable "project_id" {
  type        = string
  description = "Target GCP Project ID"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Default GCP region for resources"
}

variable "zone" {
  type        = string
  default     = "europe-west1-b"
  description = "Default GCP zone for zonal compute resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment (dev, staging, prod)"
}

# ==============================================================================
# IAM Variables
# ==============================================================================
variable "sa_id" {
  type        = string
  default     = "terraform"
  description = "Terraform service account ID"
}

variable "personal_user_email" {
  type        = string
  description = "Personal user email authorized to receive role bindings and impersonate the service account"
}

variable "additional_roles" {
  type        = list(string)
  default     = []
  description = "Additional IAM roles assigned to the Terraform service account and personal user"
}

# ==============================================================================
# Network Variables
# ==============================================================================
variable "network_name" {
  type        = string
  default     = "main-vpc"
  description = "Name of the custom VPC network"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/20"
  description = "Primary CIDR block for the subnetwork"
}

variable "pods_range_name" {
  type        = string
  default     = "gke-pods"
  description = "Secondary IP range name for GKE Pods"
}

variable "pods_cidr" {
  type        = string
  default     = "10.4.0.0/14"
  description = "Secondary IP CIDR range for GKE Pods"
}

variable "services_range_name" {
  type        = string
  default     = "gke-services"
  description = "Secondary IP range name for GKE Services"
}

variable "services_cidr" {
  type        = string
  default     = "10.8.0.0/20"
  description = "Secondary IP CIDR range for GKE Services"
}

# ==============================================================================
# Cloud Storage Variables
# ==============================================================================
variable "bucket_name" {
  type        = string
  description = "Globally unique name for the Cloud Storage bucket"
}

variable "bucket_versioning" {
  type        = bool
  default     = true
  description = "Enable object versioning on the GCS bucket"
}

# ==============================================================================
# Compute Engine Variables
# ==============================================================================
variable "instance_name" {
  type        = string
  default     = "bastion-vm"
  description = "Name of the Compute Engine VM instance"
}

variable "compute_machine_type" {
  type        = string
  default     = "e2-micro"
  description = "Machine type for the Compute Engine instance"
}

variable "enable_load_balancer" {
  type        = bool
  default     = false
  description = "Whether to create a Managed Instance Group with an HTTP Load Balancer instead of a single standalone VM"
}

variable "mig_target_size" {
  type        = number
  default     = 3
  description = "Target number of instances in the Managed Instance Group"
}

# ==============================================================================
# GKE Variables
# ==============================================================================
variable "cluster_name" {
  type        = string
  default     = "main-gke-cluster"
  description = "Name of the GKE cluster"
}

variable "gke_node_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes per zone in the GKE node pool"
}

variable "gke_min_node_count" {
  type        = number
  default     = 1
  description = "Minimum number of worker nodes per zone in the GKE node pool"
}

variable "gke_max_node_count" {
  type        = number
  default     = 5
  description = "Maximum number of worker nodes per zone in the GKE node pool"
}

variable "gke_machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Machine type for the GKE worker nodes"
}

# ==============================================================================
# Serverless (Cloud Run) Variables
# ==============================================================================
variable "serverless_service_name" {
  type        = string
  default     = "cloud-run-service"
  description = "Name of the Cloud Run service"
}

variable "serverless_container_image" {
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
  description = "Container image URI for Cloud Run deployment"
}

variable "serverless_allow_unauthenticated" {
  type        = bool
  default     = true
  description = "Whether to allow unauthenticated public HTTP traffic to Cloud Run"
}

variable "serverless_min_instances" {
  type        = number
  default     = 0
  description = "Minimum number of Cloud Run instances (0 for scale-to-zero)"
}

variable "serverless_max_instances" {
  type        = number
  default     = 3
  description = "Maximum number of Cloud Run instances"
}

# ==============================================================================
# BigQuery Variables
# ==============================================================================
variable "bigquery_dataset_id" {
  type        = string
  default     = "analytics_dw"
  description = "Unique ID for the BigQuery dataset"
}

variable "bigquery_location" {
  type        = string
  default     = "EU"
  description = "Geographic location for BigQuery data storage"
}

variable "bigquery_table_id" {
  type        = string
  default     = "transactions"
  description = "BigQuery table identifier"
}

variable "bigquery_partition_field" {
  type        = string
  default     = "transaction_timestamp"
  description = "Column used for time-unit partitioning"
}

variable "bigquery_clustering_fields" {
  type        = list(string)
  default     = ["customer_id", "status"]
  description = "Columns used for clustering (up to 4)"
}

# ==============================================================================
# Cloud SQL (PostgreSQL) Variables
# ==============================================================================
variable "db_instance_name" {
  type        = string
  default     = "quality-air-db"
  description = "Base instance name for the PostgreSQL Cloud SQL database"
}

variable "db_version" {
  type        = string
  default     = "POSTGRES_15"
  description = "Database engine version for PostgreSQL"
}

variable "db_tier" {
  type        = string
  default     = "db-f1-micro"
  description = "Cloud SQL machine tier (e.g. db-f1-micro for dev, db-custom-1-3840 for prod)"
}

variable "db_disk_size_gb" {
  type        = number
  default     = 10
  description = "Disk size in GB for the Cloud SQL instance"
}

variable "db_disk_type" {
  type        = string
  default     = "PD_SSD"
  description = "Storage type for database: PD_SSD or PD_HDD"
}

variable "db_availability_type" {
  type        = string
  default     = "ZONAL"
  description = "High availability configuration: ZONAL or REGIONAL"
}

variable "db_deletion_protection" {
  type        = bool
  default     = false
  description = "Prevent accidental deletion via Terraform"
}

variable "db_enable_backup" {
  type        = bool
  default     = false
  description = "Enable automated daily backups"
}

variable "db_enable_public_ip" {
  type        = bool
  default     = true
  description = "Enable public IP access to the database"
}

variable "db_enable_private_ip" {
  type        = bool
  default     = false
  description = "Enable private VPC network access for Cloud SQL"
}

variable "db_name" {
  type        = string
  default     = "quality_air_db"
  description = "Name of the initial application PostgreSQL database"
}

variable "db_user" {
  type        = string
  default     = "quality_air_admin"
  description = "Initial PostgreSQL database username"
}

variable "db_password" {
  type        = string
  default     = "QualityAir2026!ChangeMe"
  sensitive   = true
  description = "Initial PostgreSQL user password"
}