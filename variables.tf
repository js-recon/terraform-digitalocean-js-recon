variable "url" {
  description = "Target URL to scan (e.g. https://example.com or http://localhost:3000)"
  type        = string
}

variable "js_recon_version" {
  description = "JS Recon version to install — passed to npm install -g @shriyanss/js-recon@<version> (e.g. latest, alpha, 1.3.1-beta.1)"
  type        = string
  default     = "latest"
}

variable "break_on_map_files" {
  description = "Fail the job if .map source map files are detected in the output"
  type        = bool
  default     = true
}

variable "break_on_vulnerabilities" {
  description = "Fail the job if vulnerabilities at or above the configured severity are detected"
  type        = bool
  default     = true
}

variable "vulnerability_severity" {
  description = "Minimum severity to fail on: low, medium, or high"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["low", "medium", "high"], var.vulnerability_severity)
    error_message = "vulnerability_severity must be one of: low, medium, high"
  }
}

variable "output_dir" {
  description = "Directory inside the container where JS Recon output files are saved"
  type        = string
  default     = "js-recon-output"
}

variable "droplet_name" {
  description = "Name for the Droplet and prefix for all other resources"
  type        = string
  default     = "js-recon"
}

variable "region" {
  description = "DigitalOcean region for the Droplet and Spaces bucket (e.g. nyc3, ams3, sgp1)"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size slug — must have at least 4 GB RAM for Puppeteer/Chrome"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_keys" {
  description = "List of SSH key IDs or fingerprints to add to the Droplet for manual access"
  type        = list(string)
  default     = []
}

variable "create_spaces_bucket" {
  description = "Whether to create a DigitalOcean Spaces bucket for storing JS Recon output artifacts"
  type        = bool
  default     = true
}

variable "spaces_bucket_name" {
  description = "Name of the Spaces bucket. Must be globally unique. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "spaces_artifact_prefix" {
  description = "Object key prefix for uploaded artifacts inside the Spaces bucket"
  type        = string
  default     = "js-recon-output"
}

variable "spaces_access_id" {
  description = "DigitalOcean Spaces access key ID — required when create_spaces_bucket = true. Generate at: cloud.digitalocean.com → API → Spaces Keys."
  type        = string
  default     = ""
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret access key — required when create_spaces_bucket = true"
  type        = string
  default     = ""
  sensitive   = true
}

variable "schedule" {
  description = "Cron expression for automated scans (e.g. 0 8 * * *). Leave empty to run once at Droplet creation."
  type        = string
  default     = ""
}

variable "build_timeout" {
  description = "Maximum duration in minutes for a single scan job (used as Docker --stop-timeout)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "List of tag names to apply to the Droplet"
  type        = list(string)
  default     = []
}
