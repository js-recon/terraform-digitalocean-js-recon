# Changelog

## 1.0.0 — 2026-07-10

Initial release.

- DigitalOcean Droplet that runs JS Recon against any URL using the Puppeteer Docker image
- Optional DigitalOcean Spaces bucket for artifact storage
- Optional cron schedule for recurring scans
- Inputs mirroring the GitHub Action and GitLab CI component: `url`, `js_recon_version`, `break_on_map_files`, `break_on_vulnerabilities`, `vulnerability_severity`, `output_dir`
- Outputs: `droplet_name`, `droplet_id`, `droplet_ip`, `spaces_bucket_name`, `spaces_bucket_urn`, `spaces_bucket_endpoint`
- Examples: `basic/` (on-demand) and `scheduled/` (daily cron)
