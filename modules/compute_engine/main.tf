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
    subnetwork = var.subnet_id

    # Omit access_config block for a private VM (secure by default with IAP)
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["ssh-enabled", "${var.environment}-node"]

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = var.environment
  }
}

