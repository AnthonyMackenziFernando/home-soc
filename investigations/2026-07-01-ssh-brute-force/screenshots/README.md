# Screenshots to capture (INV-2026-07-01)

Run `simulations/ssh-bruteforce/run.sh` against your victim, then capture these
from the Wazuh dashboard and save them here with these exact names (the report
references them):

- `01-alert-100002.png` — the rule 100002 alert detail (success after brute force)
- `02-srcip-timeline.png` — Events filtered on `data.srcip:<attacker-ip>` showing the burst
- `03-session-commands.png` — auditd execve events for the compromised session

Tip: use the browser's built-in screenshot or your OS tool; crop to the panel.
