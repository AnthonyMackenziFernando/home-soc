#!/usr/bin/env bash
#
# Deploy this repo's custom detection content into the running Wazuh manager.
#
# This is the "rule deployment pipeline" for the lab: instead of editing files
# inside the container by hand, detection content lives in git and is pushed in,
# validated, and hot-reloaded — the same shape as a real detection-as-code flow.
#
# Steps:
#   1. Copy local_rules.xml / local_decoder.xml into the manager
#   2. Copy the shared agent.conf (centralised agent config) into the default group
#   3. Validate the ruleset with wazuh-analysisd -t  (aborts on syntax error)
#   4. Restart the manager so the new rules take effect
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SVC="wazuh.manager"
RULES_SRC="$REPO_ROOT/detections/wazuh-rules"
AGENT_CONF="$REPO_ROOT/deploy/config/wazuh_cluster/agent.conf"

require_docker
dc ps "$SVC" >/dev/null 2>&1 || die "The $SVC service isn't running. Start the stack first: make up"

log "Copying detection content into $SVC"
dc cp "$RULES_SRC/local_rules.xml"    "$SVC:/var/ossec/etc/rules/local_rules.xml"
dc cp "$RULES_SRC/local_decoder.xml"  "$SVC:/var/ossec/etc/decoders/local_decoder.xml"

if [ -f "$AGENT_CONF" ]; then
  # Centralised configuration pushed to every agent in the 'default' group.
  dc exec -u root "$SVC" mkdir -p /var/ossec/etc/shared/default
  dc cp "$AGENT_CONF" "$SVC:/var/ossec/etc/shared/default/agent.conf"
  dc exec -u root "$SVC" chown -R wazuh:wazuh /var/ossec/etc/shared/default
fi

dc exec -u root "$SVC" chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/decoders/local_decoder.xml

log "Validating ruleset (wazuh-analysisd -t)"
if ! dc exec -u wazuh "$SVC" /var/ossec/bin/wazuh-analysisd -t; then
  die "Ruleset failed validation — the manager was NOT restarted. Fix the reported error and re-run."
fi
ok "Ruleset is valid."

log "Restarting $SVC to load new rules"
dc restart "$SVC" >/dev/null
ok "Detection content deployed. New alerts will use the updated ruleset."
