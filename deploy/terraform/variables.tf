variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the VM"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-small"
}

variable "domain" {
  description = "Domain name for TLS (must have DNS pointing to the VM IP)"
  type        = string
}

variable "cloudrift_api_key" {
  description = "CloudRift API key"
  type        = string
  sensitive   = true
}

variable "github_pat" {
  description = "GitHub PAT with administration:write scope"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook HMAC secret"
  type        = string
  sensitive   = true
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
