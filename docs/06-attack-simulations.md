# 06 — Attack simulations

To trust a detection you have to watch it fire. Every detection in this lab has a
safe, repeatable trigger in [`simulations/`](../simulations/README.md).

## Safety first
- Run simulations **only** against machines you own in this lab.
- Every script prints a `[LAB]` banner and is reversible; the
  privilege-escalation one requires `--confirm` and cleans up after itself.
- Nothing downloads real malware — the "malware" test uses the standardised,
  harmless **EICAR** string.

## The matrix
| Simulation | Fires | Playbook | Investigation |
|------------|-------|----------|---------------|
| `ssh-bruteforce` | 100001 (+100002) | PB-01 | INV-2026-07-01 |
| `custom-app-bruteforce` | 100071, 100072 | PB-01 | — |
| `web-attack` | 100050, 1000005/6 | PB-04 | INV-2026-07-02 |
| `malware-eicar` | 1000004, 100062 | PB-02 | — |
| `reverse-shell` | 100062, 100034, 1000003 | PB-05 | INV-2026-07-03 |
| `privilege-escalation` | 100020, 100030, 100031, 100061 | PB-03 | — |

## The full drill (what to practise)
1. **Simulate** — run a script.
2. **Detect** — find the alert on the dashboard (queries are in each playbook).
3. **Respond** — work the matching [playbook](../playbooks/README.md).
4. **Document** — write it up under
   [`investigations/`](../investigations/README.md) with your own screenshots.

Doing that loop a few times is what turns "I set up Wazuh" into "I can run an
incident" — which is the story the repo tells a reviewer.

## Start here
```bash
bash simulations/custom-app-bruteforce/run.sh   # self-contained, no target needed
# Dashboard: rule.id:100072
```
