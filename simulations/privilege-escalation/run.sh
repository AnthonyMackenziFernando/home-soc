#!/usr/bin/env bash
#
# Simulation: privilege escalation & account abuse (MITRE T1136 / T1548.003 / T1053.003)
#   -> fires Wazuh 100020 (new user), 100030 (identity file), 100031 (sudoers),
#      100061 (cron)
# --------------------------------------------------------------------------
# LAB USE ONLY. Reversible: creates a throwaway user, a comment-only sudoers.d
# drop-in, and a marker cron file — then removes them. Requires root + --confirm.
#
# Usage:
#   sudo bash run.sh --confirm            # run and auto-clean
#   sudo CLEANUP=no bash run.sh --confirm # leave artifacts to investigate
#
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "[x] Run as root (sudo)."; exit 1; }
case " $* " in *" --confirm "*) : ;; *) echo "[x] Refusing to run without --confirm (this changes system state)."; exit 1;; esac
CLEANUP="${CLEANUP:-yes}"

U="homesoc_testuser"
SUDOERS="/etc/sudoers.d/homesoc_test"
CRON="/etc/cron.d/homesoc_test"

echo "=============================================================="
echo " [LAB] Privilege-escalation simulation (reversible)"
echo "=============================================================="

echo "[*] Creating throwaway user '$U'  (-> 100020 + identity 100030)"
useradd -m -c "home-soc simulation" "$U" 2>/dev/null || echo "    (user already exists)"

echo "[*] Dropping a comment-only file in /etc/sudoers.d  (-> 100031)"
install -m 0440 /dev/stdin "$SUDOERS" <<<'# home-soc simulation marker — no actual privileges granted'

echo "[*] Creating a marker cron file in /etc/cron.d  (-> 100061)"
printf '# home-soc simulation marker\n' > "$CRON"

echo "[*] Waiting a few seconds for auditd/FIM to ship the events..."
sleep 5

if [ "$CLEANUP" = "yes" ]; then
  echo "[*] Cleaning up"
  userdel -r "$U" 2>/dev/null || true
  rm -f "$SUDOERS" "$CRON"
  echo "[+] Reverted. Dashboard: rule.id:(100020 OR 100030 OR 100031 OR 100061)"
else
  echo "[!] CLEANUP=no — artifacts left in place for investigation. Remove them with:"
  echo "      sudo userdel -r $U; sudo rm -f $SUDOERS $CRON"
fi
