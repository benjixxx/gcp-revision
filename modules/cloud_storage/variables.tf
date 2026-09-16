variable "bucket_name" {
  type        = string
  description = "Globally unique name for the Cloud Storage bucket"
}

variable "location" {
  type        = string
  default     = "europe-west1"
  description = "Geographic location for the bucket"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment tag"
}

variable "versioning" {
  type        = bool
  default     = true
  description = "Whether to enable object versioning"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "When deleting a bucket, this boolean option will delete all contained objects"
}

