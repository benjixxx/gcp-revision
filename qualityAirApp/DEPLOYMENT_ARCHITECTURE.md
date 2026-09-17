# QualityAirApp — GCP Deployment Architecture

This document details the production architecture, networking, security, and automated deployment pipeline for **QualityAirApp** deployed on Google Cloud Platform (GCP).

---

## 1. High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Clients ["Public Internet"]
        User["Client Browser"]
        OpenMeteo["Open-Meteo API<br/>(air-quality-api.open-meteo.com)"]
    end

    subgraph GCP ["Google Cloud Platform (Project: myproject-329912)"]
        
        subgraph GCS_Layer ["Storage & Artifacts Layer"]
            Bucket[("Cloud Storage Bucket<br/>gs://quality-air-app")]
            Code["Application Bundle:<br/>• app.py<br/>• requirements.txt<br/>• templates/index.html"]
            Bucket --- Code
        end

        subgraph IAM_Layer ["Security & Identity (Keyless IAM)"]
            SA["Service Account<br/>qualityair-vm-sa"]
            Binding["Bucket IAM Member<br/>roles/storage.objectViewer"]
            SA --> Binding
            Binding -.->|"Read-only access"| Bucket
        end

        subgraph LB_Layer ["Cloud HTTP(S) Load Balancing (Global)"]
            FR["Global Forwarding Rule<br/>IP: 34.110.164.113 : Port 80"]
            Proxy["Target HTTP Proxy<br/>(qualityair-vm-http-proxy)"]
            URLMap["URL Map<br/>(qualityair-vm-url-map)"]
            BackendSvc["Backend Service<br/>(qualityair-vm-backend)<br/>Port: 8080 | Mode: UTILIZATION"]
            HC["HTTP Health Check<br/>(qualityair-vm-hc)<br/>GET /health : 8080 (every 5s)"]

            FR --> Proxy
            Proxy --> URLMap
            URLMap --> BackendSvc
            HC -.->|"Health Probes"| BackendSvc
        end

        subgraph VPC_Layer ["VPC Network: default"]
            FW["Firewall Rule: qualityair-vm-allow-lb-hc<br/>Allow TCP 8080<br/>Sources: 35.191.0.0/16, 130.211.0.0/22<br/>Target Tag: http-server"]

            subgraph MIG ["Managed Instance Group: qualityair-vm-mig (Zone: europe-west1-b)"]
                subgraph IT ["Instance Template: qualityair-vm-template"]
                    Meta["Metadata: startup-script.sh<br/>Attached Identity: qualityair-vm-sa"]
                end

                VM1["VM Node 1<br/>qualityair-vm-node-dwtd"]
                VM2["VM Node 2<br/>qualityair-vm-node-qwwj"]
                VM3["VM Node 3<br/>qualityair-vm-node-xxxx"]
            end
        end
    end

    %% Ingress Flow
    User -->|"HTTP GET :80"| FR
    BackendSvc -->|"Proxy traffic :8080"| FW
    FW -->|"Filtered by tag: http-server"| VM1 & VM2 & VM3

    %% Bootstrapping & Provisioning Flow
    SA -.->|"Attached via Metadata"| IT
    Meta -->|"1. Pull bundle via gsutil rsync"| Bucket
    Meta -->|"2. Provision Python 3 venv & dependencies"| VM1 & VM2 & VM3
    Meta -->|"3. Systemd daemon (Gunicorn on :8080)"| VM1 & VM2 & VM3

    %% Outbound Egress
    VM1 & VM2 & VM3 -->|"HTTPS Outbound Egress :443"| OpenMeteo
```

---

## 2. End-to-End Request Flow

The following sequence diagram outlines how an end-user request travels through the load balancing and compute tier, including asynchronous egress calls to the external weather API:

```mermaid
sequenceDiagram
    autonumber
    actor User as Client Browser
    participant GFE as Google Front End (GFE) / LB<br/>(34.110.164.113:80)
    participant FW as VPC Firewall
    participant Gunicorn as VM Gunicorn / Flask<br/>(Port 8080)
    participant API as Open-Meteo Air Quality API

    User->>GFE: HTTP GET /
    Note over GFE: Checks healthy backends<br/>(qualityair-vm-mig)
    GFE->>FW: Forward to selected node on TCP 8080
    FW->>Gunicorn: Validate source range & target tag (http-server)
    
    activate Gunicorn
    Gunicorn->>Gunicorn: Collect local system metrics (CPU, RAM, Uptime)
    Gunicorn->>API: HTTPS GET /v1/air-quality (Paris, London, NY, etc.)
    activate API
    API-->>Gunicorn: 200 OK (AQI, PM2.5, PM10, NO2, O3)
    deactivate API
    Gunicorn->>Gunicorn: Render index.html with live telemetry
    Gunicorn-->>GFE: 200 OK (HTML Response + Headers)
    deactivate Gunicorn

    GFE-->>User: HTTP 200 OK (Dashboard loaded)
```

---

## 3. Node Bootstrapping & Continuous Deployment Lifecycle

Each VM instance in the Managed Instance Group executes the following automated bootstrapping sequence during provisioning:

```mermaid
sequenceDiagram
    autonumber
    participant Engine as Compute Engine Boot
    participant Meta as GCP Metadata Server
    participant GCS as GCS Bucket (gs://quality-air-app)
    participant Systemd as Linux Systemd

    Engine->>Meta: Fetch Instance Metadata (startup-script.sh)
    Engine->>Meta: Obtain OAuth Access Token for qualityair-vm-sa
    Note over Engine: apt-get install python3-venv python3.11-venv
    Engine->>GCS: gsutil -m rsync -r gs://quality-air-app/qualityAirApp/ /opt/qualityAirApp/
    GCS-->>Engine: Synchronize app.py, requirements.txt, templates/
    Note over Engine: Setup Python venv in /opt/qualityAirApp/venv
    Note over Engine: pip install -r requirements.txt
    Engine->>Systemd: Create /etc/systemd/system/quality-air-app.service
    Engine->>Systemd: systemctl enable --now quality-air-app.service
    Systemd->>Systemd: Launch Gunicorn on 0.0.0.0:8080
    Note over Engine: VM is ready & serves /health
```

---

## 4. Technical Specifications Summary

| Component | Technical Specification | GCP Resource |
| :--- | :--- | :--- |
| **Public Frontend IP** | `34.110.164.113` (Port 80) | `google_compute_global_forwarding_rule` |
| **HTTP Proxy & Routing** | Global URL Map & Target HTTP Proxy | `google_compute_target_http_proxy`, `google_compute_url_map` |
| **Backend Service** | Port 8080, Protocol HTTP, Balancing Mode `UTILIZATION` | `google_compute_backend_service` |
| **Health Check** | HTTP `GET /health` on port 8080, interval 5s, timeout 3s | `google_compute_health_check` |
| **Managed Instance Group** | Zone: `europe-west1-b`, Target Size: 3, Base: `qualityair-vm-node` | `google_compute_instance_group_manager` |
| **Instance Template** | `e2-micro`, Debian 12 Minimal, Tags: `["http-server", "ssh-enabled"]` | `google_compute_instance_template` |
| **Artifact Storage** | Bucket `gs://quality-air-app/qualityAirApp/` | `google_storage_bucket` |
| **Identity & IAM** | Service Account `qualityair-vm-sa`, `roles/storage.objectViewer` | `google_service_account`, `google_storage_bucket_iam_member` |
| **Firewall** | Ingress 8080 allowed ONLY for `35.191.0.0/16` and `130.211.0.0/22` | `google_compute_firewall` |
| **Application Server** | Python 3.11 + Flask 3.1 + Gunicorn 26.2 (Systemd daemon) | `/etc/systemd/system/quality-air-app.service` |

---

## 5. Security Architecture Highlights

1. **Keyless Authentication (Zero Secrets on Disk):**
   - The VMs authenticate to Google Cloud Storage via the instance metadata server using short-lived OAuth tokens. No private JSON keys are generated, stored, or distributed.
2. **Principle of Least Privilege (PoLP):**
   - `qualityair-vm-sa` only has `roles/storage.objectViewer` scoped directly to `gs://quality-air-app`. It has zero privileges on Compute Engine, IAM, or other buckets.
3. **Restricted VPC Ingress:**
   - Firewall rule `qualityair-vm-allow-lb-hc` exclusively whitelists Google Cloud Load Balancer proxies and health checker subnets (`35.191.0.0/16`, `130.211.0.0/22`). Direct unsolicited internet traffic on port 8080 is blocked by default.

---

## 6. Operational Playbook

### Check Load Balancer Health Status
```bash
gcloud compute backend-services get-health qualityair-vm-backend --global
```

### Zero-Downtime Rolling Update of the MIG
```bash
gcloud compute instance-groups managed rolling-action replace qualityair-vm-mig \
    --zone=europe-west1-b \
    --max-surge=1 \
    --max-unavailable=0
```

### Inspect Instance Group Status
```bash
gcloud compute instance-groups managed list-instances qualityair-vm-mig \
    --zone=europe-west1-b \
    --format="table(name, instanceTemplate.basename(), currentAction, status)"
```

### Check Live Application Logs on a Specific VM Node
```bash
gcloud compute ssh qualityair-vm-node-dwtd --zone=europe-west1-b --command="sudo journalctl -u quality-air-app -n 50 -f"
```
