output "webhook_url" {
  description = "URL to configure as the GitHub webhook endpoint"
  value       = google_cloudfunctions2_function.webhook.url
}

output "cleanup_url" {
  description = "URL of the cleanup Cloud Function"
  value       = google_cloudfunctions2_function.cleanup.url
}

output "service_account_email" {
  description = "Service account used by the Cloud Functions"
  value       = google_service_account.runner_sa.email
}
