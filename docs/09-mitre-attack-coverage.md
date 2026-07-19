# 09 — MITRE ATT&CK coverage

Mapping detections to [MITRE ATT&CK](https://attack.mitre.org/) does two things:
it proves the lab detects *deliberate* techniques (not random noise), and it makes
the **gaps** explicit — knowing what you *can't* see is a senior habit.

## Coverage matrix

| Tactic | Technique | Detection(s) |
|--------|-----------|--------------|
| Reconnaissance | T1595 Active Scanning | Suricata 1000006 (scanner UA), 1000002 (SYN scan) |
| Reconnaissance / Discovery | T1018 Remote System Discovery | Suricata 1000001 (ping sweep) |
| Discovery | T1046 Network Service Discovery | Suricata 1000002, Wazuh 100040 |
| Initial Access | T1190 Exploit Public-Facing App | Wazuh 100050, Suricata 1000005 |
| Initial Access / Delivery | T1105 Ingress Tool Transfer | Suricata 1000004 (EICAR), Wazuh 100062 |
| Credential Access | T1110 Brute Force | Wazuh 100001, 100002, 100072 |
| Credential Access | T1003.008 /etc/passwd & /etc/shadow | Wazuh 100030 |
| Execution | T1059 Command & Scripting Interpreter | Wazuh 100034, 100062, Suricata 1000003 |
| Persistence | T1136 Create Account | Wazuh 100020 |
| Persistence | T1098 Account Manipulation | Wazuh 100030 |
| Persistence | T1505.003 Web Shell | Wazuh 100060 |
| Persistence | T1053.003 Cron | Wazuh 100061 |
| Privilege Escalation | T1548.003 Sudo and Sudo Caching | Wazuh 100031 |
| Command & Control | T1071 / T1095 | Wazuh 100034, Suricata 1000003 |

**Tactics with at least one detection:** Reconnaissance · Initial Access ·
Execution · Persistence · Privilege Escalation · Credential Access · Discovery ·
Command & Control.

## Known gaps (and how I'd close them)
Being honest about this is the point — no home lab covers ATT&CK end to end.

| Gap | Why it's not covered yet | How I'd close it |
|-----|--------------------------|------------------|
| **Defense Evasion** (T1070 log clearing, T1562 disabling tools) | Needs more auditd/EDR telemetry | Add auditd watches on `/var/log`, Wazuh service-stop rules |
| **Lateral Movement** (T1021) | Single victim host in the lab | Add a second endpoint + Zeek for east-west visibility |
| **Exfiltration** (T1041, T1048) | No egress/DNS analytics yet | Add Zeek `conn`/`dns` logs; alert on volume + rare destinations |
| **Windows techniques** | Lab is Linux-only on 8 GB | Add a Windows VM with **Sysmon** → Wazuh (roadmap stretch goal) |
| **Impact** (T1486 ransomware) | Destructive to simulate | FIM mass-change heuristics; canary files |

## Roadmap to broaden coverage
1. **Sysmon on Windows** — the single biggest coverage jump (Execution, Defense
   Evasion, Persistence on Windows).
2. **Zeek** alongside Suricata — connection/DNS/SSL logs unlock Lateral Movement
   and Exfiltration detections.
3. **Import a Sigma pack** and convert it, widening technique coverage quickly.
4. **osquery** via Wazuh for scheduled host-state hunting.

See [`docs/05-detection-engineering.md`](05-detection-engineering.md) for how new
rules get added, tested and deployed.
