#!/usr/bin/env bash
#
# Install and enrol a Wazuh agent on a Debian/Ubuntu endpoint (the host laptop
# or a victim VM), and wire up the extra log sources this lab uses.
#
# Run ON THE ENDPOINT you want to monitor:
#     sudo MANAGER_IP=192.168.1.50 bash install-agent-linux.sh
#
# Optional environment variables:
#     AGENT_NAME   (default: this machine's hostname)
#     AGENT_GROUP  (default: default)
#     WAZUH_VERSION (default: 4.14.6 stream via the 4.x repo)
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run as root (sudo)." >&2; exit 1; }
: "${MANAGER_IP:?Set MANAGER_IP to the IP of your Wazuh manager, e.g. MANAGER_IP=192.168.1.50}"
AGENT_NAME="${AGENT_NAME:-$(hostname)}"
AGENT_GROUP="${AGENT_GROUP:-default}"

echo "[*] Installing Wazuh agent '$AGENT_NAME' -> manager $MANAGER_IP (group: $AGENT_GROUP)"

# --- Wazuh apt repository ---------------------------------------------------
if [ ! -f /usr/share/keyrings/wazuh.gpg ]; then
  curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
    | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
  chmod 644 /usr/share/keyrings/wazuh.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list
apt-get update -y

# --- Install with auto-enrolment via install-time variables -----------------
WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" WAZUH_AGENT_GROUP="$AGENT_GROUP" \
  apt-get install -y wazuh-agent

# --- Extra local log sources for this lab -----------------------------------
# Wazuh accepts multiple <ossec_config> blocks, so we append one instead of
# editing the existing config. The marker keeps this idempotent.
OSSEC_CONF=/var/ossec/etc/ossec.conf
if ! grep -q "home-soc:local-sources" "$OSSEC_CONF"; then
  cat >> "$OSSEC_CONF" <<'EOF'

<ossec_config>
  <!-- home-soc:local-sources -->

  <!-- Suricata network IDS events (JSON EVE) -->
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/suricata/eve.json</location>
  </localfile>

  <!-- Linux auditd (execve, privilege changes, file access) -->
  <localfile>
    <log_format>audit</log_format>
    <location>/var/log/audit/audit.log</location>
  </localfile>

  <!-- Authentication / sudo / SSH -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <!-- General syslog (feeds the homesoc-app custom decoder demo) -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
</ossec_config>
EOF
  echo "[+] Added Suricata, auditd and auth.log sources to $OSSEC_CONF"
fi

# --- auditd: install + load the lab's keyed rules ---------------------------
# These keys (identity / priv_esc / netcat) are matched by the Wazuh rules in
# detections/wazuh-rules/local_rules.xml.
echo "[*] Installing auditd and loading Home SOC audit rules"
apt-get install -y auditd audispd-plugins
cat > /etc/audit/rules.d/homesoc.rules <<'EOF'
## Home SOC auditd rules (keys consumed by Wazuh local_rules.xml)
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/group   -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers   -p wa -k priv_esc
-w /etc/sudoers.d -p wa -k priv_esc
-w /usr/bin/nc    -p x -k netcat
-w /bin/nc        -p x -k netcat
-w /usr/bin/ncat  -p x -k netcat
-w /usr/bin/socat -p x -k netcat
EOF
augenrules --load 2>/dev/null || service auditd restart 2>/dev/null || systemctl restart auditd 2>/dev/null || true
systemctl enable auditd 2>/dev/null || true

systemctl daemon-reload
systemctl enable wazuh-agent
systemctl restart wazuh-agent

echo "[+] Wazuh agent installed and started."
echo "    Confirm enrolment in the dashboard (Agents) or with:"
echo "      sudo /var/ossec/bin/agent_control -l"
