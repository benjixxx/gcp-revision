output "cluster_name" {
  description = "Name of the created GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "An identifier for the resource"
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "The IP address of this cluster's Kubernetes master"
  value       = google_container_cluster.primary.endpoint
}

output "node_pool_name" {
  description = "The name of the node pool"
  value       = google_container_node_pool.primary_nodes.name
}

