# PB-XX — <Scenario name>

| Field | Value |
|-------|-------|
| **Playbook ID** | PB-XX |
| **Scenario** | <one line> |
| **MITRE ATT&CK** | Txxxx (<tactic>) |
| **Severity (default)** | Low / Medium / High / Critical |
| **Triggering detections** | <Wazuh/Suricata rule IDs> |
| **Author** | Anthony Mackenzi |

## 1. Preparation
_What must already be in place for this playbook to work (log sources, agents,
rules, backups)._

## 2. Identification
_How the alert appears on the dashboard, the query to pivot on, and the facts to
confirm before acting._

- **Dashboard query:** `rule.id:<id>`
- **Confirm:** who / what / where / when / which asset

## 3. Triage & severity
_Questions that raise or lower severity, and the escalation threshold._

## 4. Containment
_Immediate actions to stop the bleeding (with exact commands). Prefer reversible
containment first._

## 5. Eradication
_Remove the attacker's foothold: kill processes, remove persistence, reset
credentials._

## 6. Recovery
_Restore normal operations and verify the threat is gone. What to watch for._

## 7. Lessons learned & detection tuning
_What worked, what was noisy, and the concrete rule/log-source change that would
catch this faster next time._

## References
- <links>
