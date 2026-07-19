# 07 — Incident response

Detections raise alerts; incident response is what you *do* about them. This lab
follows the six-phase **SANS/NIST SP 800-61** lifecycle, and each scenario has a
concrete [playbook](../playbooks/README.md).

> **P**reparation → **I**dentification → **C**ontainment → **E**radication → **R**ecovery → **L**essons Learned

## Playbooks
| Scenario | Playbook |
|----------|----------|
| SSH / credential brute force | [PB-01](../playbooks/PB-01-ssh-brute-force.md) |
| Malware / malicious file | [PB-02](../playbooks/PB-02-malware-detection.md) |
| Privilege escalation | [PB-03](../playbooks/PB-03-privilege-escalation.md) |
| Web application attack | [PB-04](../playbooks/PB-04-web-attack.md) |
| Reverse shell / C2 | [PB-05](../playbooks/PB-05-reverse-shell.md) |

Worked examples of the full loop are in
[`investigations/`](../investigations/README.md).

## Automated response (Wazuh Active Response)
The manager can act on an alert without waiting for a human — the fastest form of
containment. The response commands (`firewall-drop`, `host-deny`, `disable-account`)
are already defined in
[`wazuh_manager.conf`](../deploy/config/wazuh_cluster/wazuh_manager.conf); you
just add an `<active-response>` block that binds one to a rule.

**Example — auto-block a brute-force source for 10 minutes.** Add to the manager
config, inside `<ossec_config>`:
```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>       <!-- run on the agent that saw the event -->
  <rules_id>100001</rules_id>
  <timeout>600</timeout>           <!-- auto-undo after 600s -->
</active-response>
```
Then apply and reload:
```bash
make deploy-rules      # validates config, restarts the manager
```
Now a host that trips rule `100001` is firewalled at the source automatically —
exactly the tuning called out in [PB-01](../playbooks/PB-01-ssh-brute-force.md)
and INV-2026-07-01.

> Start active response in **alert-only** mode and watch for false positives
> before letting it block. An over-eager auto-block is its own incident.

### High-confidence combinations
For noisy single signals, bind the response to a **correlation** instead. The
reverse-shell case is high-confidence when a payload is staged *and* netcat runs,
so gate isolation on that pair rather than on either alone (see
[INV-2026-07-03](../investigations/2026-07-03-reverse-shell/report.md)).

## Threat intelligence (CDB lists)
Turn IOCs from an investigation into future detections. Wazuh **CDB lists** are
key:value lookups you can match in a rule:
```bash
# add an IOC, then rebuild the list
echo "192.168.1.70:c2" >> /var/ossec/etc/lists/homesoc-malicious-ip
```
Reference the list in the ruleset and write a rule that alerts on any traffic to
a listed IP — so a repeat of INV-03's C2 is caught instantly.

## Records
Close every incident with a write-up in
[`investigations/`](../investigations/README.md). The steady accumulation of
these is both good operational hygiene and the strongest single signal on the
repo.
