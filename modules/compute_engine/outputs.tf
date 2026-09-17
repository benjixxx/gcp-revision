# ==============================================================================
# VM Instance Outputs
# ==============================================================================
output "instance_id" {
  description = "The server-assigned unique identifier of the VM instance"
  value       = google_compute_instance.vm_instance.instance_id
}

output "instance_name" {
  description = "The name of the VM instance"
  value       = google_compute_instance.vm_instance.name
}

output "internal_ip" {
  description = "The primary internal IP address of the instance"
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
}

output "external_ip" {
  description = "The external IP address of the instance (if enabled)"
  value       = try(google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip, null)
}

output "self_link" {
  description = "The URI of the instance"
  value       = google_compute_instance.vm_instance.self_link
}

# ==============================================================================
# Load Balancer & MIG Outputs (Available when enable_load_balancer = true)
# ==============================================================================
output "load_balancer_ip" {
  description = "Permanent Public Frontend IP address of the Cloud Load Balancer (Port 80)"
  value       = try(google_compute_global_forwarding_rule.app_forwarding_rule[0].ip_address, null)
}

output "mig_instance_group" {
  description = "The instance group URI of the Managed Instance Group"
  value       = try(google_compute_instance_group_manager.app_mig[0].instance_group, null)
}

output "mig_name" {
  description = "The name of the Managed Instance Group"
  value       = try(google_compute_instance_group_manager.app_mig[0].name, null)
}
