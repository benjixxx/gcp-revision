# ==============================================================================
# Private Services Access (Optional - when enable_private_ip is true)
# ==============================================================================
resource "google_compute_global_address" "private_ip_address" {
  count         = var.enable_private_ip && var.network_id != null ? 1 : 0
  name          = "${var.instance_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.enable_private_ip && var.network_id != null ? 1 : 0
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
}

# ==============================================================================
# Cloud SQL PostgreSQL Instance
# ==============================================================================
resource "google_sql_database_instance" "postgres" {
  name                = "${var.instance_name}-${var.environment}"
  database_version    = var.database_version
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    disk_size         = var.disk_size_gb
    disk_type         = var.disk_type
    disk_autoresize   = true
    availability_type = var.availability_type

    ip_configuration {
      ipv4_enabled    = var.enable_public_ip
      private_network = var.enable_private_ip ? var.network_id : null
      require_ssl     = var.require_ssl

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    backup_configuration {
      enabled                        = var.enable_backup
      start_time                     = "03:00"
      point_in_time_recovery_enabled = false
      transaction_log_retention_days = 7
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

# ==============================================================================
# Default PostgreSQL Database
# ==============================================================================
resource "google_sql_database" "database" {
  name      = var.database_name
  instance  = google_sql_database_instance.postgres.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# ==============================================================================
# Default PostgreSQL User
# ==============================================================================
resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
}

