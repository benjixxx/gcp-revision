resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Custom VPC network for ${var.environment} environment"
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.network_name}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.enable_gke_ranges ? [1] : []
    content {
      range_name    = var.pods_range_name
      ip_cidr_range = var.pods_cidr
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.enable_gke_ranges ? [1] : []
    content {
      range_name    = var.services_range_name
      ip_cidr_range = var.services_cidr
    }
  }
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.subnet_cidr]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google Cloud Identity-Aware Proxy (IAP) CIDR block
  source_ranges = ["35.235.240.0/20"]
}

