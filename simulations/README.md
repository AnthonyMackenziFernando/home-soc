# Attack Simulations

Detections are only trustworthy if you can **make them fire on demand**. Each
folder here is a small, safe, self-contained script that generates the telemetry
for one detection, so you can:

- prove a rule works (and screenshot it for an investigation write-up),
- re-test after tuning, and
- demo the whole pipeline end-to-end.

> ## ⚠️ Lab use only
> Run these **only** against machines you own in this lab. They generate activity
> that looks hostile by design. Every script is safe and reversible, but they are
> not toys — read the banner each one prints.

## The simulations

| Folder | What it does | Fires | Playbook |
|--------|--------------|-------|----------|
| `ssh-bruteforce` | Many failed SSH logins from one source | `100001` (+`100002` if a valid cred is included) | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |
| `custom-app-bruteforce` | Emits `homesoc-app` failed-login lines via `logger` | `100071`, `100072` | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |
| `web-attack` | SQLi payloads + scanner user-agent over HTTP | `100050`, `1000005`, `1000006` | [PB-04](../playbooks/PB-04-web-attack.md) |
| `malware-eicar` | Fetches/stages the harmless EICAR test file | `1000004`, `100062` | [PB-02](../playbooks/PB-02-malware-detection.md) |
| `reverse-shell` | Stages a payload in /tmp and runs netcat to a local listener | `100062`, `100034`, `1000003` | [PB-05](../playbooks/PB-05-reverse-shell.md) |
| `privilege-escalation` | Reversibly creates a user, a sudoers.d marker and a cron file | `100020`, `100030`, `100031`, `100061` | [PB-03](../playbooks/PB-03-privilege-escalation.md) |

## Typical workflow

```bash
# 1. Trigger an attack (from the victim endpoint or the SOC host)
bash simulations/ssh-bruteforce/run.sh TARGET_IP=192.168.1.60

# 2. Watch it land in the dashboard
#    Threat Hunting -> Events -> filter rule.id:100001

# 3. Work the matching playbook, then record it under investigations/
```

## Prerequisites

- The Wazuh agent + auditd + Suricata installed on the endpoint you target
  (`scripts/install-agent-linux.sh`, `scripts/install-suricata.sh`).
- Some scripts use common tools (`curl`, `ssh`, `sshpass`, `nc`); each checks and
  tells you what to `apt-get install` if it's missing.
