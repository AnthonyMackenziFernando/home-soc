# 10 — Hardening

The stack ships with Wazuh's **default demo credentials** so it works out of the
box. That is fine for an isolated lab and unacceptable for anything else. This is
a security project — treating your own SOC casually is exactly the wrong message,
so here is how to lock it down.

## 1. Change every default password
Four credentials ship as defaults. All of them must change before the stack is
reachable by anyone but you.

| Credential | Default | Where it lives |
|------------|---------|----------------|
| Indexer `admin` | `SecretPassword` | `docker-compose.yml` env + `internal_users.yml` |
| Indexer `kibanaserver` | `kibanaserver` | `docker-compose.yml` env + `internal_users.yml` |
| Wazuh API `wazuh-wui` | `MyS3cr37P450r.*-` | `docker-compose.yml` env |
| Dashboard login (`admin`) | = indexer admin | indexer |

**Recommended:** follow the official, version-matched procedure —
*Wazuh docs → Deployment → Docker → Change the default passwords*.

<details>
<summary>Manual method for the indexer users (admin / kibanaserver)</summary>

```bash
cd deploy
# 1. Generate a bcrypt hash for the new password
docker compose exec wazuh.indexer \
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p 'NEW_STRONG_PASSWORD'

# 2. Paste the hash into config/wazuh_indexer/internal_users.yml (admin: hash: ...)
# 3. Put the plaintext in docker-compose.yml (INDEXER_PASSWORD / DASHBOARD_PASSWORD)
#    and anywhere the manager/dashboard reference it.
# 4. Restart, then re-apply the security config:
docker compose restart wazuh.indexer
docker compose exec wazuh.indexer bash -c '\
  I=/usr/share/wazuh-indexer; JAVA_HOME=$I/jdk \
  $I/plugins/opensearch-security/tools/securityadmin.sh \
  -cd $I/opensearch-security/ -nhnv \
  -cacert $I/config/certs/root-ca.pem \
  -cert $I/config/certs/admin.pem -key $I/config/certs/admin-key.pem -p 9200 -icl'
```
</details>

Also change the **cluster key** in
[`wazuh_manager.conf`](../deploy/config/wazuh_cluster/wazuh_manager.conf)
(`<cluster><key>`) if you ever enable clustering.

## 2. Don't expose it to the internet
The dashboard (443), indexer (9200), API (55000) and agent ports (1514/1515)
should be reachable **only from your lab network**.

- Keep the SOC on a private/host-only network or behind your home router with **no
  port forwards**.
- Restrict with the host firewall — allow the lab subnet only:
  ```bash
  sudo ufw allow from 192.168.1.0/24 to any port 1514,1515,443 proto tcp
  sudo ufw deny 9200
  ```
- Never put this stack on a public cloud IP without a VPN/reverse proxy and real
  auth in front.

## 3. Secrets hygiene (already enforced)
- `deploy/.env` and the generated `config/wazuh_indexer_ssl_certs/` are
  **git-ignored** — verify with `git status` that neither is ever staged.
- Never commit real passwords, private keys, or captured logs. The
  [`.gitignore`](../.gitignore) covers `*.pem`, `*.key`, `*.log`, `*.pcap`.
- The demo passwords in this repo are Wazuh's published defaults, not secrets —
  once you rotate them, keep the new ones out of git.

## 4. TLS
Certificates are self-signed for the lab (fine here). For any non-lab use, issue
certs from a real CA and set `FILEBEAT_SSL_VERIFICATION_MODE=full` end to end
(already the default in the compose file).

## 5. Harden the monitored endpoints too
The lab teaches defence — apply it:
- SSH: key-only auth, no root login, `AllowUsers`.
- **Egress filtering** on the victim — the single control that would have stopped
  INV-2026-07-03's C2 channel.
- Keep the OS and the Wazuh stack patched (`WAZUH_VERSION` bump + `make down/up`).

## 6. Back up what matters
Detection content and docs are in git. Before a risky change, snapshot the VMs
and, if you care about the alert history, back up the `wazuh-indexer-data`
volume.
