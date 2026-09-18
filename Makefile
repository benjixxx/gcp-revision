# ==============================================================================
# Terraform Automation Makefile for GCP Infrastructure
# ==============================================================================

VAR_FILE := ./gcp.tfvars

.PHONY: help init fmt validate \
        plan apply destroy \
        plan-iam apply-iam destroy-iam \
        plan-network apply-network destroy-network \
        plan-storage apply-storage destroy-storage \
        plan-compute apply-compute destroy-compute \
        plan-gke apply-gke destroy-gke \
        plan-serverless apply-serverless destroy-serverless \
        plan-bigquery apply-bigquery destroy-bigquery \
        plan-artifactory apply-artifactory destroy-artifactory \
        plan-ops apply-ops destroy-ops

# ------------------------------------------------------------------------------
# Help Menu
# ------------------------------------------------------------------------------
help:
	@echo "=================================================================="
	@echo "              GCP Terraform Automation Helper                     "
	@echo "=================================================================="
	@echo "Global Commands:"
	@echo "  make init                 # Initialize Terraform"
	@echo "  make plan                 # Plan all modules"
	@echo "  make apply                # Apply all modules"
	@echo "  make destroy              # Destroy all modules"
	@echo "  make fmt                  # Format all terraform files"
	@echo "  make validate             # Validate configuration"
	@echo ""
	@echo "Module Commands (Plan | Apply | Destroy):"
	@echo "  make plan-iam             | make apply-iam             | make destroy-iam"
	@echo "  make plan-network         | make apply-network         | make destroy-network"
	@echo "  make plan-storage         | make apply-storage         | make destroy-storage"
	@echo "  make plan-compute         | make apply-compute         | make destroy-compute"
	@echo "  make plan-gke             | make apply-gke             | make destroy-gke"
	@echo "  make plan-serverless      | make apply-serverless      | make destroy-serverless"
	@echo "  make plan-bigquery        | make apply-bigquery        | make destroy-bigquery"
	@echo "  make plan-artifactory     | make apply-artifactory     | make destroy-artifactory"
	@echo "  make plan-ops             | make apply-ops             | make destroy-ops"
	@echo "=================================================================="

# ------------------------------------------------------------------------------
# Core Global Commands
# ------------------------------------------------------------------------------
init:
	terraform init

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	terraform plan -var-file=$(VAR_FILE)

apply:
	terraform apply -var-file=$(VAR_FILE)

destroy:
	terraform destroy -var-file=$(VAR_FILE)

# ------------------------------------------------------------------------------
# IAM Module
# ------------------------------------------------------------------------------
plan-iam:
	terraform plan -var-file=$(VAR_FILE) -target=module.iam

apply-iam:
	terraform apply -var-file=$(VAR_FILE) -target=module.iam

destroy-iam:
	terraform destroy -var-file=$(VAR_FILE) -target=module.iam

# ------------------------------------------------------------------------------
# Network Module
# ------------------------------------------------------------------------------
plan-network:
	terraform plan -var-file=$(VAR_FILE) -target=module.network

apply-network:
	terraform apply -var-file=$(VAR_FILE) -target=module.network

destroy-network:
	terraform destroy -var-file=$(VAR_FILE) -target=module.network

# ------------------------------------------------------------------------------
# Cloud Storage Module
# ------------------------------------------------------------------------------
plan-storage:
	terraform plan -var-file=$(VAR_FILE) -target=module.cloud_storage

apply-storage:
	terraform apply -var-file=$(VAR_FILE) -target=module.cloud_storage

destroy-storage:
	terraform destroy -var-file=$(VAR_FILE) -target=module.cloud_storage

# ------------------------------------------------------------------------------
# Compute Engine Module
# ------------------------------------------------------------------------------
plan-compute:
	terraform plan -var-file=$(VAR_FILE) -target=module.compute_engine

apply-compute:
	terraform apply -var-file=$(VAR_FILE) -target=module.compute_engine

destroy-compute:
	terraform destroy -var-file=$(VAR_FILE) -target=module.compute_engine

# ------------------------------------------------------------------------------
# GKE Module
# ------------------------------------------------------------------------------
plan-gke:
	terraform plan -var-file=$(VAR_FILE) -target=module.gke

apply-gke:
	terraform apply -var-file=$(VAR_FILE) -target=module.gke

destroy-gke:
	terraform destroy -var-file=$(VAR_FILE) -target=module.gke

# ------------------------------------------------------------------------------
# Serverless Module (Cloud Run)
# ------------------------------------------------------------------------------
plan-serverless:
	terraform plan -var-file=$(VAR_FILE) -target=module.serverless

apply-serverless:
	terraform apply -var-file=$(VAR_FILE) -target=module.serverless

destroy-serverless:
	terraform destroy -var-file=$(VAR_FILE) -target=module.serverless

# ------------------------------------------------------------------------------
# BigQuery Module
# ------------------------------------------------------------------------------
plan-bigquery:
	terraform plan -var-file=$(VAR_FILE) -target=module.bigquery

apply-bigquery:
	terraform apply -var-file=$(VAR_FILE) -target=module.bigquery

destroy-bigquery:
	terraform destroy -var-file=$(VAR_FILE) -target=module.bigquery

# ------------------------------------------------------------------------------
# Artifactory Moudle
# ------------------------------------------------------------------------------
plan-artifactory:
	terraform plan -var-file=$(VAR_FILE) -target=module.artifactory

apply-artifactory:
	terraform apply -var-file=$(VAR_FILE) -target=module.artifactory

destroy-artifactory:
	terraform destroy -var-file=$(VAR_FILE) -target=module.artifactory

# ------------------------------------------------------------------------------
# Logging & Monitoring (Ops)
# ------------------------------------------------------------------------------
plan-ops:
	terraform plan -var-file=$(VAR_FILE) -target=module.bigquery -target=module.logging_monitoring

apply-ops:
	terraform apply -var-file=$(VAR_FILE) -target=module.bigquery -target=module.logging_monitoring

destroy-ops:
	terraform destroy -var-file=$(VAR_FILE) -target=module.logging_monitoring -target=module.bigquery