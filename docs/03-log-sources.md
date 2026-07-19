# 03 — Log sources

A SIEM is only as good as what you feed it. This lab collects four complementary
telemetry types so detections can see host **and** network behaviour and
correlate across them.

| Source | Collected by | What it gives you | Detections that use it |
|--------|--------------|-------------------|------------------------|
| **SSH / auth** (`/var/log/auth.log`) | Wazuh agent (syslog) | Logins, sudo, failures | 100001, 100002 |
| **auditd** (`/var/log/audit/audit.log`) | Wazuh agent (audit) | execve, identity/sudoers file access (keyed) | 100030, 100031, 100034 |
| **File Integrity Monitoring** | Wazuh agent (syscheck) | New/changed files, real-time on hot dirs | 100060, 100061, 100062 |
| **Suricata** (`/var/log/suricata/eve.json`) | Wazuh agent (json) | Network IDS alerts, flows, HTTP | 100040, 1000001–1000006 |
| **General syslog** (`/var/log/syslog`) | Wazuh agent (syslog) | Everything else, incl. the demo-app decoder | 100071, 100072 |

All of these are wired up automatically by
[`scripts/install-agent-linux.sh`](../scripts/install-agent-linux.sh) (which
appends the localfile blocks and installs auditd) and the centralised
[`agent.conf`](../deploy/config/wazuh_cluster/agent.conf) (which turns on
real-time FIM for `/home`, `/tmp`, `/var/www`, and cron directories).

## Why each one earns its place
- **auth.log** is the cheapest, highest-value source — brute force, the classic
  first move, shows up here.
- **auditd** sees what syslog can't: the actual `execve` of a binary and writes to
  sensitive files, tagged with keys so rules stay simple and robust.
- **FIM** catches the *result* of an attack (a web shell appears, a cron job is
  planted) even when the exploit itself was invisible.
- **Suricata** adds the network dimension — scans, C2 output, malware in transit —
  which host logs alone miss.

Layering them is what enables **correlation**: the reverse-shell investigation
([INV-2026-07-03](../investigations/2026-07-03-reverse-shell/report.md)) is
convincing precisely because FIM, auditd and Suricata all fire on the same host
in the same second.

## Verifying a source is flowing
```bash
# On the dashboard: Threat Hunting -> Events, then:
#   rule.groups:suricata          (Suricata is arriving)
#   rule.groups:audit             (auditd is arriving)
#   syscheck.event:*              (FIM is arriving)

# On the agent host:
sudo tail -f /var/ossec/logs/ossec.log      # agent shipping status
sudo /var/ossec/bin/agent_control -l        # (on the manager) list agents
```
If a source is missing, see [08 — Troubleshooting](08-troubleshooting.md).
