# Incident Response Playbooks

A detection tells you *something happened*. A playbook tells you *what to do
about it*. These follow the six-phase **SANS / NIST SP 800-61** incident-response
lifecycle so the workflow matches what a real SOC runs:

> **P**reparation → **I**dentification → **C**ontainment → **E**radication → **R**ecovery → **L**essons Learned

Each playbook is tied to specific detections in
[`../detections/`](../detections/README.md) and to a reproducible attack in
[`../simulations/`](../simulations/README.md), so every step can be rehearsed.

| Playbook | Scenario | Primary MITRE | Triggering rules |
|----------|----------|---------------|------------------|
| [PB-01](PB-01-ssh-brute-force.md) | SSH / credential brute force | T1110 | 100001, 100002, 100072 |
| [PB-02](PB-02-malware-detection.md) | Malware / malicious file on host | T1105, T1204 | 1000004, 100062, FIM/rootcheck |
| [PB-03](PB-03-privilege-escalation.md) | Privilege escalation & account abuse | T1548.003, T1136 | 100020, 100030, 100031, 100061 |
| [PB-04](PB-04-web-attack.md) | Web application attack | T1190 | 100050, 100040, 100060, 1000005/1000006 |
| [PB-05](PB-05-reverse-shell.md) | Reverse shell / C2 | T1059, T1071 | 100034, 100062, 1000003 |

`template.md` is the blank structure to copy when you add a new playbook.

## How to use one during an "incident"

1. An alert fires on the dashboard (or in `make health`).
2. Open the matching playbook.
3. Work top to bottom, recording what you find.
4. When it's over, write it up in [`../investigations/`](../investigations/README.md).

> ⚠️ Containment/eradication commands here assume a **lab you own**. Never run
> them against systems you are not authorised to touch.
