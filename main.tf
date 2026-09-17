# ==============================================================================
# 1. IAM Module (Service Account & Security Roles)
# ==============================================================================
module "iam" {
  source = "./modules/iam"

  project_id          = var.project_id
  sa_id               = var.sa_id
  personal_user_email = var.personal_user_email
  additional_roles    = var.additional_roles
}

# ==============================================================================
# 2. Network Module (VPC, Subnets, Cloud Router & NAT)
# ==============================================================================
module "network" {
  source = "./modules/network"

  network_name        = var.network_name
  region              = var.region
  environment         = var.environment
  subnet_cidr         = var.subnet_cidr
  pods_cidr           = var.pods_cidr
  services_cidr       = var.services_cidr
  pods_range_name     = var.pods_range_name
  services_range_name = var.services_range_name
}

# ==============================================================================
# 3. Cloud Storage Module (Buckets & Security)
# ==============================================================================
module "cloud_storage" {
  source = "./modules/cloud_storage"

  bucket_name = var.bucket_name
  location    = var.region
  environment = var.environment
  versioning  = var.bucket_versioning
}

# ==============================================================================
# 4. Compute Engine Module (VM Instances)
# ==============================================================================
module "compute_engine" {
  source = "./modules/compute_engine"

  instance_name         = var.instance_name
  machine_type          = var.compute_machine_type
  zone                  = var.zone
  network               = "default"
  subnet_id             = null # Set to module.network.subnet_id if you want to use your custom VPC later
  enable_public_ip      = true
  service_account_email = module.iam.terraform_service_account_email
  environment           = var.environment
  enable_load_balancer  = var.enable_load_balancer
  mig_target_size       = var.mig_target_size
  startup_script        = file("${path.module}/qualityAirApp/startup-script.sh")
}

# ==============================================================================
# 5. GKE Module (Kubernetes Cluster & Node Pool)
# ==============================================================================
module "gke" {
  source = "./modules/gke"

  cluster_name          = var.cluster_name
  region                = var.region
  network_id            = module.network.network_id
  subnet_name           = module.network.subnet_name
  pods_range_name       = module.network.pods_range_name
  services_range_name   = module.network.services_range_name
  service_account_email = module.iam.terraform_service_account_email
  node_count            = var.gke_node_count
  machine_type          = var.gke_machine_type
  environment           = var.environment
}

# ==============================================================================
# 6. Serverless Module (Cloud Run Service)
# ==============================================================================
module "serverless" {
  source = "./modules/serverless"

  service_name          = var.serverless_service_name
  region                = var.region
  container_image       = var.serverless_container_image
  service_account_email = module.iam.terraform_service_account_email
  allow_unauthenticated = var.serverless_allow_unauthenticated
  min_instances         = var.serverless_min_instances
  max_instances         = var.serverless_max_instances
  environment           = var.environment
}

# ==============================================================================
# 7. BigQuery Module (Dataset & Partitioned/Clustered Tables)
# ==============================================================================
module "bigquery" {
  source = "./modules/BigQuery"

  dataset_id        = var.bigquery_dataset_id
  location          = var.bigquery_location
  table_id          = var.bigquery_table_id
  partition_field   = var.bigquery_partition_field
  clustering_fields = var.bigquery_clustering_fields
  environment       = var.environment
}