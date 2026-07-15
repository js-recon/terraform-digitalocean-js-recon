locals {
  spaces_bucket_name = var.spaces_bucket_name != "" ? var.spaces_bucket_name : "${var.droplet_name}-${random_id.bucket_suffix[0].hex}"
}

resource "random_id" "bucket_suffix" {
  count       = var.create_spaces_bucket && var.spaces_bucket_name == "" ? 1 : 0
  byte_length = 4
}

# ─── Spaces bucket ────────────────────────────────────────────────────────────

resource "digitalocean_spaces_bucket" "artifacts" {
  count  = var.create_spaces_bucket ? 1 : 0
  name   = local.spaces_bucket_name
  region = var.region
  acl    = "private"
}

# ─── Droplet ──────────────────────────────────────────────────────────────────

resource "digitalocean_droplet" "js_recon" {
  name   = var.droplet_name
  region = var.region
  size   = var.droplet_size
  image  = "docker-20-04"

  ssh_keys = var.ssh_keys
  tags     = var.tags

  user_data = <<-USERDATA
    #!/bin/bash
    set -e

    # ── Terraform-resolved configuration ──────────────────────────────────────
    JSR_URL="${var.url}"
    JSR_VERSION="${var.js_recon_version}"
    JSR_BREAK_ON_MAP="${var.break_on_map_files}"
    JSR_BREAK_ON_VULNS="${var.break_on_vulnerabilities}"
    JSR_SEVERITY="${var.vulnerability_severity}"
    JSR_OUTPUT_DIR="${var.output_dir}"
    JSR_BUCKET="${var.create_spaces_bucket ? local.spaces_bucket_name : ""}"
    JSR_BUCKET_REGION="${var.region}"
    JSR_ARTIFACT_PREFIX="${var.spaces_artifact_prefix}"
    JSR_SPACES_KEY="${var.spaces_access_id}"
    JSR_SPACES_SECRET="${var.spaces_secret_key}"
    SCAN_TIMEOUT="${var.build_timeout * 60}"

    # ── Write inner scan script (runs inside the Puppeteer container) ─────────
    mkdir -p /tmp/js-recon-output
    chmod 777 /tmp/js-recon-output

    cat > /tmp/js-recon-inner.sh << 'INNER_SCAN'
    #!/bin/bash
    set -e
    npm config set prefix /home/pptruser/.npm-global
    export PATH="/home/pptruser/.npm-global/bin:$PATH"

    echo "[js-recon] Installing @js-recon/js-recon@$JSR_VERSION..."
    npm install -g "@js-recon/js-recon@$JSR_VERSION"
    INSTALLED_VERSION=$(js-recon --version 2>/dev/null || echo "unknown")
    echo "[js-recon] Installed version: $INSTALLED_VERSION"

    echo "[js-recon] Running js-recon against $JSR_URL..."
    js-recon run -u "$JSR_URL" -o "$JSR_OUTPUT_DIR" --no-sandbox -y -k || {
      echo "[js-recon] ERROR: js-recon run failed."
      exit 1
    }
    echo "[js-recon] Scan complete."

    HOST_DIR=$(echo "$JSR_URL" | sed 's|https\?://||' | sed 's|[/?].*||' | tr ':' '_')
    mkdir -p "$JSR_OUTPUT_DIR/$HOST_DIR"
    for f in analyze.json mapped.json mapped-openapi.json endpoints.json strings.json report.html report.db js-recon.db; do
      [ -f "$f" ] && mv "$f" "$JSR_OUTPUT_DIR/$HOST_DIR/" 2>/dev/null || true
    done

    MAP_FILES=$(find "$JSR_OUTPUT_DIR" -name "*.map" 2>/dev/null | head -50)
    if [ -n "$MAP_FILES" ]; then
      echo "[js-recon] Source map files detected:"
      echo "$MAP_FILES"
      if [ "$JSR_BREAK_ON_MAP" = "true" ]; then
        echo "[js-recon] ERROR: Source map files are publicly accessible. Set break_on_map_files = false to suppress."
        exit 1
      fi
    fi

    ANALYZE_JSON=$(find "$JSR_OUTPUT_DIR" -name "analyze.json" 2>/dev/null | head -1)
    if [ -n "$ANALYZE_JSON" ] && [ "$JSR_BREAK_ON_VULNS" = "true" ]; then
      node -e "
    const fs = require('fs');
    const RANK = {info: 0, low: 1, medium: 2, high: 3};
    let findings = [];
    try { findings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); } catch {
      console.log('[js-recon] analyze.json is empty or invalid. Skipping.');
      process.exit(0);
    }
    if (!Array.isArray(findings) || findings.length === 0) {
      console.log('[js-recon] No findings in analyze.json.');
      process.exit(0);
    }
    const severity = process.argv[2];
    const threshold = RANK[severity] ?? 3;
    const matched = findings.filter(f => (RANK[f.severity?.toLowerCase()] ?? -1) >= threshold);
    if (matched.length === 0) {
      console.log('[js-recon] No findings at or above severity \"' + severity + '\".');
      process.exit(0);
    }
    console.log('[js-recon] ' + matched.length + ' finding(s) at or above severity \"' + severity + '\":\n');
    console.log('Rule'.padEnd(40) + ' ' + 'Severity'.padEnd(10) + ' Location');
    console.log('-'.repeat(80));
    for (const f of matched) {
      const rule = (f.ruleName || f.ruleId || 'unknown').substring(0, 39).padEnd(40);
      const sev  = (f.severity || '?').padEnd(10);
      const loc  = f.findingLocation || '';
      console.log(rule + ' ' + sev + ' ' + loc);
    }
    console.log('\n[js-recon] ERROR: ' + matched.length + ' vulnerability/vulnerabilities at severity \"' + severity + '\" or above.');
    process.exit(matched.length > 255 ? 255 : matched.length);
      " "$ANALYZE_JSON" "$JSR_SEVERITY" || exit 1
    fi

    cp -r "$JSR_OUTPUT_DIR/." /scan-output/
    INNER_SCAN
    chmod +x /tmp/js-recon-inner.sh

    # ── Write Docker run wrapper ──────────────────────────────────────────────
    cat > /usr/local/bin/js-recon-scan << WRAPPER
    #!/bin/bash
    set -e
    docker run --rm \
      -v /tmp/js-recon-inner.sh:/tmp/js-recon-inner.sh:ro \
      -v /tmp/js-recon-output:/scan-output \
      -e JSR_URL="$JSR_URL" \
      -e JSR_VERSION="$JSR_VERSION" \
      -e JSR_BREAK_ON_MAP="$JSR_BREAK_ON_MAP" \
      -e JSR_BREAK_ON_VULNS="$JSR_BREAK_ON_VULNS" \
      -e JSR_SEVERITY="$JSR_SEVERITY" \
      -e JSR_OUTPUT_DIR="$JSR_OUTPUT_DIR" \
      -e PUPPETEER_SKIP_DOWNLOAD=true \
      -e IS_DOCKER=true \
      -e NODE_OPTIONS="--max-http-header-size=99999999" \
      -e PUPPETEER_CACHE_DIR=/home/pptruser/.cache/puppeteer \
      --stop-timeout "$SCAN_TIMEOUT" \
      ghcr.io/puppeteer/puppeteer:24.43.1 \
      /bin/bash /tmp/js-recon-inner.sh

    if [ -n "$JSR_BUCKET" ] && [ -n "$JSR_SPACES_KEY" ]; then
      echo "[js-recon] Uploading artifacts to DigitalOcean Spaces..."
      export AWS_ACCESS_KEY_ID="$JSR_SPACES_KEY"
      export AWS_SECRET_ACCESS_KEY="$JSR_SPACES_SECRET"
      aws s3 sync /tmp/js-recon-output/ \
        "s3://$JSR_BUCKET/$JSR_ARTIFACT_PREFIX/" \
        --endpoint-url "https://$JSR_BUCKET_REGION.digitaloceanspaces.com" \
        --region "$JSR_BUCKET_REGION"
      echo "[js-recon] Artifacts uploaded to s3://$JSR_BUCKET/$JSR_ARTIFACT_PREFIX/"
    fi
    WRAPPER
    chmod +x /usr/local/bin/js-recon-scan

    # ── Pull image ────────────────────────────────────────────────────────────
    docker pull ghcr.io/puppeteer/puppeteer:24.43.1

    # ── Install AWS CLI for Spaces upload ────────────────────────────────────
    apt-get update -y -qq
    apt-get install -y -qq awscli

    # ── Schedule or run immediately ───────────────────────────────────────────
    if [ -n "${var.schedule}" ]; then
      echo "[js-recon] Installing cron schedule: ${var.schedule}"
      echo "${var.schedule} root /usr/local/bin/js-recon-scan >> /var/log/js-recon.log 2>&1" \
        > /etc/cron.d/js-recon
      chmod 644 /etc/cron.d/js-recon
      service cron reload
      echo "[js-recon] Cron installed. First run at next scheduled time."
    else
      echo "[js-recon] Running scan now..."
      /usr/local/bin/js-recon-scan 2>&1 | tee /var/log/js-recon.log
    fi
  USERDATA
}
