# Screenshots to capture (INV-2026-07-02)

Run `simulations/web-attack/run.sh` (and drop the test web shell as shown in the
report appendix), then capture from the Wazuh dashboard and save here:

- `01-fim-webshell-alert.png` — the rule 100060 alert (new file in the web root)
- `02-access-log.png` — the Apache access-log events showing scan → SQLi → upload → shell access
