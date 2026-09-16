output "instance_id" {
  description = "The server-assigned unique identifier of this instance"
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
  description = "The URI of the created instance"
  value       = google_compute_instance.vm_instance.self_link
}

