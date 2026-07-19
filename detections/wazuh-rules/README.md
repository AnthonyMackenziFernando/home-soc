# Wazuh rules & decoders

## Files

| File | Purpose |
|------|---------|
| `local_rules.xml` | Custom detection rules, IDs `100000+`, each MITRE-tagged |
| `local_decoder.xml` | Custom decoder for the `homesoc-app` demo log source |

These are deployed into the running manager by
[`scripts/deploy-rules.sh`](../../scripts/deploy-rules.sh), which validates the
ruleset (`wazuh-analysisd -t`) before restarting the manager.

## How a detection flows through Wazuh

```
log line ──▶ DECODER (extracts fields: srcip, user, file, audit.key …)
          ──▶ RULE   (matches fields / groups, assigns level + MITRE id)
          ──▶ ALERT  (indexed, shown on the dashboard, may fire active response)
```

A rule reuses a built-in decoder (sshd, sudo, auditd, syscheck, Suricata) unless
the log source is bespoke — then you write a decoder first, as done for
`homesoc-app` in `local_decoder.xml`.

## Testing a rule before you ship it

Use the interactive log tester — no need to generate a real attack:

```bash
# from the repo root
make logtest
# or directly:
docker compose -f deploy/docker-compose.yml exec wazuh.manager /var/ossec/bin/wazuh-logtest
```

Paste a sample line, e.g. for the custom demo-app decoder:

```
Jul 19 10:00:00 host homesoc-app: LOGIN_FAILED user=admin src=10.0.0.5 reason=badpass
```

`wazuh-logtest` prints which decoder matched, the extracted fields, and the rule
that fired (expect rule `100071`). Repeat the line 5× within 60s in a real feed
to see the correlation rule `100072` escalate.

## Anatomy of a rule

```xml
<rule id="100031" level="12">
  <if_group>audit</if_group>                     <!-- only look at auditd events -->
  <field name="audit.key">priv_esc</field>       <!-- our auditd key (see deploy/audit) -->
  <description>Sudoers configuration modified ...</description>
  <mitre><id>T1548.003</id></mitre>              <!-- ATT&CK technique -->
  <group>audit,privilege_escalation,</group>
</rule>
```

- **level** drives alerting: `>= 7` notable, `>= 10` high, `>= 12` critical.
  `log_alert_level` in the manager config is `3`, so everything meaningful is
  stored.
- **`<if_group>` / `<if_sid>`** chain your rule onto existing detections.
- **`<if_matched_sid>` + `<same_source_ip/>` + `frequency`/`timeframe`** build
  correlations across multiple events (used by 100001, 100002, 100072).

## Deploying changes

```bash
# edit local_rules.xml / local_decoder.xml, then:
make deploy-rules      # copies in, validates, hot-reloads the manager
```

If validation fails, the manager is **not** restarted and the error is printed —
fix it and re-run. This is the lab's miniature "detection-as-code" loop.
