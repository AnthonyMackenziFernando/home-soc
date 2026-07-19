# INV-2026-07-01 — SSH Brute Force Leading to Account Compromise

| Field | Value |
|-------|-------|
| **Incident ID** | INV-2026-07-01 |
| **Date / time (UTC)** | 2026-07-15 22:14 |
| **Analyst** | Anthony Mackenzi |
| **Severity** | High |
| **Status** | Closed |
| **Affected asset** | `ubuntu-victim` (agent 002), 192.168.1.60 |
| **Source** | 192.168.1.70 |
| **MITRE ATT&CK** | [T1110 Brute Force](https://attack.mitre.org/techniques/T1110/) |
| **Playbook used** | [PB-01](../../playbooks/PB-01-ssh-brute-force.md) |

## Executive summary
An external host (192.168.1.70) ran an SSH password brute-force against
`ubuntu-victim` and, after ~40 failed attempts in under a minute, **successfully
logged in** to the `devops` account, which had a weak password. The correlation
rule for "successful login after brute force" (100002) fired and was triaged
within minutes. The account was locked, the source IP blocked, and credentials
rotated. No privilege escalation or lateral movement occurred before containment.

## Timeline
| Time (UTC) | Event |
|------------|-------|
| 22:14:01 | First failed SSH login from 192.168.1.70 (user `admin`) |
| 22:14:01–22:14:29 | 41 failed logins across users `admin`, `root`, `devops` |
| 22:14:18 | **Wazuh rule 100001** fires (8+ auth failures / 90s from one IP) |
| 22:14:31 | `Accepted password for devops from 192.168.1.70` |
| 22:14:31 | **Wazuh rule 100002** fires (level 12 — success after brute force) |
| 22:16 | Analyst triage begins |
| 22:19 | Source IP blocked, `devops` locked, sessions killed |
| 22:35 | Password rotated, `authorized_keys` reviewed — clean; incident closed |

## Detection
Two alerts, viewed under **Threat Hunting → Events**:

- `rule.id:100001` — *Brute force: 8+ authentication failures from the same
  source IP within 90s* (level 10).
- `rule.id:100002` — *Possible successful brute force: login succeeded from an IP
  previously flagged for brute forcing* (level 12). **This is the alert that
  mattered** — it distinguishes a failed spray from an actual compromise.

![Alert 100002 detail](screenshots/01-alert-100002.png)

## Investigation & evidence
**1. Scope the campaign.** Pivoted on the source IP:
`data.srcip:192.168.1.70` returned 41 failures + 1 success, all within 30
seconds — machine-speed, clearly automated.

![Source IP timeline](screenshots/02-srcip-timeline.png)

Representative `auth.log` evidence from the agent:
```
Jul 15 22:14:01 ubuntu-victim sshd[3120]: Failed password for invalid user admin from 192.168.1.70 port 40122 ssh2
Jul 15 22:14:07 ubuntu-victim sshd[3141]: Failed password for root from 192.168.1.70 port 40160 ssh2
Jul 15 22:14:29 ubuntu-victim sshd[3180]: Failed password for devops from 192.168.1.70 port 40260 ssh2
Jul 15 22:14:31 ubuntu-victim sshd[3184]: Accepted password for devops from 192.168.1.70 port 40268 ssh2
Jul 15 22:14:31 ubuntu-victim sshd[3184]: pam_unix(sshd:session): session opened for user devops by (uid=0)
```

**2. Determine what the attacker did post-login.** Correlated the `devops`
session against auditd execve events for the host in the 22:14–22:20 window:
```
type=EXECVE ... a0="id"
type=EXECVE ... a0="uname" a1="-a"
type=EXECVE ... a0="sudo" a1="-l"
```
The attacker ran basic discovery (`id`, `uname -a`) and probed for sudo rights
(`sudo -l`) — but `devops` had no sudo entitlement, so escalation failed. No file
writes to `/tmp`, `/var/www`, cron, or sudoers were observed (no 100031/100060/
100061/100062 alerts for this host in the window).

![Session commands](screenshots/03-session-commands.png)

## Impact assessment
- **Confidentiality:** Low–Medium. The attacker gained an unprivileged shell and
  could read files readable by `devops`. No sensitive data access observed.
- **Integrity / Availability:** None observed. No changes, no persistence, no
  lateral movement before containment.
- **Blast radius:** Contained to one non-privileged account on one host.

## Response actions
Executed [PB-01](../../playbooks/PB-01-ssh-brute-force.md):
```bash
sudo ufw deny from 192.168.1.70          # block source (containment)
sudo passwd -l devops                     # lock account
sudo pkill -KILL -u devops                # kill live sessions (eradication)
sudo passwd --expire devops               # force reset on next use (recovery)
grep devops /etc/sudoers /etc/sudoers.d/* # privilege review — none
cat /home/devops/.ssh/authorized_keys     # key review — no rogue keys
```
All clean after rotation. Incident closed.

## Root cause
`ubuntu-victim` allowed **SSH password authentication**, and the `devops` account
used a weak, guessable password present in common wordlists. Nothing rate-limited
the attempts at the host level.

## Lessons learned & detection tuning
1. **Prevent:** disabled password auth (`PasswordAuthentication no`), moved to
   key-only, added `AllowUsers`. This removes the entire attack class.
2. **Detect faster:** wired a Wazuh **active response** so rule `100001` triggers
   `firewall-drop` on the source for 600s — automatic containment before a
   human looks.
3. **Right alert, right priority:** confirmed `100002` routes to the high-priority
   view; `100001` alone (failures, no success) is informational.
4. **Gap noted:** host had no `fail2ban`; added as defence-in-depth.

## Indicators of Compromise (IOCs)
| Type | Value |
|------|-------|
| Source IP | 192.168.1.70 |
| Targeted account | `devops` (compromised), `admin`/`root` (attempted) |
| Technique | SSH password brute force (T1110) |

## Appendix — reproduce this
```bash
bash simulations/ssh-bruteforce/run.sh TARGET_IP=192.168.1.60 TARGET_USER=devops
# add the real weak password to the wordlist to reproduce the 100002 success path
```
