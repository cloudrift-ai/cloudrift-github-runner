terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# --- Networking ---

resource "google_compute_address" "runner" {
  name   = "cloudrift-runner-ip"
  region = var.region
}

resource "google_compute_firewall" "runner" {
  name    = "cloudrift-runner-allow"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["cloudrift-runner"]
}

# --- Compute Instance ---

resource "google_compute_instance" "runner" {
  name         = "cloudrift-runner"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["cloudrift-runner"]

  boot_disk {
    initialize_params {
      image = "projects/cos-cloud/global/images/family/cos-stable"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.runner.address
    }
  }

  metadata = {
    "user-data" = templatefile("${path.module}/cloud-init.yml.tpl", {
      domain                = var.domain
      cloudrift_api_key     = var.cloudrift_api_key
      github_pat            = var.github_pat
      github_webhook_secret = var.github_webhook_secret
      cloudrift_api_url     = var.cloudrift_api_url
      cloudrift_with_public_ip    = var.cloudrift_with_public_ip
      runner_label                = var.runner_label
      max_runner_lifetime_minutes = var.max_runner_lifetime_minutes
    })
  }

  service_account {
    scopes = ["logging-write", "monitoring-write"]
  }
}
