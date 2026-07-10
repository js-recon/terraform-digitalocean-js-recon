provider "digitalocean" {
  # token = var.do_token  # set via DIGITALOCEAN_TOKEN env var
}

module "js_recon" {
  source = "../../"

  url      = "https://example.com"
  schedule = "0 8 * * *"

  break_on_map_files       = true
  break_on_vulnerabilities = true
  vulnerability_severity   = "high"

  spaces_access_id  = var.spaces_access_id
  spaces_secret_key = var.spaces_secret_key

  tags = ["security"]
}

variable "spaces_access_id" {
  description = "DigitalOcean Spaces access key ID"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret access key"
  type        = string
  sensitive   = true
}

output "droplet_name" {
  value = module.js_recon.droplet_name
}

output "spaces_bucket_name" {
  value = module.js_recon.spaces_bucket_name
}
