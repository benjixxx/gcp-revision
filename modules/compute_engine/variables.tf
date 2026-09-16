variable "instance_name" {
  type        = string
  default     = "bastion-vm"
  description = "Name of the Compute Engine instance"
}

variable "machine_type" {
  type        = string
  default     = "e2-micro"
  description = "Compute Engine machine type"
}

variable "zone" {
  type        = string
  default     = "europe-west1-b"
  description = "GCP zone for the VM"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnetwork where the VM will be attached"
}

variable "service_account_email" {
  type        = string
  description = "Service account email attached to the instance"
}

variable "os_image" {
  type        = string
  default     = "debian-cloud/debian-12"
  description = "Operating system boot image"
}

variable "disk_size" {
  type        = number
  default     = 20
  description = "Size of the boot disk in GB"
}

variable "enable_public_ip" {
  type        = bool
  default     = false
  description = "Whether to assign a public IP address (default false, access via IAP)"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"
}

