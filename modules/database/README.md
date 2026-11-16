# 🐘 Cloud SQL (PostgreSQL) Module

This module provisions and manages a Google Cloud SQL managed PostgreSQL database instance, including initial database creation, user provisioning, network connectivity (public IP and/or private VPC peering), and backup policies.

---

## 🚀 Resources Managed

- **`google_sql_database_instance.postgres`**: Fully managed PostgreSQL server instance on GCP.
- **`google_sql_database.database`**: Default application database (`UTF-8` charset).
- **`google_sql_user.user`**: Application database user and credential configuration.
- **`google_compute_global_address` & `google_service_networking_connection`**: (Optional) VPC Peering configuration for internal RFC 1918 private IP access.

---

## 🛠️ Usage Example

```hcl
module "database" {
  source = "./modules/database"

  instance_name       = "quality-air-db"
  database_version    = "POSTGRES_15"
  region              = var.region
  environment         = var.environment
  tier                = "db-f1-micro"
  disk_size_gb        = 10
  deletion_protection = false

  enable_public_ip    = true
  enable_private_ip   = false
  network_id          = module.network.network_id

  database_name       = "quality_air_db"
  database_user       = "quality_air_admin"
  database_password   = "SuperSecretPassword123!"
}
```

---

## 🔌 Connection Methods

### 1. Connecting via Cloud SQL Auth Proxy (Recommended for Dev & Kube)
```bash
# Download and run Cloud SQL proxy locally
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.13.0/cloud-sql-proxy.darwin.arm64
chmod +x cloud-sql-proxy
./cloud-sql-proxy <INSTANCE_CONNECTION_NAME>

# Connect via standard psql
psql -h 127.0.0.1 -p 5432 -U quality_air_admin -d quality_air_db
```

### 2. Connecting from GKE Workloads
You can run the Cloud SQL Proxy as a sidecar container in Kubernetes pods or connect directly using the private IP if VPC peering is enabled.

