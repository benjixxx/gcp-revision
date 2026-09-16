# GCP Serverless (Cloud Run) Module

This module deploys a containerized Serverless service onto Cloud Run (v2) with configurable ingress and authentication controls.

## Official Documentation
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run IAM & Security](https://cloud.google.com/run/docs/securing/managing-access)

## Summary of Provisioned Resources
- **`google_cloud_run_v2_service`**: Deployment configuration for the containerized service.

## Inputs
| Name | Description | Type |
| :--- | :--- | :--- |
| `service_name` | Name of the Cloud Run service | `string` |
| `region` | Target GCP region | `string` |
| `container_image` | Docker image URI to deploy | `string` |
| `service_account_email` | Identity Service Account for runtime | `string` |

## Outputs
| Name | Description |
| :--- | :--- |
| `service_url` | Generated HTTPS endpoint URL |

---

## Google App Engine: Standard vs. Flexible Environment

Google App Engine (GAE) is Google Cloud's fully managed Platform-as-a-Service (PaaS). The exam frequently tests your ability to choose between the **Standard** and **Flexible** environments based on architectural and business requirements.

### Quick Comparison Matrix

| Feature / Criteria | App Engine Standard | App Engine Flexible |
| :--- | :--- | :--- |
| **Underlying Runtime** | Pre-configured sandbox environments | Docker containers on Compute Engine VMs |
| **Startup Time** | **Seconds / Milliseconds** (rapid scaling) | **Minutes** (must provision Compute Engine VM) |
| **Scale to Zero?** | ✅ **Yes** (shuts down to 0 instances when idle) | ❌ **No** (minimum 1 instance runs continuously) |
| **Pricing / Free Tier** | Pay-per-instance class; **Free Tier available** | Pay for vCPU, memory, & disk (Compute Engine pricing); **No Free Tier** |
| **Custom Runtimes & Docker** | ❌ No custom Dockerfiles (only supported language runtimes) | ✅ **Yes** (bring your own Dockerfile, any language or binary) |
| **OS / Native Extensions** | No OS access or custom C-libraries | ✅ Full root access to install custom OS packages & C-libraries |
| **SSH Access** | ❌ No SSH access | ✅ **Yes** (can SSH into the VM for troubleshooting) |
| **Local Disk Access** | Read-only filesystem (in-memory `/tmp` only) | Ephemeral disk with read/write access |
| **Background Processes** | Limited, requests have strict deadlines | ✅ Allowed to run long-running background threads & processes |
| **VPC Connectivity** | Requires Serverless VPC Access connector | Direct attachment to VPC network |
| **Network Protocols** | HTTP/HTTPS and WebSockets | HTTP/HTTPS and WebSockets |

---

### Key Decision Rules for the Exam

* **Choose App Engine Standard if:**
  * Your application experiences sudden, unpredictable traffic spikes (needs instantaneous scaling).
  * Minimizing cost is critical and the app needs to **scale to zero** during idle hours.
  * Your application is written in standard versions of Python, Java, Node.js, Go, PHP, or Ruby without native C-extensions.

* **Choose App Engine Flexible if:**
  * You need to run a **custom Docker container** or an unsupported language/runtime.
  * Your application requires **custom OS libraries** or native C-dependencies.
  * You need **SSH access** for deep debugging.
  * You have sustained, consistent traffic and need long-lived background threads or processes.

---

### Essential `gcloud app` Commands

| Command | Purpose |
| :--- | :--- |
| `gcloud app create --region=<REGION>` | Initialize App Engine in the project (can only set region once per project). |
| `gcloud app deploy` | Deploy application code / `app.yaml` to create a new version. |
| `gcloud app deploy --no-promote` | Deploy a new version without routing traffic to it immediately. |
| `gcloud app versions list` | List all deployed versions across services. |
| `gcloud app services set-traffic <SERVICE> --splits=<V1>=0.5,<V2>=0.5` | Split traffic for A/B testing or canary deployments. |
| `gcloud app browse` | Open the deployed application URL in your web browser. |

---

### Real Exam Question & Answer Example

**Question:**
> Google App Engine has a second hosting option, called App Engine Flexible Environment. Which of the following best describes App Engine Flexible Environment?
>
> - **A. (Correct)** The Flexible Environment supports App Engine applications on configurable Compute Engine instances.
> - **B.** The Flexible Environment supports App Engine instances on third-party networks.
> - **C.** The Flexible Environment supports applications on configurable GKE containers.
> - **D.** The Flexible Environment supports managed functions as well as managed instances.

**Correct Answer:** **A**

**Explanation:**
* Google App Engine Flexible Environment runs application containers on **configurable Compute Engine Virtual Machines (VMs)**.
* This VM-based hosting model offers higher flexibility, allowing custom CPU and memory configurations, background processes, custom Docker containers, and SSH access.
* **Why the others are incorrect:**
  * **B** is false: App Engine runs on Google Cloud infrastructure and VPC networks, not third-party networks.
  * **C** is false: While Flexible uses Docker containers, they are orchestrated directly on Compute Engine VMs, **not** on GKE (Google Kubernetes Engine).
  * **D** is false: Managed functions are part of Cloud Functions / Cloud Run functions, not App Engine Flexible.

* Reference: [Google App Engine Flexible Environment Documentation](https://cloud.google.com/appengine/docs/flexible/)

---

## 20 Essential GCP CLI Commands & Syntax (Cloud Run & Serverless)

| Command / Syntax | Description & Use Case |
| :--- | :--- |
| `gcloud run services list` | List all Cloud Run services in the project. |
| `gcloud run services describe <SERVICE> --region=<REGION>` | View status, image, and URL of a Cloud Run service. |
| `gcloud run deploy <SERVICE> --image=<DOCKER_IMAGE>` | Deploy a new service revision from a container image. |
| `gcloud run deploy <SERVICE> --source .` | Deploy directly from local source code (via Cloud Build). |
| `gcloud run services delete <SERVICE> --region=<REGION>` | Delete a Cloud Run service. |
| `gcloud run revisions list --service=<SERVICE>` | List revision history for a specific service. |
| `gcloud run services add-iam-policy-binding <SERVICE> --member="allUsers" --role="roles/run.invoker"` | Make a Cloud Run service publicly accessible over the internet. |
| `gcloud run services remove-iam-policy-binding <SERVICE> --member="allUsers" --role="roles/run.invoker"` | Restrict public access (enforce IAM authentication). |
| `gcloud run jobs create <JOB_NAME> --image=<DOCKER_IMAGE>` | Create a Cloud Run Job for batch executions. |
| `gcloud run jobs execute <JOB_NAME> --region=<REGION>` | Manually trigger a Cloud Run Job run. |
| `gcloud functions list` | List Cloud Functions (v1/v2) in the project. |
| `gcloud functions logs read <FUNCTION_NAME>` | View execution logs for a specific Cloud Function. |
| `--allow-unauthenticated` | Deployment flag allowing unauthenticated requests. |
| `--no-allow-unauthenticated` | Deployment flag blocking anonymous invocations. |
| `--min-instances=1` | Keep warm instances active to eliminate Cold Starts. |
| `--max-instances=10` | Set maximum scaling limit for cost control. |
| `--set-env-vars="KEY=VALUE"` | Inject runtime environment variables into the container. |
| `--service-account=<SA_EMAIL>` | Delegate runtime identity to a specific Service Account. |
| `--ingress=all` | Allow inbound traffic from any source (vs `internal`). |
| `gcloud services enable run.googleapis.com` | Enable the Cloud Run API. |