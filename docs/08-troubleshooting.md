# 08 — Troubleshooting

Fixes for the issues you're most likely to hit, roughly in order of frequency.

## The indexer won't start / keeps restarting
Almost always one of two things:

1. **`vm.max_map_count` too low** (OpenSearch needs ≥ 262144):
   ```bash
   cat /proc/sys/vm/max_map_count
   sudo sysctl -w vm.max_map_count=262144            # temporary
   echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf   # permanent
   ```
2. **Out of memory (OOM)** on the 8 GB host. Check `make logs` for `Killed` /
   heap errors. Keep `INDEXER_HEAP=512m` in `deploy/.env`, close other apps, and
   only boot the victim VM while actively simulating.

## Dashboard shows 503 / "not ready"
The dashboard starts before the indexer is fully up. Wait 1–3 minutes on first
run. Confirm the indexer answers:
```bash
curl -sk -u admin:SecretPassword https://localhost:9200/_cluster/health
```
Green/yellow is fine (yellow is normal for a single node).

## Certificate errors on start
The certs are generated once into `deploy/config/wazuh_indexer_ssl_certs/`. If
they're missing or partial:
```bash
cd deploy
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose down && docker compose up -d
```
Browser TLS warnings on `https://localhost/` are **expected** (self-signed lab
certs) — click through.

## An agent won't connect / doesn't appear
```bash
# On the agent:
sudo tail -n 50 /var/ossec/logs/ossec.log        # look for connection errors
sudo systemctl status wazuh-agent
```
Checklist:
- The agent's manager address is the SOC host IP (re-run `install-agent-linux.sh`
  with the right `MANAGER_IP`).
- Ports **1514/tcp** (events) and **1515/tcp** (enrolment) are reachable — open
  them on the SOC host firewall for the lab subnet.
- Time is roughly in sync between hosts (large skew breaks TLS).

## A rule isn't firing
Work it in this order:
1. **Is the log arriving?** Dashboard → Events, filter by the source
   (`rule.groups:audit`, `syscheck.event:*`, `rule.groups:suricata`). If not, it's
   a log-source problem, not a rule problem — see [03](03-log-sources.md).
2. **Does the rule logically match?** `make logtest`, paste a sample line, and see
   which rule fires. This catches wrong field names and typos.
3. **Was it deployed?** `make deploy-rules` (it validates, then reloads). A
   validation failure is printed and the manager is left running the old ruleset.

## Suricata produces no `eve.json`
```bash
sudo systemctl status suricata
sudo suricata -T -c /etc/suricata/suricata.yaml -v     # config test
ip -br link                                            # confirm the interface name
```
Make sure `IFACE` in `/etc/default/suricata` matches a real, up interface, then
`sudo systemctl restart suricata`.

## Running low on disk
Indexed alerts grow over time. Check and, if needed, reset lab data:
```bash
docker system df
make destroy     # stops the stack AND deletes data volumes — lab reset
make up
```

## Still stuck?
```bash
make logs                                   # all three services
docker compose -f deploy/docker-compose.yml logs wazuh.manager
```
Cross-check versions against the pinned `WAZUH_VERSION` in `deploy/.env` and the
official Wazuh Docker docs.
