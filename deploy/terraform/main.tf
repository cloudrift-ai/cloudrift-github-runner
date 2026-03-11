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

# --- Secret Manager ---

resource "google_secret_manager_secret" "cloudrift_api_key" {
  secret_id = "cloudrift-runner-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "github_pat" {
  secret_id = "cloudrift-runner-github-pat"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "webhook_secret" {
  secret_id = "cloudrift-runner-webhook-secret"
  replication {
    auto {}
  }
}

# --- Service Account ---

resource "google_service_account" "runner_sa" {
  account_id   = "cloudrift-runner"
  display_name = "CloudRift GitHub Runner Controller"
}

resource "google_project_iam_member" "firestore_access" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.runner_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "api_key_access" {
  secret_id = google_secret_manager_secret.cloudrift_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "pat_access" {
  secret_id = google_secret_manager_secret.github_pat.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "webhook_secret_access" {
  secret_id = google_secret_manager_secret.webhook_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner_sa.email}"
}

# --- Firestore ---

resource "google_firestore_database" "runner_db" {
  name        = "cloudrift-runners"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  # TTL policy is configured at the field level via application code
}

# --- Cloud Storage (source code) ---

resource "google_storage_bucket" "source" {
  name     = "${var.project_id}-cloudrift-runner-source"
  location = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "source_zip" {
  name   = "cloudrift-runner-${var.source_hash}.zip"
  bucket = google_storage_bucket.source.name
  source = var.source_zip_path
}

# --- Cloud Functions (gen2) ---

resource "google_cloudfunctions2_function" "webhook" {
  name     = "cloudrift-runner-webhook"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "handle_webhook"
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.runner_sa.email

    environment_variables = {
      CLOUDRIFT_API_URL           = var.cloudrift_api_url
      CLOUDRIFT_WITH_PUBLIC_IP    = var.cloudrift_with_public_ip
      RUNNER_LABEL                = var.runner_label
      MAX_RUNNER_LIFETIME_MINUTES = var.max_runner_lifetime_minutes
    }

    secret_environment_variables {
      key        = "CLOUDRIFT_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.cloudrift_api_key.secret_id
      version    = "latest"
    }
    secret_environment_variables {
      key        = "GITHUB_PAT"
      project_id = var.project_id
      secret     = google_secret_manager_secret.github_pat.secret_id
      version    = "latest"
    }
    secret_environment_variables {
      key        = "GITHUB_WEBHOOK_SECRET"
      project_id = var.project_id
      secret     = google_secret_manager_secret.webhook_secret.secret_id
      version    = "latest"
    }
  }
}

# Allow unauthenticated access (GitHub webhooks)
resource "google_cloud_run_service_iam_member" "webhook_invoker" {
  location = var.region
  service  = google_cloudfunctions2_function.webhook.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloudfunctions2_function" "cleanup" {
  name     = "cloudrift-runner-cleanup"
  location = var.region

  build_config {
    runtime     = "python311"
    entry_point = "cleanup_orphans_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.runner_sa.email

    environment_variables = {
      CLOUDRIFT_API_URL           = var.cloudrift_api_url
      MAX_RUNNER_LIFETIME_MINUTES = var.max_runner_lifetime_minutes
    }

    secret_environment_variables {
      key        = "CLOUDRIFT_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.cloudrift_api_key.secret_id
      version    = "latest"
    }
    secret_environment_variables {
      key        = "GITHUB_PAT"
      project_id = var.project_id
      secret     = google_secret_manager_secret.github_pat.secret_id
      version    = "latest"
    }
    secret_environment_variables {
      key        = "GITHUB_WEBHOOK_SECRET"
      project_id = var.project_id
      secret     = google_secret_manager_secret.webhook_secret.secret_id
      version    = "latest"
    }
  }
}

# --- Cloud Scheduler ---

resource "google_cloud_scheduler_job" "cleanup_schedule" {
  name     = "cloudrift-runner-cleanup"
  schedule = "*/10 * * * *"
  region   = var.region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.cleanup.url

    oidc_token {
      service_account_email = google_service_account.runner_sa.email
    }
  }
}
