variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "source_zip_path" {
  description = "Path to the zipped source code for Cloud Functions"
  type        = string
}

variable "source_hash" {
  description = "Hash of the source zip (used for cache-busting the GCS object name)"
  type        = string
}

variable "cloudrift_api_url" {
  description = "CloudRift API base URL"
  type        = string
  default     = "https://api.cloudrift.ai"
}

variable "cloudrift_with_public_ip" {
  description = "Whether to assign a public IP to runner VMs"
  type        = string
  default     = "false"
}

variable "runner_label" {
  description = "GitHub Actions label that triggers CloudRift provisioning"
  type        = string
  default     = "cloudrift"
}

variable "max_runner_lifetime_minutes" {
  description = "Maximum lifetime for a runner VM in minutes"
  type        = string
  default     = "120"
}
