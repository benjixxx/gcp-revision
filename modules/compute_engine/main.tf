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

