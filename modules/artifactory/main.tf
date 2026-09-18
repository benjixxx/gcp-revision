# Artifact Registry Docker Repository
resource "google_artifact_registry_repository" "quality_air_repo" {
  location      = var.region
  repository_id = "quality-air-repo"
  description   = "Docker repository for QualityAirApp"
  format        = "DOCKER"
}

