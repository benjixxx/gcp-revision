output "network_id" {
  description = "The ID of the created VPC network"
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "The name of the created VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_id" {
  description = "The ID of the created subnetwork"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "The name of the created subnetwork"
  value       = google_compute_subnetwork.subnet.name
}

output "pods_range_name" {
  description = "Secondary range name for GKE Pods"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE Services"
  value       = var.services_range_name
}

