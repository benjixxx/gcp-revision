# OpenTelemetry Collector (DaemonSet) sur GKE (`main-gke-cluster`)

Ce dossier contient la configuration complète d'un **DaemonSet OpenTelemetry Collector** déployé sur chaque nœud du cluster GKE `main-gke-cluster` (Projet GCP: `myproject-329912`).

---

## 🏗️ Architecture

```text
[ Node GKE: main-gke-cluster ]
  │
  ├── Pod App (ex: quality-air-app) ──(OTLP 4317 / 4318)──┐
  ├── Pod App N ─────────────────────(OTLP 4317 / 4318)──┤
  │                                                      ▼
  │                                         [ DaemonSet Pod ]
  │                                         otel-collector-contrib
  │                                         ├── kubeletstats (métriques pods/nodes)
  │                                         └── hostmetrics (CPU/RAM/Disk du nœud)
  │                                                      │
  │                                                      ▼
  └──────────────────────────────────────── Google Cloud Operations Suite
                                            ├── Google Cloud Trace (Traces OTLP)
                                            └── Google Cloud Monitoring (Métriques)
```

### Rôle du DaemonSet :
1. **Collecte locale à faible latence** : Chaque nœud exécute une instance du collector exposant les ports OTLP en direct (`hostPort: 4317 / 4318`) ou via le Service ClusterIP (`otel-collector.opentelemetry.svc.cluster.local`).
2. **Métriques d'infrastructure GKE** :
   * `hostmetrics` : CPU, mémoire, disque, réseau du nœud physique/VM.
   * `kubeletstats` : Utilisation des ressources par conteneur et par pod via l'API Kubelet.
3. **Enrichissement Kubernetes automatique (`k8sattributes`)** : Ajout automatique des tags `k8s.pod.name`, `k8s.namespace.name`, `k8s.node.name`, `k8s.cluster.name: "main-gke-cluster"`.
4. **Export natif GCP (`googlecloud`)** : Envoie directement vers Google Cloud Trace et Google Cloud Monitoring sans outil tiers requis.

---

## 📁 Fichiers inclus

* `00-namespace.yaml` : Namespace dédié `opentelemetry`.
* `01-rbac.yaml` : ServiceAccount et ClusterRole autorisant la lecture des métadonnées K8s et kubelet.
* `02-configmap.yaml` : Configuration des pipelines OTel (receivers, processors, exporters).
* `03-service.yaml` : Service ClusterIP interne.
* `04-daemonset.yaml` : DaemonSet déployant `otel/opentelemetry-collector-contrib`.
* `kustomization.yaml` : Permet un déploiement en une seule commande via Kustomize.

---

## 🚀 Déploiement

### 1. Vérifier le contexte Kubernetes
Assurez-vous d'être connecté au bon cluster :
```bash
kubectl config current-context
# Doit afficher : gke_myproject-329912_europe-west1-b_main-gke-cluster
```

### 2. Déployer les manifests
Déployez tout le dossier via `kustomize` :
```bash
kubectl apply -k openTelemetry/
```

### 3. Vérifier le bon fonctionnement
```bash
# Vérifier l'état des pods DaemonSet (1 pod par node)
kubectl get daemonset -n opentelemetry
kubectl get pods -n opentelemetry -o wide

# Consulter les logs du collecteur
kubectl logs -n opentelemetry -l app.kubernetes.io/name=otel-collector -f
```

---

## 🔐 Permissions GCP requises (IAM)

Pour que le collecteur puisse exporter vers Google Cloud Trace et Monitoring, le compte de service utilisé par vos nœuds GKE (ou via Workload Identity) doit posséder au minimum les rôles GCP suivants :

* **Cloud Trace Agent** : `roles/cloudtrace.agent`
* **Monitoring Metric Writer** : `roles/monitoring.metricWriter`
* **Logs Writer** (si export de logs activé) : `roles/logging.logWriter`

Exemple de commande pour ajouter les rôles au compte de service de vos nœuds :
```bash
SA_EMAIL="<NODE_OR_WORKLOAD_IDENTITY_SA>@myproject-329912.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding myproject-329912 \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/cloudtrace.agent"

gcloud projects add-iam-policy-binding myproject-329912 \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/monitoring.metricWriter"
```

---

## 📡 Comment envoyer la télémétrie depuis vos pods (ex: `quality-air-app`)

### Option A : Via le Service ClusterIP (Recommandé)
Configurez l'endpoint OTLP dans votre application :
* **OTLP gRPC** : `http://otel-collector.opentelemetry.svc.cluster.local:4317`
* **OTLP HTTP** : `http://otel-collector.opentelemetry.svc.cluster.local:4318`

### Option B : Directement sur l'agent du nœud hôte (`hostIP`)
Dans le manifest de votre pod, injectez l'IP du nœud hôte via la downward API :
```yaml
env:
  - name: HOST_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(HOST_IP):4317"
```

