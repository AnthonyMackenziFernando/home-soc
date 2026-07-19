# PB-01 — SSH / Credential Brute Force

| Field | Value |
|-------|-------|
| **Playbook ID** | PB-01 |
| **Scenario** | Repeated failed authentications against SSH (or the demo app), possibly followed by a successful login |
| **MITRE ATT&CK** | [T1110 Brute Force](https://attack.mitre.org/techniques/T1110/) (Credential Access) |
| **Severity (default)** | Medium — **High/Critical** if a success follows |
| **Triggering detections** | Wazuh `100001` (brute force), `100002` (success after brute force), `100072` (demo-app brute force) |
| **Simulation** | [`simulations/ssh-bruteforce`](../simulations/README.md) |
| **Author** | Anthony Mackenzi |

## 1. Preparation
- Wazuh agent installed on the target host; `auth.log` collected (added by
  `scripts/install-agent-linux.sh`).
- Rules `100001`/`100002` deployed (`make deploy-rules`).
- Know your **baseline**: which source IPs legitimately SSH in.

## 2. Identification
Open the dashboard → **Threat Hunting → Events**.

- **Find the campaign:** `rule.id:100001`
- **Check for compromise (do this first):** `rule.id:100002` — a hit here means a
  login **succeeded** from a brute-forcing IP. Treat as a likely account
  takeover.

Confirm and record:
| Question | Where to look |
|----------|---------------|
| Source IP(s)? | `data.srcip` |
| Target account(s)? | `data.dstuser` |
| Target host? | `agent.name` |
| How many attempts, over what window? | event count for that `srcip` |
| Did any attempt **succeed**? | `rule.id:(5715 OR 100002)` for that `srcip` |

Cross-check the host directly:
```bash
sudo grep -Ei "accepted|failed password" /var/log/auth.log | tail -n 50
sudo lastb | head            # recent failed logins
sudo last  | head            # recent successful logins
```

## 3. Triage & severity
- **No success + external IP hammering** → Medium. Contain the source, keep watching.
- **Success after brute force (100002)** → **Critical**. Assume the account is
  compromised; go straight to containment + eradication.
- **Internal source IP** → check for a misconfigured script before assuming evil.

## 4. Containment
Block the source and/or lock the account (reversible first):

```bash
# Block the attacker IP at the firewall
sudo ufw deny from <ATTACKER_IP>            # or: sudo iptables -A INPUT -s <IP> -j DROP

# If an account was compromised, lock it and kill its sessions
sudo passwd -l <USER>
sudo pkill -KILL -u <USER>
```

Wazuh can do this automatically — see *Lessons learned* for enabling the
`firewall-drop` active response on rule `100001`.

## 5. Eradication
If a login succeeded:
```bash
# Force a password reset and review what the account can do
sudo passwd --expire <USER>
sudo crontab -l -u <USER>                    # unexpected persistence?
grep -R "<USER>" /etc/sudoers /etc/sudoers.d # unexpected privilege?
```
- Review `~/.ssh/authorized_keys` for keys you didn't add (T1098.004).
- Check for new users/services created after the login time.

## 6. Recovery
- Unlock the account only after the password/keys are rotated.
- Restrict SSH: key-only auth (`PasswordAuthentication no`), non-default port,
  `AllowUsers`, and fail2ban or Wazuh active response.
- Watch `rule.id:(100001 OR 100002)` for that account/IP for 24–48h.

## 7. Lessons learned & detection tuning
- **Auto-contain:** add an active response so rule `100001` triggers
  `firewall-drop` for 10 minutes (see [`docs/07-incident-response.md`](../docs/07-incident-response.md)).
- **Reduce noise:** allow-list known automation source IPs so they don't page you.
- **Raise fidelity:** `100002` (success-after-brute-force) is the alert that
  actually matters — make sure it routes to a higher-priority channel.

## References
- MITRE ATT&CK T1110 — https://attack.mitre.org/techniques/T1110/
- NIST SP 800-61r2 Incident Handling Guide
