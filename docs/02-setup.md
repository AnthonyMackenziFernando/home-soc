# 02 — Setup

End-to-end setup on Ubuntu/Debian, from a clean machine to a working SOC with a
detection firing. Budget ~30–45 minutes (mostly image downloads on first run).

> Assumes an 8 GB (or larger) host for the SOC and, optionally, a lightweight
> Linux VM as the "victim". You can also monitor the SOC host itself.

## 1. Prerequisites — Docker Engine + Compose

```bash
# Install Docker Engine and the Compose plugin
curl -fsSL https://get.docker.com | sudo sh

# Run docker without sudo (log out/in afterwards, or run: newgrp docker)
sudo usermod -aG docker "$USER"

# Verify
docker --version
docker compose version
```

## 2. Get the repo

```bash
git clone <your-home-soc-repo-url>
cd home-soc
```

## 3. Bring up the stack

One command does everything — kernel tuning, TLS certs, start, and rule
deployment:

```bash
make up
```

<details>
<summary>What <code>make up</code> does (or run these by hand)</summary>

```bash
# raise the mmap limit OpenSearch needs
sudo sysctl -w vm.max_map_count=262144

cp deploy/.env.example deploy/.env
cd deploy
docker compose -f generate-indexer-certs.yml run --rm generator   # TLS certs (once)
docker compose up -d                                              # start 3 services
cd .. && bash scripts/deploy-rules.sh                             # load custom rules
```
</details>

When it finishes it prints the dashboard URL and login.

## 4. Open the dashboard

Browse to **https://localhost/** (accept the self-signed cert warning — expected
in a lab).

- Username: `admin`
- Password: `SecretPassword`

> These are Wazuh's default demo credentials. **Change them** before exposing
> anything — see [`10-hardening.md`](10-hardening.md).

Check health any time:
```bash
make health
```

## 5. Enrol an endpoint

On the machine you want to monitor (the victim VM, or this host itself), with the
SOC host's IP:

```bash
# copy scripts/install-agent-linux.sh to the endpoint, then:
sudo MANAGER_IP=<soc-host-ip> bash install-agent-linux.sh
```

This installs the Wazuh agent, enrols it, installs **auditd** with the lab's
keyed rules, and adds the Suricata / auth.log / syslog log sources. Confirm the
agent shows up under **Agents** in the dashboard (or `make health`).

## 6. Add the network IDS (optional but recommended)

On the same endpoint:
```bash
sudo bash install-suricata.sh          # from scripts/
```
Then load the custom Suricata rules as described in
[`../deploy/suricata/README.md`](../deploy/suricata/README.md).

## 7. Fire your first detection

```bash
# Self-contained — no target needed:
bash simulations/custom-app-bruteforce/run.sh

# Then in the dashboard: Threat Hunting -> Events -> rule.id:100072
```

If you see the alert, the whole pipeline — log source → decoder → rule →
correlation → dashboard — is working. 🎉

## Everyday commands (`make help`)

| Command | Does |
|---------|------|
| `make up` | Bootstrap / start everything |
| `make down` | Stop the stack (keeps data) |
| `make health` | Container + indexer + agent status |
| `make logs` | Tail stack logs |
| `make deploy-rules` | Re-deploy detection content after editing it |
| `make logtest` | Open the interactive rule tester |
| `make destroy` | Stop **and delete all data volumes** |

## Next
- [03 — Log sources](03-log-sources.md)
- [05 — Detection engineering](05-detection-engineering.md)
- [08 — Troubleshooting](08-troubleshooting.md) if something won't start
