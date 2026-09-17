# ==============================================================================
# 1. Standalone Compute Engine Instance (Used when enable_load_balancer = false)
# ==============================================================================
resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.subnet_id == null ? var.network : null
    subnetwork = var.subnet_id

    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["ssh-enabled", "http-server", "${var.environment}-node"]

  metadata = merge(
    {
      enable-oslogin = "TRUE"
    },
    var.startup_script != null ? { startup-script = var.startup_script } : {}
  )

  labels = {
    environment = var.environment
  }
}

# ==============================================================================
# 2. Instance Template (Used when enable_load_balancer = true)
# ==============================================================================
resource "google_compute_instance_template" "app_template" {
  count        = var.enable_load_balancer ? 1 : 0
  name_prefix  = "${var.instance_name}-template-"
  machine_type = var.machine_type
  region       = join("-", slice(split("-", var.zone), 0, 2))

  disk {
    source_image = var.os_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size
    disk_type    = "pd-standard"
  }

  network_interface {
    network    = var.subnet_id == null ? var.network : null
    subnetwork = var.subnet_id

    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["ssh-enabled", "http-server", "${var.environment}-node", "mig-node"]

  metadata = merge(
    {
      enable-oslogin = "TRUE"
    },
    var.startup_script != null ? { startup-script = var.startup_script } : {}
  )

  labels = {
    environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# 3. Managed Instance Group (MIG with target_size = 3)
# ==============================================================================
resource "google_compute_instance_group_manager" "app_mig" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.instance_name}-mig"
  base_instance_name = "${var.instance_name}-node"
  zone               = var.zone
  target_size        = var.mig_target_size

  version {
    instance_template = google_compute_instance_template.app_template[0].id
  }

  named_port {
    name = "http"
    port = 8080
  }
}

# ==============================================================================
# 4. HTTP Health Check (Probes /health on port 8080)
# ==============================================================================
resource "google_compute_health_check" "app_hc" {
  count               = var.enable_load_balancer ? 1 : 0
  name                = "${var.instance_name}-hc"
  check_interval_sec  = 5
  timeout_sec         = 3
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    request_path = "/health"
    port         = 8080
  }
}

# ==============================================================================
# 5. Cloud HTTP Load Balancer Components
# ==============================================================================
resource "google_compute_backend_service" "app_backend" {
  count                 = var.enable_load_balancer ? 1 : 0
  name                  = "${var.instance_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.app_hc[0].id]

  backend {
    group           = google_compute_instance_group_manager.app_mig[0].instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "app_url_map" {
  count           = var.enable_load_balancer ? 1 : 0
  name            = "${var.instance_name}-url-map"
  default_service = google_compute_backend_service.app_backend[0].id
}

resource "google_compute_target_http_proxy" "app_http_proxy" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "${var.instance_name}-http-proxy"
  url_map = google_compute_url_map.app_url_map[0].id
}

resource "google_compute_global_forwarding_rule" "app_forwarding_rule" {
  count                 = var.enable_load_balancer ? 1 : 0
  name                  = "${var.instance_name}-forwarding-rule"
  target                = google_compute_target_http_proxy.app_http_proxy[0].id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
}

# ==============================================================================
# 6. Firewall Rule for Load Balancer & Health Checks
# ==============================================================================
resource "google_compute_firewall" "allow_lb_health_checks" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "${var.instance_name}-allow-lb-hc"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  # Google Cloud Load Balancer and Health Check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["http-server"]
}
