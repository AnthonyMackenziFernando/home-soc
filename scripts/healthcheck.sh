#!/usr/bin/env bash
#
# Quick health snapshot of the Home SOC stack: container state, indexer cluster
# health, and the list of enrolled agents (via the Wazuh REST API).
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_docker

log "Container status"
dc ps

echo
log "Indexer cluster health"
curl -sk -u admin:SecretPassword https://localhost:9200/_cluster/health 2>/dev/null \
  | sed 's/,/,\n  /g' || warn "Could not reach the indexer on https://localhost:9200"

echo
log "Enrolled agents (Wazuh API)"
# The API needs a short-lived JWT first.
TOKEN="$(curl -sk -u wazuh-wui:MyS3cr37P450r.*- -X POST \
  'https://localhost:55000/security/user/authenticate?raw=true' 2>/dev/null || true)"
if [ -n "${TOKEN:-}" ]; then
  curl -sk -H "Authorization: Bearer $TOKEN" \
    'https://localhost:55000/agents?select=id,name,ip,status,os.name&pretty=true' 2>/dev/null \
    | grep -E '"(id|name|ip|status)"' || warn "No agent data returned."
else
  warn "Could not authenticate to the Wazuh API on https://localhost:55000"
fi

echo
ok "Health check complete. Full dashboard: https://localhost/"
