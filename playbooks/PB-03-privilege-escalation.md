# PB-03 — Privilege Escalation & Account Abuse

| Field | Value |
|-------|-------|
| **Playbook ID** | PB-03 |
| **Scenario** | An attacker who already has a foothold tries to gain root or establish a privileged foothold |
| **MITRE ATT&CK** | [T1548.003 Sudo/Sudo Caching](https://attack.mitre.org/techniques/T1548/003/), [T1136 Create Account](https://attack.mitre.org/techniques/T1136/), [T1098 Account Manipulation](https://attack.mitre.org/techniques/T1098/) |
| **Severity (default)** | High |
| **Triggering detections** | Wazuh `100031` (sudoers), `100030` (passwd/shadow), `100020` (new account), `100061` (cron) |
| **Simulation** | [`simulations/privilege-escalation`](../simulations/README.md) |
| **Author** | Anthony Mackenzi |

## 1. Preparation
- auditd installed with the lab keys (`identity`, `priv_esc`) — see
  `deploy/audit/homesoc-audit.rules`.
- FIM watching `/etc/cron*` and `/var/spool/cron`.

## 2. Identification
Dashboard → **Threat Hunting → Events**.

| What happened | Query |
|---------------|-------|
| Sudoers changed | `rule.id:100031` |
| passwd/shadow/group changed | `rule.id:100030` |
| New user/group created | `rule.id:100020` |
| Cron persistence | `rule.id:100061` |

Record the actor and the change:
- **Who:** `data.audit.auid` / `data.audit.uid` (the auditd `auid` is the *login*
  user — it survives `su`/`sudo`, so it identifies the human behind the action).
- **What:** `data.audit.file.name` or the FIM `syscheck.diff`.
- **When / where:** `timestamp`, `agent.name`.

On the host:
```bash
sudo ausearch -k priv_esc -i | tail -n 40      # sudoers changes with context
sudo ausearch -k identity -i | tail -n 40      # passwd/shadow/group changes
sudo getent group sudo root                    # who is privileged right now
grep -R "" /etc/sudoers /etc/sudoers.d 2>/dev/null
```

## 3. Triage & severity
- **Change maps to a known, ticketed admin action** → likely benign; annotate and close.
- **Change made by an unexpected `auid`, or right after another alert** (e.g.
  PB-01 login) → **Critical**; the foothold is escalating.

## 4. Containment
```bash
# Revert the unauthorised privilege change
sudo visudo                                    # remove the rogue rule safely
sudo gpasswd -d <USER> sudo                     # remove from sudo group
sudo passwd -l <USER>; sudo pkill -KILL -u <USER>
```

## 5. Eradication
- Remove any account the attacker created (`sudo userdel -r <USER>`).
- Remove rogue cron entries / systemd units / `authorized_keys`.
- Reset credentials for any account that was used to make the change.
- Diff the system against your baseline (packages, SUID binaries):
  ```bash
  find / -perm -4000 -type f 2>/dev/null       # unexpected SUID binaries (T1548.001)
  ```

## 6. Recovery
- Confirm `getent group sudo`/`root` matches your intended list.
- Keep `rule.id:(100030 OR 100031 OR 100020)` under close watch for 24–48h.

## 7. Lessons learned & detection tuning
- Alert-worthy privilege changes should be **rare** — if these rules are noisy,
  your change management is the problem, not the rule.
- Add an active-response that emails/kills on `100031` (sudoers is almost never
  edited outside a maintenance window).
- Consider SCA (Security Configuration Assessment) policies to catch weak
  sudo/SUID configs proactively.

## References
- MITRE ATT&CK T1548 — https://attack.mitre.org/techniques/T1548/
- MITRE ATT&CK T1136 — https://attack.mitre.org/techniques/T1136/
