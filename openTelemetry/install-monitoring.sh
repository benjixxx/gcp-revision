#!/usr/bin/env bash
# ==============================================================================
# Complete Observability & Tracing Installer for GKE
# (cert-manager + OpenTelemetry Operator + Collector + Tempo + Grafana)
# ==============================================================================
set -euo pipefail

PROJECT_ID="myproject-329912"
ZONE="europe-west1-b"
CLUSTER_NAME="main-gke-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function log() {
  echo -e "\033[1;34m[Observability]\033[0m $1"
}

function connect() {
  log "Connexion au cluster GKE '${CLUSTER_NAME}' (${ZONE})..."
  gcloud container clusters get-credentials "${CLUSTER_NAME}" \
    --zone "${ZONE}" \
    --project "${PROJECT_ID}"
}

function install_all() {
  connect

  # ----------------------------------------------------------------------------
  # 1. Cert-Manager (Requis pour les certificats TLS du webhook de l'Opérateur)
  # ----------------------------------------------------------------------------
  log "1/5. Déploiement de Cert-Manager (v1.14.0)..."
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
  
  log "Attente que les webhooks Cert-Manager soient prêts..."
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

  # ----------------------------------------------------------------------------
  # 2. OpenTelemetry Operator (via Helm)
  # ----------------------------------------------------------------------------
  log "2/5. Déploiement de l'OpenTelemetry Operator..."
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm repo update

  helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
    --namespace opentelemetry \
    --create-namespace \
    --set "manager.collectorImage.repository=otel/opentelemetry-collector-contrib"

  log "Attente que l'OpenTelemetry Operator soit prêt..."
  kubectl rollout status deployment/opentelemetry-operator -n opentelemetry --timeout=120s

  # ----------------------------------------------------------------------------
  # 3. Collector + Tempo + Grafana + Instrumentation CRD
  # ----------------------------------------------------------------------------
  log "3/5. Déploiement du Collector, Tempo, Grafana et de l'Instrumentation..."
  kubectl apply -k "${SCRIPT_DIR}"

  # ----------------------------------------------------------------------------
  # 4. Redémarrage de QualityAirApp pour injecter l'Init Container OTel
  # ----------------------------------------------------------------------------
  log "4/5. Redémarrage de QualityAirApp pour injecter l'agent Python..."
  if kubectl get deployment quality-air-app -n quality-air &>/dev/null; then
    kubectl rollout restart deployment/quality-air-app -n quality-air
    kubectl rollout status deployment/quality-air-app -n quality-air --timeout=120s
  fi

  # ----------------------------------------------------------------------------
  # 5. Récapitulatif et accès
  # ----------------------------------------------------------------------------
  echo ""
  log "Installation terminée avec succès !"
  echo "=================================================================="
  echo -e "🚀 \033[1;32mStack d'Observabilité & Tracing active :\033[0m"
  echo "  1. OpenTelemetry Operator : Auto-injecte l'agent dans Python"
  echo "  2. OTel Collector         : Reçoit, enrichit et route les traces"
  echo "  3. Tempo                  : Stocke chaque requête et trace HTTP"
  echo "  4. Grafana                : Visualise les traces et requêtes"
  echo ""
  echo "Pour ouvrir Grafana :"
  echo "  kubectl port-forward svc/grafana -n opentelemetry 3000:3000"
  echo "  Navigateur : http://localhost:3000"
  echo "  Identifiants : admin / admin"
  echo "=================================================================="
}

function grafana_ui() {
  log "Ouverture du tunnel vers Grafana sur http://localhost:3000..."
  echo "Identifiants : admin / admin"
  kubectl port-forward svc/grafana -n opentelemetry 3000:3000
}

case "${1:-install}" in
  connect)
    connect
    ;;
  install)
    install_all
    ;;
  ui|grafana)
    grafana_ui
    ;;
  *)
    echo "Usage: $0 {connect|install|ui}"
    exit 1
    ;;
esac
