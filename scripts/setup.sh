#!/usr/bin/env bash
#
# Home SOC — one-shot bootstrap for the Wazuh single-node stack.
#
# What it does:
#   1. Pre-flight checks (docker, compose, kernel setting)
#   2. Creates deploy/.env from the template if missing
#   3. Generates the indexer/manager/dashboard TLS certificates (once)
#   4. Brings the stack up
#   5. Waits for the indexer to answer, then deploys custom detection content
#   6. Prints how to reach the dashboard
#
# Safe to re-run: every step is idempotent.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MAX_MAP_COUNT_MIN=262144

log "Pre-flight checks"
require_docker

# OpenSearch (the indexer) refuses to start without a large mmap limit.
current_mmc="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
if [ "$current_mmc" -lt "$MAX_MAP_COUNT_MIN" ]; then
  warn "vm.max_map_count is $current_mmc (need >= $MAX_MAP_COUNT_MIN). Raising it now (needs sudo)."
  sudo sysctl -w vm.max_map_count=$MAX_MAP_COUNT_MIN
  if ! grep -q '^vm.max_map_count' /etc/sysctl.conf 2>/dev/null; then
    echo "vm.max_map_count=$MAX_MAP_COUNT_MIN" | sudo tee -a /etc/sysctl.conf >/dev/null
    ok "Made vm.max_map_count persistent in /etc/sysctl.conf"
  fi
else
  ok "vm.max_map_count = $current_mmc"
fi

# .env
if [ ! -f "$DEPLOY_DIR/.env" ]; then
  cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
  ok "Created deploy/.env from template (edit it to change the Wazuh version or heap size)."
fi

# Certificates — only generate once.
CERT_DIR="$DEPLOY_DIR/config/wazuh_indexer_ssl_certs"
if [ ! -f "$CERT_DIR/root-ca.pem" ]; then
  log "Generating TLS certificates (first run only)"
  dc -f generate-indexer-certs.yml run --rm generator
  ok "Certificates written to deploy/config/wazuh_indexer_ssl_certs/ (git-ignored)."
else
  ok "Certificates already present — skipping generation."
fi

log "Starting the stack (this pulls ~2 GB of images on first run)"
dc up -d

log "Waiting for the Wazuh indexer to become reachable (up to 5 minutes)..."
deadline=$(( $(date +%s) + 300 ))
until curl -sk -u admin:SecretPassword https://localhost:9200/_cluster/health >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    err "Indexer did not come up in time. Check logs with:  make logs"
    exit 1
  fi
  sleep 5
done
ok "Indexer is up."

log "Deploying custom detection content"
"$LIB_DIR/deploy-rules.sh" || warn "Rule deployment reported a problem — review the output above."

host_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo '<this-host-ip>')"
cat <<EOF

${C_GRN}==============================================================${C_RESET}
  Home SOC is up.
${C_GRN}==============================================================${C_RESET}
  Dashboard : https://localhost/            (or https://$host_ip/ from other hosts)
  Login     : admin / SecretPassword        (CHANGE THIS — see docs/10-hardening.md)

  Enroll an endpoint (run on the victim VM / host):
    sudo MANAGER_IP=$host_ip bash scripts/install-agent-linux.sh

  Check health any time:   make health
  Tail logs:               make logs
${C_GRN}==============================================================${C_RESET}
EOF
