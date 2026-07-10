output "droplet_name" {
  description = "Name of the Droplet running JS Recon"
  value       = digitalocean_droplet.js_recon.name
}

output "droplet_id" {
  description = "ID of the Droplet"
  value       = digitalocean_droplet.js_recon.id
}

output "droplet_ip" {
  description = "Public IPv4 address of the Droplet"
  value       = digitalocean_droplet.js_recon.ipv4_address
}

output "spaces_bucket_name" {
  description = "Name of the Spaces bucket where JS Recon artifacts are stored"
  value       = var.create_spaces_bucket ? digitalocean_spaces_bucket.artifacts[0].name : var.spaces_bucket_name
}

output "spaces_bucket_urn" {
  description = "URN of the Spaces bucket"
  value       = var.create_spaces_bucket ? digitalocean_spaces_bucket.artifacts[0].urn : null
}

output "spaces_bucket_endpoint" {
  description = "HTTPS endpoint for the Spaces bucket"
  value       = var.create_spaces_bucket ? "https://${local.spaces_bucket_name}.${var.region}.digitaloceanspaces.com" : null
}
