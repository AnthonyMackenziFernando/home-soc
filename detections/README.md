# Detections

This is the detection-engineering core of the lab. Every detection is:

- **mapped to MITRE ATT&CK** (so it speaks the same language as a real SOC),
- **backed by a repeatable simulation** (so anyone can reproduce the alert),
- **linked to a response playbook** (so an analyst knows what to do), and
- **written twice**: once as a deployable **Wazuh** rule and once as a portable
  **Sigma** rule that could be shipped to any other SIEM.

```
detections/
├── wazuh-rules/
│   ├── local_rules.xml      # MITRE-tagged Wazuh rules (IDs 100000+)
│   ├── local_decoder.xml    # custom decoder for the demo app
│   └── README.md            # how to write/test/deploy Wazuh rules
└── sigma/                   # vendor-neutral versions of the same logic
```

## Detection catalogue — Wazuh rules

| Wazuh ID | Detection | MITRE | Data source | Sigma | Simulation | Playbook |
|---------:|-----------|-------|-------------|-------|------------|----------|
| 100001 | Brute force: 8+ auth failures / 90s | [T1110](https://attack.mitre.org/techniques/T1110/) | sshd / PAM | `ssh_brute_force.yml` | `ssh-bruteforce` | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |
| 100002 | Successful login after brute force | [T1110](https://attack.mitre.org/techniques/T1110/) | sshd / PAM | *(correlation)* | `ssh-bruteforce` | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |
| 100020 | New local account / group | [T1136](https://attack.mitre.org/techniques/T1136/) | syslog (adduser) | — | `privilege-escalation` | [PB-03](../playbooks/PB-03-privilege-escalation.md) |
| 100030 | Identity file (passwd/shadow) modified | [T1098](https://attack.mitre.org/techniques/T1098/) / [T1003.008](https://attack.mitre.org/techniques/T1003/008/) | auditd | — | `privilege-escalation` | [PB-03](../playbooks/PB-03-privilege-escalation.md) |
| 100031 | Sudoers modified | [T1548.003](https://attack.mitre.org/techniques/T1548/003/) | auditd | `sudoers_modification.yml` | `privilege-escalation` | [PB-03](../playbooks/PB-03-privilege-escalation.md) |
| 100034 | Netcat / socat executed | [T1059](https://attack.mitre.org/techniques/T1059/) / [T1095](https://attack.mitre.org/techniques/T1095/) | auditd | `netcat_execution.yml` | `reverse-shell` | [PB-05](../playbooks/PB-05-reverse-shell.md) |
| 100062 | File staged in /tmp or /dev/shm | [T1059](https://attack.mitre.org/techniques/T1059/) | FIM (realtime) | `execution_from_tmp.yml` | `reverse-shell` | [PB-05](../playbooks/PB-05-reverse-shell.md) |
| 100060 | File written to web root (web shell) | [T1505.003](https://attack.mitre.org/techniques/T1505/003/) | FIM (realtime) | `webshell_dropped_in_webroot.yml` | `web-attack` | [PB-04](../playbooks/PB-04-web-attack.md) |
| 100061 | Cron job created / modified | [T1053.003](https://attack.mitre.org/techniques/T1053/003/) | FIM (realtime) | — | `privilege-escalation` | [PB-03](../playbooks/PB-03-privilege-escalation.md) |
| 100040 | Suricata high-severity IDS alert | [T1046](https://attack.mitre.org/techniques/T1046/) | Suricata EVE | — | `web-attack` | [PB-04](../playbooks/PB-04-web-attack.md) |
| 100050 | Web application attack (SQLi/XSS) | [T1190](https://attack.mitre.org/techniques/T1190/) | web access log | `web_sqli_in_uri.yml` | `web-attack` | [PB-04](../playbooks/PB-04-web-attack.md) |
| 100070–100072 | Demo-app custom-decoder brute force | [T1110](https://attack.mitre.org/techniques/T1110/) | custom decoder | — | `custom-app-bruteforce` | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |

## Detection catalogue — Suricata rules (`deploy/suricata/custom.rules`)

| SID | Detection | MITRE |
|----:|-----------|-------|
| 1000001 | ICMP ping sweep | [T1018](https://attack.mitre.org/techniques/T1018/) |
| 1000002 | TCP SYN port scan | [T1046](https://attack.mitre.org/techniques/T1046/) |
| 1000003 | Reverse shell — `id` output in cleartext egress | [T1059](https://attack.mitre.org/techniques/T1059/) |
| 1000004 | EICAR antivirus test file transferred | [T1105](https://attack.mitre.org/techniques/T1105/) |
| 1000005 | SQL injection in URI (UNION SELECT) | [T1190](https://attack.mitre.org/techniques/T1190/) |
| 1000006 | Web scanner user-agent (sqlmap/nikto/…) | [T1595](https://attack.mitre.org/techniques/T1595/) |

## ATT&CK tactics covered

Reconnaissance · Initial Access · Execution · Persistence · Privilege Escalation ·
Credential Access · Command & Control · Discovery.

The honest gaps (Defense Evasion, Lateral Movement, Exfiltration, Impact) and how
I'd close them next are documented in
[`../docs/09-mitre-attack-coverage.md`](../docs/09-mitre-attack-coverage.md) —
knowing your blind spots is part of the job.

## Design principles

1. **Reserved ID space.** Wazuh rules use `100000+`; Suricata rules use
   `1000000+`. Custom content never collides with vendor rulesets.
2. **High signal first.** Rules key on unambiguous behaviour (sudoers changed,
   file in a web root) or on correlation (success *after* brute force) rather
   than on noisy single events.
3. **Every rule is testable.** If you can't trigger it from `simulations/`, it
   doesn't belong here.
4. **Tuning is documented, not hidden.** False positives and how they were
   handled live in the investigation write-ups.
