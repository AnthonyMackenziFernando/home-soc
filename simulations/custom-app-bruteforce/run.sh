#!/usr/bin/env bash
#
# Simulation: custom-decoder brute force  (MITRE T1110)
#   -> fires Wazuh 100071 (per event) and 100072 (correlation)
# --------------------------------------------------------------------------
# Emits "homesoc-app" failed-login lines through syslog. The custom decoder in
# detections/wazuh-rules/local_decoder.xml parses them; the rules then correlate.
# Fully self-contained: no target host or service required.
#
# Usage:
#   bash run.sh [COUNT=6] [SRC=10.10.10.66] [APPUSER=admin]
#
set -euo pipefail
for a in "$@"; do case "$a" in *=*) export "${a%%=*}"="${a#*=}";; esac; done
COUNT="${COUNT:-6}"
SRC="${SRC:-10.10.10.66}"
APPUSER="${APPUSER:-admin}"

command -v logger >/dev/null 2>&1 || { echo "[x] 'logger' not found (package: bsdutils/util-linux)"; exit 1; }

echo "=============================================================="
echo " [LAB] homesoc-app brute-force simulation"
echo " Writing $COUNT failed logins for '$APPUSER' from $SRC to syslog."
echo " Requires the agent to read /var/log/syslog (install-agent-linux.sh adds it)."
echo "=============================================================="

for i in $(seq 1 "$COUNT"); do
  logger -t homesoc-app "LOGIN_FAILED user=$APPUSER src=$SRC reason=badpass"
  sleep 1
done

echo "[+] Done. Dashboard: rule.id:100071 (each) and rule.id:100072 (brute force)."
echo "    Tip: verify parsing offline with  make logtest  and paste:"
echo "      $(date '+%b %d %H:%M:%S') $(hostname) homesoc-app: LOGIN_FAILED user=$APPUSER src=$SRC reason=badpass"
