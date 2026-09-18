# ==============================================================================
# 1. Local Role Definitions (Required Services)
# ==============================================================================
locals {
  # Core roles required for Terraform and Cloud Engineering administration
  terraform_roles = distinct(concat([
    # Cloud Storage
    "roles/storage.admin",

    # BigQuery
    "roles/bigquery.admin",

    # IAM & Service Accounts
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",

    # GKE (Google Kubernetes Engine) & Artifact Registry
    "roles/container.admin",
    "roles/artifactregistry.reader",

    # Pub/Sub
    "roles/pubsub.admin",

    # Serverless (Cloud Run & Cloud Functions)
    "roles/run.admin",
    "roles/cloudfunctions.admin",

    # Compute Engine
    "roles/compute.admin"
  ], var.additional_roles))
}

# ==============================================================================
# 2. Terraform Service Account
# ==============================================================================
resource "google_service_account" "terraform_sa" {
  account_id   = var.sa_id
  display_name = "Terraform Automation Service Account"
  description  = "Dedicated Service Account for Terraform CI/CD and infrastructure deployments"
  project      = var.project_id
}

# ==============================================================================
# 3. Project IAM Role Bindings for Terraform Service Account
# ==============================================================================
# Non-authoritative member bindings to avoid overwriting default GCP service agents
resource "google_project_iam_member" "terraform_sa_bindings" {
  for_each = toset(local.terraform_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}


# ==============================================================================
# 5. Service Account Impersonation Permissions (Security Best Practice)
# ==============================================================================
# Allows the personal user to impersonate the Terraform SA without downloading static JSON keys
resource "google_service_account_iam_member" "personal_user_token_creator" {
  count = var.personal_user_email != "" ? 1 : 0

  service_account_id = google_service_account.terraform_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.personal_user_email}"
}

resource "google_service_account_iam_member" "personal_user_sa_user" {
  count = var.personal_user_email != "" ? 1 : 0

  service_account_id = google_service_account.terraform_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.personal_user_email}"
}

# ==============================================================================
#  GitHub Actions Service Account & Permissions
# ==============================================================================
resource "google_service_account" "github_sa" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI Service Account"
  description  = "Service account for GitHub Actions CI to push images to Artifact Registry"
  project      = var.project_id
}

# 1. Grant roles/artifactregistry.writer and roles/container.developer to this SA
# 1. Grant roles/artifactregistry.writer and roles/container.admin to this SA
resource "google_project_iam_member" "github_sa_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_sa.email}"
}

resource "google_project_iam_member" "github_sa_gke_developer" {
resource "google_project_iam_member" "github_sa_gke_admin" {
  project = var.project_id
  role    = "roles/container.developer"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.github_sa.email}"
}

# 2. Allow your personal user to impersonate this GitHub SA
resource "google_service_account_iam_member" "personal_user_impersonate_github_sa" {
  count              = var.personal_user_email != "" ? 1 : 0
  service_account_id = google_service_account.github_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.personal_user_email}"
}

# ==============================================================================
# 5. Workload Identity Federation for GitHub Actions (100% Keyless CI/CD)
# ==============================================================================
# Dedicated pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions automated CI/CD"
  project                   = var.project_id
}

# Provider linking GitHub OIDC tokens to the pool
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == 'benjixxx/gcp-revision'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

# Authorize repository benjixxx/gcp-revision to impersonate github-actions-sa
resource "google_service_account_iam_member" "github_sa_workload_identity_user" {
  service_account_id = google_service_account.github_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/benjixxx/gcp-revision"
}

