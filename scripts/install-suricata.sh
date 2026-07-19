#!/usr/bin/env bash
#
# Install and configure Suricata (network IDS) on a Debian/Ubuntu endpoint so
# its EVE JSON output can be picked up by the Wazuh agent on the same host.
#
# Run ON THE ENDPOINT:
#     sudo bash install-suricata.sh                 # auto-detect interface
#     sudo IFACE=eth0 bash install-suricata.sh      # or name it explicitly
#
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (sudo)." >&2; exit 1; }

IFACE="${IFACE:-$(ip route | awk '/default/{print $5; exit}')}"
[ -n "$IFACE" ] || { echo "Could not detect a network interface. Set IFACE=... and retry." >&2; exit 1; }
echo "[*] Installing Suricata, monitoring interface: $IFACE"

apt-get update -y
apt-get install -y suricata suricata-update jq

# --- Point the Debian service at the right interface ------------------------
if [ -f /etc/default/suricata ]; then
  sed -i "s/^IFACE=.*/IFACE=$IFACE/" /etc/default/suricata
  sed -i "s/^LISTENMODE=.*/LISTENMODE=af-packet/" /etc/default/suricata
fi

# --- EVE JSON + Community ID (lets you pivot between Suricata and other logs) -
CFG=/etc/suricata/suricata.yaml
if [ -f "$CFG" ]; then
  cp "$CFG" "$CFG.bak.$(date +%s 2>/dev/null || echo backup)"
  # Turn on community-id if present and currently disabled.
  sed -i 's/^\(\s*\)community-id:\s*false/\1community-id: true/' "$CFG" || true
fi

# --- Rules: pull the free ET Open ruleset -----------------------------------
echo "[*] Downloading ruleset with suricata-update (Emerging Threats Open)"
suricata-update || echo "[!] suricata-update had a non-zero exit; you can re-run it later."

# --- Sanity check config, then start ----------------------------------------
echo "[*] Validating Suricata configuration"
suricata -T -c "$CFG" -v || { echo "[x] Suricata config test failed — review $CFG" >&2; exit 1; }

systemctl enable suricata
systemctl restart suricata

echo "[+] Suricata is running on $IFACE."
echo "    EVE JSON: /var/log/suricata/eve.json  (the Wazuh agent tails this)"
echo "    Generate a test alert:  curl -s http://testmynids.org/uid/index.html >/dev/null"
echo "    Then look for Suricata rule group 86600 alerts in the Wazuh dashboard."
