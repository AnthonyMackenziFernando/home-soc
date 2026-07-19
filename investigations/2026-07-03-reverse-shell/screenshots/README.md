# Screenshots to capture (INV-2026-07-03)

Run `simulations/reverse-shell/run.sh` (LAN version for the Suricata signal),
then capture from the Wazuh dashboard and save here:

- `01-c2-alerts.png` — the three correlated alerts (100062, 100034, 100040) on one host in one second
- `02-established-connection.png` — terminal capture of `ss -tnp` showing the established connection to the C2
