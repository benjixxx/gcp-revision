# GCP GKE Module

This module deploys a VPC-native Google Kubernetes Engine (GKE) cluster. It removes the default node pool on creation and replaces it with a dedicated, customizable node pool.

## Official Documentation
- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [VPC-native Clusters Overview](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)

## Summary of Provisioned Resources
- **`google_container_cluster`**: GKE cluster created with `remove_default_node_pool = true`.
- **`google_container_node_pool`**: Managed node pool utilizing VPC secondary IP ranges.

## Inputs
| Name | Description | Type | Default |
| :--- | :--- | :--- | :--- |
| `cluster_name` | Name of the GKE cluster | `string` | `"main-gke-cluster"` |
| `zone` | Target zone for single-zone low-cost cluster | `string` | `"europe-west1-b"` |
| `network_id` | Host VPC network ID | `string` | - |
| `subnet_name` | Name of the VPC-native subnetwork | `string` | - |
| `service_account_email` | Service Account used by cluster nodes | `string` | - |
| `node_count` | Number of worker nodes | `number` | `1` |
| `machine_type` | Machine type for worker nodes | `string` | `"e2-medium"` |
| `spot` | Use Spot (preemptible) VMs for 60-80% discount | `bool` | `true` |
| `disk_size_gb` | Boot disk size per node (GB) | `number` | `30` |

## Outputs
| Name | Description |
| :--- | :--- |
| `cluster_endpoint` | IP endpoint of the Kubernetes API Master |

---

## 💰 Cost Optimization Architecture (From $328/mo down to ~$10/mo)

By default, GCP estimates GKE at **$328/month** because of multi-zone replication and large default disks. We optimized it for study and lab work:

1. **Single-Zone Cluster (`location = var.zone`)**:
   - Instead of replicating nodes across 3 zones, it runs strictly in `europe-west1-b`.
   - `node_count = 1` creates **exactly 1 VM** instead of 3.
2. **Spot / Preemptible VMs (`spot = true`)**:
   - Saves **60% to 80%** on compute costs.
3. **Small Boot Disks (`disk_size_gb = 30`)**:
   - Replaced GCP's 100 GB default with 30 GB standard persistent disk.
4. **On-Demand Study Workflow**:
   - Spin up when studying: `make apply-gke`
   - Connect kubectl: `gcloud container clusters get-credentials main-gke-cluster --zone=europe-west1-b`
   - Tear down when finished: `make destroy-gke` *(Cost for a 2-hour session: < $0.10)*.

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