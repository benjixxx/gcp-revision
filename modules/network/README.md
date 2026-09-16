# GCP Network Module

This module provisions a custom non-automatic VPC network, a subnetwork with secondary IP ranges dedicated to Google Kubernetes Engine (Pods and Services), and a Cloud Router with Cloud NAT to allow outbound internet access for private instances.

## Official Documentation
- [Google Cloud VPC Documentation](https://cloud.google.com/vpc/docs)
- [GKE Cluster Network Configuration](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)
- [Cloud NAT Overview](https://cloud.google.com/nat/docs/overview)

## Summary of Provisioned Resources
- **`google_compute_network`**: Main VPC network in custom subnet mode.
- **`google_compute_subnetwork`**: Subnet configured with secondary ranges (`gke-pods`, `gke-services`).
- **`google_compute_router` & `google_compute_router_nat`**: NAT Gateway for outbound traffic.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `network_name` | Name of the VPC network | `string` |
| `subnet_cidr` | Primary CIDR range for the subnet | `string` |
| `pods_cidr` | Secondary IP range for GKE Pods | `string` |
| `services_cidr` | Secondary IP range for GKE Services | `string` |
| `region` | Target GCP region | `string` |

## Outputs
| Name | Description |
| :--- | :--- |
| `network_id` | ID of the created VPC network |
| `subnet_id` | ID of the created subnetwork |
| `subnet_name` | Name of the created subnetwork |

---

## 20 Essential GCP CLI Commands & Syntax (Networking & VPC)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud compute networks list` | List all VPC networks in the active project. |
| `gcloud compute networks describe <VPC_NAME>` | Display complete configuration details of a specific VPC. |
| `gcloud compute subnets list` | List all subnetworks across all regions in the project. |
| `gcloud compute subnets list --network=<VPC_NAME>` | Filter subnetworks belonging to a specific VPC. |
| `gcloud compute firewall-rules list` | Display all active firewall rules. |
| `gcloud compute firewall-rules describe <RULE_NAME>` | Inspect details of a specific firewall rule (IPs, ports, target tags). |
| `gcloud compute firewall-rules create <NAME> --allow=tcp:80,tcp:443` | Create a firewall rule allowing inbound HTTP/HTTPS traffic. |
| `gcloud compute routers list` | List all Cloud Routers in the project. |
| `gcloud compute routers nats list --router=<ROUTER_NAME>` | Display Cloud NAT configurations attached to a specific router. |
| `gcloud compute addresses list` | List reserved static public and internal IP addresses. |
| `gcloud compute addresses create <NAME> --region=<REGION>` | Reserve a new static external IP address. |
| `gcloud compute routes list` | Display the project's network routing table. |
| `gcloud compute networks subnets get-iam-policy <SUBNET>` | View IAM policies applied to a specific subnetwork. |
| `gcloud compute firewall-rules delete <RULE_NAME>` | Delete a firewall rule. |
| `gcloud compute networks create <NAME> --subnet-mode=custom` | Create a custom-mode VPC network via CLI. |
| `gcloud compute subnets create <NAME> --range=10.0.0.0/24` | Create a subnetwork via CLI. |
| `--format="value(ipAddress)"` | Output flag to extract only the raw IP address string. |
| `--filter="network:<VPC_NAME>"` | Filtering flag to target resources by VPC name. |
| `--allow=tcp:22 --target-tags=ssh-enabled` | Rule target syntax applying only to VMs with the `ssh-enabled` tag. |
| `gcloud services enable compute.googleapis.com` | Enable the Compute Engine / Networking API. |