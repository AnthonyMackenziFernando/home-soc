# PB-04 — Web Application Attack

| Field | Value |
|-------|-------|
| **Playbook ID** | PB-04 |
| **Scenario** | A web-facing service is scanned and probed for injection/traversal, possibly leading to a web shell |
| **MITRE ATT&CK** | [T1190 Exploit Public-Facing Application](https://attack.mitre.org/techniques/T1190/), [T1505.003 Web Shell](https://attack.mitre.org/techniques/T1505/003/) |
| **Severity (default)** | High |
| **Triggering detections** | Wazuh `100050` (web attack), `100040` (Suricata high-sev), `100060` (web shell dropped); Suricata `1000005`/`1000006` |
| **Simulation** | [`simulations/web-attack`](../simulations/README.md) |
| **Author** | Anthony Mackenzi |

## 1. Preparation
- A test web server (e.g. Apache/nginx/DVWA) on the victim VM, access log
  collected by the Wazuh agent.
- Suricata inspecting the VM's traffic; custom web rules loaded.
- FIM real-time on the web root (`/var/www`).

## 2. Identification
Dashboard → **Threat Hunting → Events**.

| Stage | Query |
|-------|-------|
| Scanning (tool user-agent) | `rule.groups:suricata AND data.alert.signature:*scanner*` or Suricata SID `1000006` |
| Injection attempts | `rule.id:100050` or `data.alert.signature_id:1000005` |
| Web shell written | `rule.id:100060` |

Reconstruct the attack from the access log:
```bash
sudo tail -n 200 /var/log/apache2/access.log        # or nginx
# What did the attacker request, and did anything return 200 after the probing?
awk '$9=="200"{print}' /var/log/apache2/access.log | tail
```
Record: attacker `src_ip`, targeted URLs/params, response codes, user-agent, and
whether a **new file appeared** in the web root (that's the pivotal fact).

## 3. Triage & severity
- **Scanning / probes with only 4xx responses** → Medium; the app resisted. Block
  and monitor.
- **A `200` on an injection payload, or a new file in `/var/www`** → **Critical**
  → assume a web shell and move to containment immediately.

## 4. Containment
```bash
# Block the attacker at the firewall
sudo ufw deny from <ATTACKER_IP>

# If a web shell was written, take it offline for analysis (don't just delete)
sudo mv -v /var/www/html/<suspicious>.php /var/quarantine/

# If exploitation is ongoing, stop the web service
sudo systemctl stop apache2
```

## 5. Eradication
- Identify how the file was written (which parameter / upload endpoint) from the
  access log and fix the vulnerable code/config.
- Hunt for **all** attacker-dropped files, not just the one that alerted:
  ```bash
  find /var/www -newermt '-1 day' -type f \( -name '*.php' -o -name '*.jsp' \)
  ```
- Kill any web-server child processes spawned by the shell; check outbound
  connections (`ss -tnp`).

## 6. Recovery
- Restore the web root from version control / known-good backup.
- Patch the application; re-enable the service.
- Watch `rule.id:(100050 OR 100060)` and the web root FIM for recurrence.

## 7. Lessons learned & detection tuning
- Put a WAF / reverse proxy in front of the app; feed its logs to Wazuh.
- Tune `100050` against your app's legitimate query strings to cut false
  positives (document what you allow-listed and why).
- The **web-shell FIM rule (100060) is the highest-value detection here** —
  exploitation attempts are noisy, but a new executable file in the web root is
  almost always bad. Prioritise it.

## References
- MITRE ATT&CK T1190 — https://attack.mitre.org/techniques/T1190/
- OWASP Top 10 — https://owasp.org/www-project-top-ten/
