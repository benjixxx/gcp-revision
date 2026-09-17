# ==============================================================================
# Standalone VM Outputs (Available when enable_load_balancer = false)
# ==============================================================================
output "instance_id" {
  description = "The server-assigned unique identifier of the standalone instance"
  value       = try(google_compute_instance.vm_instance[0].instance_id, null)
}

output "instance_name" {
  description = "The name of the standalone VM instance"
  value       = try(google_compute_instance.vm_instance[0].name, null)
}

output "internal_ip" {
  description = "The primary internal IP address of the standalone instance"
  value       = try(google_compute_instance.vm_instance[0].network_interface[0].network_ip, null)
}

output "external_ip" {
  description = "The external IP address of the standalone instance"
  value       = try(google_compute_instance.vm_instance[0].network_interface[0].access_config[0].nat_ip, null)
}

output "self_link" {
  description = "The URI of the standalone instance"
  value       = try(google_compute_instance.vm_instance[0].self_link, null)
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
