# `deploy/` — the SOC stack

This directory brings up the **Wazuh single-node** platform: a manager
(SIEM/XDR brain), an indexer (OpenSearch storage/search), and a dashboard
(the analyst UI). The layout mirrors the official Wazuh Docker deployment so it
stays easy to reason about and upgrade.

## Prerequisites

- Docker Engine + the Docker Compose plugin
- `vm.max_map_count >= 262144` (the bootstrap script sets this for you)
- ~4 GB free RAM for the stack (tuned down for an 8 GB host — see `.env`)

## Bring it up

The one-liner (from the repo root) does everything — certs, start, rules:

```bash
make up          # == scripts/setup.sh
```

Or manually, step by step:

```bash
cp deploy/.env.example deploy/.env
cd deploy

# 1. Generate TLS certs once (written to config/wazuh_indexer_ssl_certs/, git-ignored)
docker compose -f generate-indexer-certs.yml run --rm generator

# 2. Start the three services
docker compose up -d

# 3. Load this repo's detection content into the manager
cd .. && bash scripts/deploy-rules.sh
```

Dashboard: **https://localhost/** — default login `admin` / `SecretPassword`.

## Layout

```
deploy/
├── docker-compose.yml            # the three services, tuned for 8 GB RAM
├── generate-indexer-certs.yml    # one-shot TLS certificate generator
├── .env.example                  # version + heap knobs (copy to .env)
├── config/
│   ├── certs.yml                 # node names fed to the cert generator
│   ├── wazuh_cluster/
│   │   ├── wazuh_manager.conf    # the manager's ossec.conf
│   │   └── agent.conf            # centralised config pushed to all agents
│   ├── wazuh_indexer/            # opensearch.yml + internal_users.yml
│   └── wazuh_dashboard/          # dashboard config
└── suricata/                     # network IDS rules + install notes
```

## Tuning for RAM

Everything that matters is in `.env`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `WAZUH_VERSION` | `4.14.6` | Image tag for all three services |
| `INDEXER_HEAP` | `512m` | OpenSearch JVM heap — the main RAM lever |

On an 8 GB laptop, keep the indexer at `512m` and only run the victim VM while
you're actively simulating an attack. If the indexer looks unstable
(`make logs` shows OOM), close other apps before raising the heap.

## ⚠️ Credentials

The stack ships with Wazuh's **default demo passwords** so it works out of the
box. They are fine for an isolated lab but must be rotated before you expose the
stack to anything. The procedure is in
[`../docs/10-hardening.md`](../docs/10-hardening.md). Never publish real
credentials or the generated `config/wazuh_indexer_ssl_certs/` directory — both
are git-ignored on purpose.
