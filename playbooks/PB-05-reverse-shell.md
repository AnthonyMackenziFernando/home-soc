# PB-05 — Reverse Shell / Command & Control

| Field | Value |
|-------|-------|
| **Playbook ID** | PB-05 |
| **Scenario** | A compromised host opens an outbound interactive shell to an attacker-controlled listener |
| **MITRE ATT&CK** | [T1059 Command and Scripting Interpreter](https://attack.mitre.org/techniques/T1059/), [T1071 Application Layer Protocol](https://attack.mitre.org/techniques/T1071/), [T1095 Non-Application Layer Protocol](https://attack.mitre.org/techniques/T1095/) |
| **Severity (default)** | Critical |
| **Triggering detections** | Wazuh `100034` (netcat/socat), `100062` (temp payload); Suricata `1000003` (id output egress) |
| **Simulation** | [`simulations/reverse-shell`](../simulations/README.md) |
| **Author** | Anthony Mackenzi |

## 1. Preparation
- auditd `netcat` key loaded; Suricata monitoring egress.
- You know your host's **normal** outbound connections (baseline).

## 2. Identification
Dashboard → **Threat Hunting → Events**.

| Signal | Query |
|--------|-------|
| Reverse-shell tool executed | `rule.id:100034` |
| Payload staged in temp | `rule.id:100062` |
| Shell output on the wire | Suricata SID `1000003` / `rule.id:100040` |

Confirm the live connection on the host:
```bash
sudo ss -tnp | grep -vE ':22|:443|:80'      # unexpected established outbound?
sudo lsof -i -nP | grep ESTABLISHED
# Map the suspicious PID back to its parent and command line
ps -o pid,ppid,user,cmd -p <PID>
sudo ausearch -k netcat -i | tail
```
Record: the **remote IP:port** (the C2), the local **process + parent**, the
**user** it runs as, and how it started (cron? web shell? interactive?).

## 3. Triage & severity
Any confirmed unexpected interactive outbound shell is **Critical**. The question
is not *if* but *how far*: what user, what did it already do (check history,
auditd), and did it escalate (→ [PB-03](PB-03-privilege-escalation.md)).

## 4. Containment
Act fast — a live shell means a human may be on the keyboard.
```bash
# 1. Cut the network (best first move for an active C2)
sudo nmcli networking off        # or snapshot + isolate the VM

# 2. Kill the shell process and its parent if malicious
sudo kill -9 <PID> <PPID>

# 3. If you must stay online, block just the C2
sudo iptables -A OUTPUT -d <C2_IP> -j DROP
```

## 5. Eradication
- Trace the **entry point**: what spawned the shell? Remove that too (web shell,
  cron, dropped binary in `/tmp`).
- Remove persistence: cron, systemd units, `~/.bashrc`/profile hooks,
  `authorized_keys`.
- Rotate every credential that lived on the host.
```bash
crontab -l; sudo ls -la /etc/cron.* /etc/systemd/system
grep -RiE "bash -i|/dev/tcp|nc -e|socat" /home /var/www /tmp 2>/dev/null
```

## 6. Recovery
- **Re-image** is the safe default once an interactive C2 is confirmed — you can
  rarely prove a host is clean.
- If rebuilding isn't possible in the lab, restore the pre-attack snapshot.
- Monitor egress for re-connection attempts to the C2 IP for 48h.

## 7. Lessons learned & detection tuning
- Add the C2 IP to a Wazuh CDB threat-intel list.
- The strongest generic control is **egress filtering** — a host that can only
  reach what it needs can't phone home. Note the gap in
  [`docs/09-mitre-attack-coverage.md`](../docs/09-mitre-attack-coverage.md).
- Consider an active response that isolates a host on `100034`+`100062` firing
  together (staged payload *and* tool execution = high confidence).

## References
- MITRE ATT&CK T1059 — https://attack.mitre.org/techniques/T1059/
- MITRE ATT&CK T1071 — https://attack.mitre.org/techniques/T1071/
