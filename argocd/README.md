# ⎈ Plateforme ArgoCD packagée avec Helm (GKE `main-gke-cluster`)

Ce dossier contient le packaging Helm pour déployer la plateforme **ArgoCD** dans son namespace dédié **`argocd`** sur le cluster GKE privé **`main-gke-cluster`** (Projet GCP: `myproject-329912`, Zone: `europe-west1-b`).

---

## 📁 1. Structure du Package Helm

```text
argocd/
├── Chart.yaml                # Définition du Chart Helm (Umbrella chart avec dépendance argo-cd)
├── values.yaml               # Valeurs configurées pour le Chart local ./argocd
├── values-standalone.yaml    # Valeurs pour le chart officiel distant argo/argo-cd
├── sample-applications.yaml  # Applications GitOps (QualityAirApp & OpenTelemetry) à appliquer après
├── install.sh                # Helper script optionnel
└── README.md                 # Documentation et commandes d'installation
```

---

## 🚀 2. Commandes pour installer la plateforme ArgoCD

Le chart installe **strictement la plateforme ArgoCD** et toutes ses CRDs (`applications.argoproj.io`, `applicationsets.argoproj.io`, etc.).

### Option A : Déploiement via le package local `./argocd`
```bash
# 1. Mettre à jour les dépendances locales (si pas déjà fait)
helm dependency update ./argocd

# 2. Déployer la plateforme dans le namespace 'argocd'
helm upgrade --install argocd ./argocd \
  --namespace argocd \
  --create-namespace \
  --values ./argocd/values.yaml
```

---

### Option B : Déploiement via le chart officiel distant `argo/argo-cd`
```bash
# 1. Ajouter le repository officiel
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Installer avec le fichier de valeurs
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd/values-standalone.yaml
```

---

## 🔑 3. Récupérer le mot de passe initial (`admin`)

Dès que le pod `argocd-server` est démarré :

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo
```

---

## 🖥️ 4. Accéder à l'interface Web ArgoCD

Exécutez le port-forwarding local :

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Accédez ensuite à votre navigateur :
👉 **[http://localhost:8080](http://localhost:8080)**  
* **Identifiant** : `admin`  
* **Mot de passe** : *(la valeur récupérée à l'étape 3)*

---

## 📦 5. (Optionnel) Déployer les applications GitOps

Une fois la plateforme ArgoCD installée et ses CRDs actives :

```bash
kubectl apply -f argocd/sample-applications.yaml
```
Cela instancie automatiquement :
* `quality-air-app` dans le namespace `quality-air`
* `opentelemetry-collector` dans le namespace `opentelemetry`

---

## 🧹 6. Désinstallation

```bash
helm uninstall argocd --namespace argocd
kubectl delete namespace argocd
```
