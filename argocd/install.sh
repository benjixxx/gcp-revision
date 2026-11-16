#!/usr/bin/env bash
# ==============================================================================
# ArgoCD Helm Installation Helper for GKE (main-gke-cluster)
# ==============================================================================
set -euo pipefail

PROJECT_ID="myproject-329912"
ZONE="europe-west1-b"
CLUSTER_NAME="main-gke-cluster"
NAMESPACE="argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function log() {
  echo -e "\033[1;34m[ArgoCD Helm]\033[0m $1"
}

function connect() {
  log "Connexion au cluster GKE '${CLUSTER_NAME}' (${ZONE})..."
  gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${ZONE}" \
    --project "${PROJECT_ID}"
}

function install_helm() {
  connect

  log "1/3. Ajout du repository Helm officiel Argo..."
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update

  log "2/3. Déploiement d'ArgoCD via Helm dans le namespace '${NAMESPACE}'..."
  helm upgrade --install argocd argo/argo-cd \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${SCRIPT_DIR}/values-standalone.yaml"

  log "3/3. Attente de la disponibilité d'ArgoCD Server..."
  kubectl rollout status deployment/argocd-server -n "${NAMESPACE}" --timeout=180s

  echo ""
  log "Installation Helm réussie !"
  get_password
}

function get_password() {
  log "Récupération du mot de passe initial du compte 'admin' :"
  if kubectl get secret argocd-initial-admin-secret -n "${NAMESPACE}" &>/dev/null; then
    PASS=$(kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
    echo "=========================================================="
    echo -e "Utilisateur : \033[1;32madmin\033[0m"
    echo -e "Mot de passe : \033[1;33m${PASS}\033[0m"
    echo "=========================================================="
  else
    echo "⚠️ Le secret 'argocd-initial-admin-secret' n'est plus présent ou a déjà été personnalisé."
  fi
}

function ui() {
  log "Lancement du port-forward vers l'interface Web ArgoCD..."
  echo -e "Ouvrez votre navigateur sur : \033[1;32mhttp://localhost:8080\033[0m"
  echo "Identifiant : admin"
  kubectl port-forward svc/argocd-server -n "${NAMESPACE}" 8080:80
}

function uninstall() {
  read -p "Êtes-vous sûr de vouloir désinstaller ArgoCD (Helm release 'argocd') ? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Désinstallation de la release Helm 'argocd'..."
    helm uninstall argocd --namespace "${NAMESPACE}" || true
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
    log "Désinstallation terminée."
  fi
}

case "${1:-install}" in
  connect)
    connect
    ;;
  install)
    install_helm
    ;;
  password)
    get_password
    ;;
  ui|port-forward)
    ui
    ;;
  uninstall|delete)
    uninstall
    ;;
  *)
    echo "Usage: $0 {connect|install|password|ui|uninstall}"
    exit 1
    ;;
esac
