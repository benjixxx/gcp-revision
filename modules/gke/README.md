# GCP GKE Module

This module deploys a VPC-native Google Kubernetes Engine (GKE) cluster. It removes the default node pool on creation and replaces it with a dedicated, customizable node pool.

## Official Documentation
- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [VPC-native Clusters Overview](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)

## Summary of Provisioned Resources
- **`google_container_cluster`**: GKE cluster created with `remove_default_node_pool = true`.
- **`google_container_node_pool`**: Managed node pool utilizing VPC secondary IP ranges.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `cluster_name` | Name of the GKE cluster | `string` |
| `region` | Target GCP region (Regional Cluster) | `string` |
| `network_id` | Host VPC network ID | `string` |
| `subnet_name` | Name of the VPC-native subnetwork | `string` |
| `service_account_email` | Service Account used by cluster nodes | `string` |
| `node_count` | Number of nodes per zone | `number` |
| `machine_type` | Machine type for worker nodes | `string` |

## Outputs
| Name | Description |
| :--- | :--- |
| `cluster_endpoint` | IP endpoint of the Kubernetes API Master |

---

## 20 Essential GCP CLI & kubectl Commands (GKE)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud container clusters list` | List active GKE clusters in the project. |
| `gcloud container clusters get-credentials <NAME> --region=<REGION>` | Fetch cluster credentials and update local `~/.kube/config`. |
| `gcloud container clusters describe <NAME> --region=<REGION>` | Inspect cluster configuration (endpoint, version, addons). |
| `gcloud container node-pools list --cluster=<CLUSTER_NAME>` | List node pools attached to a specific GKE cluster. |
| `gcloud container node-pools resize <POOL_NAME> --cluster=<CLUSTER> --num-nodes=3` | Manually scale the node count of a node pool. |
| `gcloud container clusters delete <NAME> --region=<REGION>` | Delete a GKE cluster and associated infrastructure. |
| `kubectl get nodes -o wide` | List all Kubernetes nodes with internal/external IPs and K8s version. |
| `kubectl get pods -A` | List all running Pods across all namespaces. |
| `kubectl get svc` | List Kubernetes Services and LoadBalancer IP addresses. |
| `kubectl describe pod <POD_NAME>` | Inspect event history and full specs for a specific Pod. |
| `kubectl logs -f <POD_NAME>` | Stream live stdout/stderr logs from a container. |
| `kubectl exec -it <POD_NAME> -- /bin/sh` | Open an interactive shell terminal inside a running Pod container. |
| `kubectl apply -f manifest.yaml` | Apply declarative Kubernetes configurations (Deployments, Services, etc.). |
| `kubectl delete -f manifest.yaml` | Remove resources declared in a manifest file. |
| `kubectl get events --sort-by='.metadata.creationTimestamp'` | Display recent cluster system events chronologically. |
| `--enable-ip-alias` | CLI flag to provision a VPC-native (Alias IP) cluster. |
| `--enable-autoscaling --min-nodes=1 --max-nodes=5` | Configure Cluster Autoscaler limits on a node pool. |
| `--enable-private-nodes` | Provision GKE worker nodes without public IP addresses. |
| `--spot` or `--preemptible` | Use Spot/Preemptible VMs for up to 80% node cost reduction. |
| `gcloud services enable container.googleapis.com` | Enable the Kubernetes Engine API. |