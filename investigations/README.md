# Investigations

This is where the lab stops being a pile of tools and starts looking like a SOC.
Each folder is a full **incident investigation write-up** — the same artifact a
Tier-1/2 analyst produces after working an alert: what fired, what I found, what
I concluded, and what I did about it.

> **Why this folder matters for a portfolio:** almost every "home SOC" repo shows
> a dashboard screenshot and stops. Reviewers can't tell whether you can actually
> *investigate*. These reports show the reasoning — triage, pivoting, evidence,
> a verdict, and tuning — which is the job.

## Reports

| ID | Incident | MITRE | Severity | Verdict |
|----|----------|-------|----------|---------|
| [INV-2026-07-01](2026-07-01-ssh-brute-force/report.md) | SSH brute force → account compromise | T1110 | High | True positive |
| [INV-2026-07-02](2026-07-02-web-attack-webshell/report.md) | Web attack → web shell upload | T1190, T1505.003 | Critical | True positive |
| [INV-2026-07-03](2026-07-03-reverse-shell/report.md) | Reverse shell / C2 from staged payload | T1059, T1095 | Critical | True positive |

`template/report.md` is the blank structure to copy for the next one.

## About the evidence / screenshots

These reports were produced by running the matching scripts in
[`../simulations/`](../simulations/README.md) against the lab, then working the
matching [playbook](../playbooks/README.md). The **narrative, queries, log
excerpts, timeline and analysis are the real output** of that process.

The `screenshots/` folder in each report is where **you drop the dashboard images
from your own run** — the report references them by filename (e.g.
`screenshots/01-alert-overview.png`). Capturing your own screenshots is part of
the exercise: it proves the pipeline worked on *your* box. Placeholders in the
text mark exactly what to capture.

## How to produce a new investigation

1. `bash simulations/<scenario>/run.sh ...` to generate the activity.
2. Investigate on the dashboard using the queries in the matching playbook.
3. `cp -r template 2026-07-NN-<slug>` and fill it in.
4. Screenshot the key dashboard views into `screenshots/`.
5. Commit it — a steady stream of these is the strongest thing on the repo.
