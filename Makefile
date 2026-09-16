# ==============================================================================
# Terraform Automation Makefile for GCP Infrastructure
# ==============================================================================

VAR_FILE := ./gcp.tfvars

# Capture module argument from commands like:
#   $ make plan iam
#   $ make apply iam
#   $ make destroy serverless
SUPPORTED_ACTIONS := plan apply destroy
FIRST_GOAL        := $(firstword $(MAKECMDGOALS))

ifneq ($(filter $(FIRST_GOAL),$(SUPPORTED_ACTIONS)),)
  TARGET_MODULE := $(word 2,$(MAKECMDGOALS))
  # Treat the module name as a no-op target so Make doesn't error out
  $(eval $(TARGET_MODULE):;@:)
endif

# Normalize module name (replace '-' with '_', e.g. cloud-storage -> cloud_storage)
SELECTED_MOD := $(or $(TARGET_MODULE),$(MODULE))
CLEAN_MOD    := $(subst -,_,$(SELECTED_MOD))

.PHONY: help init fmt validate plan apply destroy

# ------------------------------------------------------------------------------
# Default Help Menu
# ------------------------------------------------------------------------------
help:
	@echo "=================================================================="
	@echo "              GCP Terraform Automation Helper                     "
	@echo "=================================================================="
	@echo "Usage Syntax:"
	@echo "  make <action> <module>"
	@echo ""
	@echo "Examples:"
	@echo "  make plan iam                 # Plan only module.iam"
	@echo "  make apply iam                # Apply only module.iam"
	@echo "  make destroy iam              # Destroy only module.iam (or make destroy-iam)"
	@echo "  make plan bigquery            # Plan only module.bigquery"
	@echo "  make apply bigquery           # Apply only module.bigquery"
	@echo "  make destroy bigquery         # Destroy only module.bigquery (or make destroy-bigquery)"
	@echo "  make destroy serverless       # Destroy only module.serverless (or make destroy-serverless)"
	@echo ""
	@echo "Available Modules:"
	@echo "  - iam"
	@echo "  - network"
	@echo "  - cloud_storage  (or cloud-storage)"
	@echo "  - compute_engine (or compute-engine)"
	@echo "  - gke"
	@echo "  - serverless"
	@echo "  - bigquery"
	@echo ""
	@echo "Full Infrastructure Commands:"
	@echo "  make init                     # Run terraform init"
	@echo "  make plan                     # Plan entire infrastructure"
	@echo "  make apply                    # Apply entire infrastructure"
	@echo "  make destroy                  # Destroy entire infrastructure"
	@echo "  make fmt                      # Format all terraform files"
	@echo "  make validate                 # Validate terraform configuration"
	@echo "=================================================================="

# ------------------------------------------------------------------------------
# Core Terraform Commands
# ------------------------------------------------------------------------------
init:
	@echo "==> Initializing Terraform..."
	terraform init

fmt:
	@echo "==> Formatting Terraform files..."
	terraform fmt -recursive

validate:
	@echo "==> Validating Terraform files..."
	terraform validate

# ------------------------------------------------------------------------------
# Dynamic Plan / Apply / Destroy
# ------------------------------------------------------------------------------
plan:
	@if [ -z "$(CLEAN_MOD)" ]; then \
		echo "==> Planning ALL infrastructure..."; \
		terraform plan -var-file=$(VAR_FILE); \
	else \
		echo "==> Planning target: module.$(CLEAN_MOD)..."; \
		terraform plan -var-file=$(VAR_FILE) -target=module.$(CLEAN_MOD); \
	fi

apply:
	@if [ -z "$(CLEAN_MOD)" ]; then \
		echo "==> Applying ALL infrastructure..."; \
		terraform apply -var-file=$(VAR_FILE); \
	else \
		echo "==> Applying target: module.$(CLEAN_MOD)..."; \
		terraform apply -var-file=$(VAR_FILE) -target=module.$(CLEAN_MOD); \
	fi

destroy:
	@if [ -z "$(CLEAN_MOD)" ]; then \
		echo "==> WARNING: Destroying ALL infrastructure..."; \
		terraform destroy -var-file=$(VAR_FILE); \
	else \
		echo "==> Destroying target: module.$(CLEAN_MOD)..."; \
		terraform destroy -var-file=$(VAR_FILE) -target=module.$(CLEAN_MOD); \
	fi

# ------------------------------------------------------------------------------
# Direct Shortcut Targets (e.g., make plan-iam, make apply-iam)
# ------------------------------------------------------------------------------
plan-iam:
	terraform plan -var-file=$(VAR_FILE) -target=module.iam

apply-iam:
	terraform apply -var-file=$(VAR_FILE) -target=module.iam

destroy-iam:
	terraform destroy -var-file=$(VAR_FILE) -target=module.iam

plan-network:
	terraform plan -var-file=$(VAR_FILE) -target=module.network

apply-network:
	terraform apply -var-file=$(VAR_FILE) -target=module.network

destroy-network:
	terraform destroy -var-file=$(VAR_FILE) -target=module.network

plan-storage:
	terraform plan -var-file=$(VAR_FILE) -target=module.cloud_storage

apply-storage:
	terraform apply -var-file=$(VAR_FILE) -target=module.cloud_storage

destroy-storage:
	terraform destroy -var-file=$(VAR_FILE) -target=module.cloud_storage

destroy-cloud-storage:
	terraform destroy -var-file=$(VAR_FILE) -target=module.cloud_storage

destroy-cloud_storage:
	terraform destroy -var-file=$(VAR_FILE) -target=module.cloud_storage

plan-compute:
	terraform plan -var-file=$(VAR_FILE) -target=module.compute_engine

apply-compute:
	terraform apply -var-file=$(VAR_FILE) -target=module.compute_engine

destroy-compute:
	terraform destroy -var-file=$(VAR_FILE) -target=module.compute_engine

destroy-compute-engine:
	terraform destroy -var-file=$(VAR_FILE) -target=module.compute_engine

destroy-compute_engine:
	terraform destroy -var-file=$(VAR_FILE) -target=module.compute_engine

plan-gke:
	terraform plan -var-file=$(VAR_FILE) -target=module.gke

apply-gke:
	terraform apply -var-file=$(VAR_FILE) -target=module.gke

destroy-gke:
	terraform destroy -var-file=$(VAR_FILE) -target=module.gke

plan-serverless:
	terraform plan -var-file=$(VAR_FILE) -target=module.serverless

apply-serverless:
	terraform apply -var-file=$(VAR_FILE) -target=module.serverless

destroy-serverless:
	terraform destroy -var-file=$(VAR_FILE) -target=module.serverless

plan-bigquery:
	terraform plan -var-file=$(VAR_FILE) -target=module.bigquery

apply-bigquery:
	terraform apply -var-file=$(VAR_FILE) -target=module.bigquery

destroy-bigquery:
	terraform destroy -var-file=$(VAR_FILE) -target=module.bigquery


