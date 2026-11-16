# ==============================================================================
# Database Module Variables
# ==============================================================================

variable "instance_name" {
  type        = string
  description = "Base name for the Cloud SQL PostgreSQL instance"
  default     = "quality-air-db"
}

variable "database_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = "POSTGRES_15"
}

variable "region" {
  type        = string
  description = "GCP region where the database instance will be hosted"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., dev, staging, prod)"
  default     = "dev"
}

variable "tier" {
  type        = string
  description = "Machine type for the Cloud SQL instance (e.g., db-f1-micro, db-custom-1-3840)"
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  type        = number
  description = "Storage disk size in GB"
  default     = 10
}

variable "disk_type" {
  type        = string
  description = "Disk type: PD_SSD or PD_HDD"
  default     = "PD_SSD"
}

variable "availability_type" {
  type        = string
  description = "Availability type: ZONAL or REGIONAL (for high availability)"
  default     = "ZONAL"
}

variable "deletion_protection" {
  type        = bool
  description = "Whether deletion protection is enabled on the instance"
  default     = false
}

variable "enable_backup" {
  type        = bool
  description = "Enable automated daily backups"
  default     = false
}

variable "enable_public_ip" {
  type        = bool
  description = "Assign a public IPv4 address to the database instance"
  default     = true
}

variable "enable_private_ip" {
  type        = bool
  description = "Enable private VPC peering connectivity"
  default     = false
}

variable "network_id" {
  type        = string
  description = "VPC Network ID (required if enable_private_ip is true)"
  default     = null
}

variable "require_ssl" {
  type        = bool
  description = "Require SSL/TLS for all client connections"
  default     = false
}

variable "authorized_networks" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "External CIDR blocks allowed to connect directly to the public IP"
  default     = []
}

variable "database_name" {
  type        = string
  description = "Name of the initial PostgreSQL database to create"
  default     = "quality_air_db"
}

variable "database_user" {
  type        = string
  description = "Username for the primary application database user"
  default     = "quality_air_admin"
}

variable "database_password" {
  type        = string
  description = "Password for the application database user"
  sensitive   = true
  default     = "QualityAir2026!ChangeMe"
}

