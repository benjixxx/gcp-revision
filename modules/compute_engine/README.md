# GCP Compute Engine Module

This module provisions a Google Compute Engine (GCE) virtual machine instance attached to a dedicated VPC subnet and run under a specific Service Account.

## Official Documentation
- [Google Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [Creating VM Instances](https://cloud.google.com/compute/docs/instances/create-start-instance)

## Summary of Provisioned Resources
- **`google_compute_instance`**: Compute Engine VM instance running a standard Linux image.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `instance_name` | Name of the VM instance | `string` |
| `machine_type` | Machine type (e.g., `e2-micro`) | `string` |
| `zone` | Target zone (e.g., `europe-west1-a`) | `string` |
| `network_id` | ID of the host VPC network | `string` |
| `subnet_id` | ID of the attached subnetwork | `string` |
| `service_account_email` | Service Account assigned to the VM | `string` |

## Outputs
| Name | Description |
| :--- | :--- |
| `internal_ip` | Private internal IP address assigned to the VM |

---

## 20 Essential GCP CLI Commands & Syntax (Compute Engine)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud compute instances list` | List all VMs in the project with internal and external IPs. |
| `gcloud compute instances describe <VM_NAME> --zone=<ZONE>` | View full configuration details of a VM instance. |
| `gcloud compute instances create <VM_NAME> --zone=<ZONE>` | Create a new Compute Engine VM instance. |
| `gcloud compute ssh <VM_NAME> --zone=<ZONE>` | Open an interactive SSH session to a VM. |
| `gcloud compute instances stop <VM_NAME> --zone=<ZONE>` | Gracefully stop a running VM instance. |
| `gcloud compute instances start <VM_NAME> --zone=<ZONE>` | Start a stopped VM instance. |
| `gcloud compute instances reset <VM_NAME> --zone=<ZONE>` | Hard-reset (reboot) a VM instance. |
| `gcloud compute instances delete <VM_NAME> --zone=<ZONE>` | Permanently delete a VM instance. |
| `gcloud compute machine-types list --zones=<ZONE>` | List machine types available in a specific zone. |
| `gcloud compute images list` | List public OS images available on GCP. |
| `gcloud compute disks list` | List Persistent Disks in the project. |
| `gcloud compute instance-templates list` | List registered Instance Templates. |
| `gcloud compute instance-groups list` | List Managed (MIG) and Unmanaged Instance Groups. |
| `gcloud compute scp local.txt <VM_NAME>:~/ --zone=<ZONE>` | Securely copy files to a VM over SSH. |
| `gcloud compute ssh <VM_NAME> --tunnel-through-iap` | SSH into a private VM without a public IP using Identity-Aware Proxy. |
| `--machine-type=e2-standard-2` | Flag specifying vCPU count and memory size. |
| `--scopes=cloud-platform` | Flag assigning OAuth2 access scopes to the VM. |
| `--tags=http-server,https-server` | Network tags syntax used for firewall rule targeting. |
| `--metadata=startup-script="..."` | Inject a bash script executed on VM boot. |
| `gcloud services enable compute.googleapis.com` | Enable the Compute Engine API. |