# Sigma rules

[Sigma](https://github.com/SigmaHQ/sigma) is a generic, vendor-neutral signature
format for logs — "the YARA of SIEM". Writing detections in Sigma proves the
logic isn't tied to one product: the same rule can be converted to Wazuh,
Elastic, Splunk, Microsoft Sentinel, and more.

Each file here is the portable twin of a Wazuh rule in
[`../wazuh-rules/local_rules.xml`](../wazuh-rules/local_rules.xml).

| File | MITRE | Wazuh twin |
|------|-------|-----------|
| `ssh_brute_force.yml` | T1110 | 100001 |
| `sudoers_modification.yml` | T1548.003 | 100031 |
| `netcat_execution.yml` | T1059 / T1095 | 100034 |
| `web_sqli_in_uri.yml` | T1190 | 100050 |
| `webshell_dropped_in_webroot.yml` | T1505.003 | 100060 |
| `execution_from_tmp.yml` | T1059 | 100062 |

## Converting Sigma to a target backend

Using the modern `sigma` CLI (pySigma):

```bash
pip install sigma-cli
sigma plugin install elasticsearch          # or splunk, etc.

# Validate the rules in this folder
sigma check detections/sigma/

# Convert one rule to an Elasticsearch (Lucene) query
sigma convert -t lucene detections/sigma/netcat_execution.yml
```

## Status

All rules are marked `experimental`: they have been reasoned through and mapped
to the lab's simulations, but you should confirm field names against your own
data before promoting them to `stable`. Field names follow the Sigma taxonomy
(`process_creation`, `file_event`, `webserver`, service `sshd`/`auditd`); some
backends need a field mapping to match their schema.
