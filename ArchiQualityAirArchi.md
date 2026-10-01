# ☁️ Architecture Réseau & Kubernetes - Quality Air Application

Ce document détaille l'architecture complète, les flux réseau (Ingress & Egress), la configuration Kubernetes/GCP et les mécanismes de résilience de l'application **Quality Air**.

---

## 🗺️ 1. Schéma d'Architecture Global

```mermaid
flowchart TD
    %% ==========================================
    %% INTERNET PUBLIC
    %% ==========================================
    subgraph PUBLIC_INTERNET["🌐 Internet Public (Monde Extérieur)"]
        Client["👤 Visiteur / Navigateur Web\nURL: http://<EXTERNAL_LB_IP>\n(Port 80 HTTP)"]
        OpenMeteo["⛅ API Météo Externe\nair-quality-api.open-meteo.com\n(Port 443 HTTPS)"]
    end

    %% ==========================================
    %% GCP EDGE & LOAD BALANCING
    %% ==========================================
    subgraph GCP_EDGE["🛡️ Google Cloud Network Edge"]
        LB["⚖️ External TCP/HTTP Load Balancer\nIP Publique : <EXTERNAL_LB_IP>:80\n(Géré automatiquement par le Service K8s)"]
        HC["🩺 GCP Health Check Probes\nPlages officielles de sondes GCP\nVérification périodique /health"]
    end

    %% ==========================================
    %% GCP CUSTOM VPC
    %% ==========================================
    subgraph VPC["🏢 Google Cloud VPC : main-vpc"]
        
        %% Firewall Layer
        subgraph FIREWALL["🔥 Règles Pare-feu VPC (Firewall Rules)"]
            FW_In["📥 INGRESS :\n• allow-internal (<SUBNET_CIDR> : all)\n• allow-health-checks (TCP 8080)\n• allow-iap-ssh (<GCP_IAP_CIDR> : port 22)"]
            FW_Out["📤 EGRESS :\n• default-allow-egress (Internet : all)"]
        end

        %% Subnetwork & GKE Private Cluster
        subgraph SUBNET["📌 Sous-réseau : main-vpc-subnet (<SUBNET_CIDR>) - europe-west1"]
            
            subgraph GKE["☸️ Cluster GKE Privé : main-gke-cluster (Zone: europe-west1-b)"]
                
                subgraph K8S_NET["Couche Réseau Kubernetes"]
                    Svc["🔀 Service K8s : quality-air-service\nType: LoadBalancer\nClusterIP: <CLUSTER_IP>\nNodePort: <NODE_PORT>/TCP\nPort: 80 -> TargetPort: 8080"]
                end

                subgraph PODS["Namespace : quality-air (Secondary Range: pods)"]
                    Pod1["📦 Pod 1 : quality-air-app-*\nIP Privée interne (<POD_IP>)\n├─ Gunicorn Server (3 workers)\n├─ Flask app.py (:8080)\n└─ Sonde Locale /health (200 OK)"]
                    Pod2["📦 Pod 2 : quality-air-app-*\nIP Privée interne (<POD_IP>)\n├─ Gunicorn Server (3 workers)\n├─ Flask app.py (:8080)\n└─ Sonde Locale /health (200 OK)"]
                end

                HPA["📈 HPA Autoscaler : quality-air-hpa\nMin: 2 Pods | Max: 5 Pods\nCible CPU : 70%"]
            end
        end

        %% Egress Gateway
        subgraph EGRESS_GW["🚪 Passerelle de Sortie (Outbound Egress Gateway)"]
            Router["🧭 Cloud Router : main-vpc-router\nRégion : europe-west1\nTable de routage Internet"]
            NAT["🌐 Cloud NAT : main-vpc-nat\nMode : AUTO_ONLY (IPs publiques dynamiques)\nSNAT : Traduction IP Privée -> IP Publique NAT"]
        end
    end

    %% ==========================================
    %% OBSERVABILITÉ & SRE
    %% ==========================================
    subgraph OBS["📊 Observabilité & Logs SRE"]
        LogsAgent["📝 Cloud Logging Agent (stdout/stderr)"]
        Sink["🚰 Log Sink : k8s-to-bigquery\nFiltre : namespace='quality-air'"]
        BQ["💾 BigQuery Dataset : k8s_logs\nTable : stderr / audit"]
    end

    %% ==========================================
    %% LIAISONS & FLUX (Ingress / Egress / Logs)
    %% ==========================================
    
    %% Flux Entrant (Ingress)
    Client ==>|"1. Requête HTTP GET / (Port 80)"| LB
    HC -.->|"Sonde de disponibilité périodique"| Svc
    LB ==>|"2. Forward vers les Nœuds via Firewall"| Svc
    Svc ==>|"3. Dispatch de charge (Round-Robin)"| Pod1
    Svc ==>|"3. Dispatch de charge (Round-Robin)"| Pod2

    %% Flux Sortant (Egress)
    Pod1 -->|"4. Appel API Externe (requests.get HTTPS)"| NAT
    Pod2 -->|"4. Appel API Externe (requests.get HTTPS)"| NAT
    Router -.- NAT
    NAT -->|"5. Egress via IP Publique NAT (SNAT)"| OpenMeteo
    OpenMeteo -->|"6. Retour JSON Données Météo"| NAT
    NAT -->|"7. Retour des données au Pod"| Pod1

    %% Flux Observabilité
    Pod1 -.->|"Logs structurés JSON"| LogsAgent
    Pod2 -.->|"Logs structurés JSON"| LogsAgent
    LogsAgent --> Sink
    Sink --> BQ

    %% ==========================================
    %% STYLES
    %% ==========================================
    classDef internet fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef gcp fill:#1e293b,stroke:#4285f4,stroke-width:2px,color:#f8fafc;
    classDef k8s fill:#1e3a5f,stroke:#34a853,stroke-width:2px,color:#f8fafc;
    classDef nat fill:#451a03,stroke:#f97316,stroke-width:2px,color:#f8fafc;
    classDef obs fill:#311042,stroke:#c084fc,stroke-width:2px,color:#f8fafc;
    
    class Client,OpenMeteo internet;
    class LB,HC,Router,FW_In,FW_Out gcp;
    class Svc,Pod1,Pod2,HPA k8s;
    class NAT nat;
    class LogsAgent,Sink,BQ obs;
```

---

## 🔄 2. Les Deux Chemins Réseau Fondamentaux

L'application repose sur deux flux réseau complètement indépendants :

### 🔵 Flux A : Trafic Entrant (*Ingress*) — La visite de l'utilisateur
1. **L'utilisateur** tape `http://<EXTERNAL_LB_IP>` dans son navigateur.
2. La requête arrive sur le **Google Cloud External Load Balancer**.
3. Le **Firewall GCP** autorise le trafic vers le cluster GKE.
4. Le **Service Kubernetes** (`quality-air-service` de type `LoadBalancer`) intercepte la requête sur le port `80` et la transmet au port cible `8080` de l'un des pods.
5. Le serveur web **Gunicorn / Flask** reçoit la requête et génère le code HTML de la page d'accueil.

### 🟠 Flux B : Trafic Sortant (*Egress*) — La récupération des données météo
1. Pendant que le pod génère le tableau de bord, son code Python exécute :
   ```python
   requests.get("https://air-quality-api.open-meteo.com/v1/air-quality?...")
   ```
2. **Problème de départ :** Le cluster GKE est **privé** (`enable_private_nodes = true`). Ses nœuds et ses pods ne possèdent **aucune adresse IP publique**.
3. **La solution :** Le paquet sortant est orienté par le **Cloud Router** vers la passerelle **Cloud NAT** (`main-vpc-nat`).
4. **Le Cloud NAT (SNAT) :** Il remplace l'adresse IP privée interne du pod (`<POD_IP>`) par l'adresse IP publique allouée par le NAT (`<NAT_PUBLIC_IP>`) et contacte l'API Open-Meteo sur le port `443` (HTTPS).
5. Open-Meteo renvoie la réponse au NAT, qui la retransmet au pod.
6. Le pod intègre les indices de pollution dans le HTML et renvoie la page complète à l'utilisateur.

---

## 📂 3. Correspondance avec le Code du Projet

| Composant | Rôle dans l'Architecture | Fichier Source dans le Projet |
| :--- | :--- | :--- |
| **VPC & Subnet** | Réseau virtuel isolé (`var.subnet_cidr`) avec plages secondaires pour GKE | [modules/network/main.tf](file:///Users/benjixxx/gcp-revision/modules/network/main.tf) |
| **Cloud Router & NAT** | Passerelle de sortie vers Internet pour les pods privés | [modules/network/main.tf#L31-L43](file:///Users/benjixxx/gcp-revision/modules/network/main.tf#L31-L43) |
| **Firewall Rules** | Autorisations internes, sondes de santé et accès IAP | [modules/network/main.tf#L45-L77](file:///Users/benjixxx/gcp-revision/modules/network/main.tf#L45-L77) |
| **Cluster GKE Privé** | Orchestrateur Kubernetes avec nœuds privés Spot | [modules/gke/main.tf](file:///Users/benjixxx/gcp-revision/modules/gke/main.tf) |
| **Service LoadBalancer** | Exposition publique de l'application sur le port 80 | [qualityAirApp/k8s/service.yaml](file:///Users/benjixxx/gcp-revision/qualityAirApp/k8s/service.yaml) |
| **Deployment & Probes** | Déploiement des réplicas, sondes `/health` et limites CPU/RAM | [qualityAirApp/k8s/deployment.yaml](file:///Users/benjixxx/gcp-revision/qualityAirApp/k8s/deployment.yaml) |
| **Code Flask & Logger** | Application Python, gestion du fallback et logs JSON GCP | [qualityAirApp/app.py](file:///Users/benjixxx/gcp-revision/qualityAirApp/app.py) |
| **Sink BigQuery** | Exportation des logs d'erreurs GKE vers BigQuery | [modules/logging_monitoring/main.tf](file:///Users/benjixxx/gcp-revision/modules/logging_monitoring/main.tf) |

---

## 🛠️ 4. Retour d'Expérience & Résolution de Panne (*Post-Mortem*)

### Le Symptôme :
- Les pods étaient affichés en vert : **`1/1 Running (0 restarts)`**.
- Le Load Balancer était fonctionnel : **`200 OK` sur `/health`**.
- Mais l'application affichait **`UNAVAILABLE`** pour toutes les villes.

### La Cause Racine :
La passerelle **Cloud NAT** n'était plus active sur le VPC. Sans Cloud NAT :
- Le trafic entrant (Ingress) continuait de fonctionner (l'utilisateur voyait bien la page HTML).
- Le trafic sortant (Egress) était bloqué : les pods ne pouvaient pas sortir vers l'API météo externe.
- Le code Flask basculait silencieusement sur son mode dégradé (*fallback*).

### Pourquoi les Pods sont restés « Verts » ?
La sonde de santé Kubernetes (`readinessProbe` & `livenessProbe`) teste l'endpoint local `/health` :
- Tester une dépendance externe dans le health check aurait entraîné le redémarrage en boucle des pods (*CrashLoopBackOff*) et une erreur 502 Bad Gateway.
- Le mode dégradé a permis de conserver l'interface accessible pendant l'incident.

### La Résolution :
La réapplication du module Terraform réseau a recréé la ressource `google_compute_router_nat` :
```bash
terraform apply -target=module.network
```
Les pods ont immédiatement retrouvé leur route de sortie vers Internet.

---

## 🚀 5. Commandes Utiles pour l'Exploitation (Cheat Sheet OPS)

```bash
# 1. Se connecter au cluster GKE
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project <PROJECT_ID>

# 2. Vérifier l'état des pods et du service (IP externe et ports)
kubectl get pods,svc -n quality-air -o wide

# 3. Tester la sortie Internet depuis l'intérieur d'un pod
kubectl exec -n quality-air -l app=quality-air-app -- curl -I -m 5 https://air-quality-api.open-meteo.com

# 4. Vérifier l'état de la passerelle Cloud NAT
gcloud compute routers nats list --router=main-vpc-router --region=<REGION>

# 5. Consulter les logs d'erreurs de l'application
kubectl logs -l app=quality-air-app -n quality-air --tail=50
```
