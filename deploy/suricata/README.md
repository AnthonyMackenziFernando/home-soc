# Suricata — network IDS sensor

Suricata runs **on an endpoint** (the host laptop and/or the victim VM), watches
the network interface in real time, and writes findings to
`/var/log/suricata/eve.json`. The Wazuh agent on that same host tails the EVE
file, so every Suricata alert becomes a Wazuh alert (Wazuh ships built-in
decoders/rules for Suricata — rule group `86600`).

```
   NIC traffic ──> Suricata ──> /var/log/suricata/eve.json ──> Wazuh agent ──> Wazuh manager ──> Dashboard
```

## Install

From the endpoint you want to monitor:

```bash
sudo bash scripts/install-suricata.sh            # auto-detects the interface
sudo IFACE=eth0 bash scripts/install-suricata.sh # or name it explicitly
```

That installs Suricata, points it at your interface, enables the Community ID
field (so you can pivot between Suricata and other logs on the same flow), pulls
the free **Emerging Threats Open** ruleset with `suricata-update`, and starts the
service.

## Load the custom rules in this repo

`custom.rules` holds the lab's home-grown signatures (SID range
`1000000-1999999`, each tagged with a MITRE ATT&CK id).

```bash
# 1. Copy the rules into Suricata's rules directory
sudo cp deploy/suricata/custom.rules /etc/suricata/rules/custom.rules

# 2. Register the file so Suricata loads it — add this line under `rule-files:`
#    in /etc/suricata/suricata.yaml
#        rule-files:
#          - suricata.rules
#          - /etc/suricata/rules/custom.rules

# 3. Validate the configuration and ruleset, then reload
sudo suricata -T -c /etc/suricata/suricata.yaml -v
sudo systemctl restart suricata
```

## Test it

```bash
# Triggers an ET Open signature (safe, well-known NIDS test URL)
curl -s http://testmynids.org/uid/index.html >/dev/null

# Triggers our custom EICAR rule (SID 1000004)
curl -s https://secure.eicar.org/eicar.com.txt >/dev/null
```

Within a few seconds these should appear in the Wazuh dashboard under
**Threat Hunting → Events**, filtered on `rule.groups: suricata`.

## Files

| File | Purpose |
|------|---------|
| `custom.rules` | Lab-authored Suricata signatures, MITRE-tagged |
| `../../scripts/install-suricata.sh` | Installer/configurator for a Debian/Ubuntu endpoint |
