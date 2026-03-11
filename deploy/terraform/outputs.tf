output "webhook_url" {
  description = "URL to configure as the GitHub webhook endpoint"
  value       = "https://${var.domain}/webhook"
}

output "vm_ip" {
  description = "Static IP address of the runner VM"
  value       = google_compute_address.runner.address
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh ${google_compute_instance.runner.name} --zone=${var.zone}"
}
