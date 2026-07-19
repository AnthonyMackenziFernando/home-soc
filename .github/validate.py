#!/usr/bin/env python3
"""Validate Home SOC detection content and stack config.

Runs in CI (see .github/workflows/ci.yml) and locally:
    python3 .github/validate.py
"""
import glob
import sys
import xml.etree.ElementTree as ET

try:
    import yaml
except ImportError:
    print("PyYAML is required: pip install pyyaml")
    sys.exit(2)

errors = []


def check_xml(path):
    """Parse XML; Wazuh rule/decoder/config files may have multiple top-level
    elements, which is valid for Wazuh but not for a strict parser — wrap and
    retry in that case."""
    raw = open(path, encoding="utf-8").read()
    try:
        ET.fromstring(raw)
    except ET.ParseError:
        try:
            ET.fromstring(f"<root>{raw}</root>")
        except ET.ParseError as e:
            errors.append(f"XML  {path}: {e}")
            return
    print(f"OK  XML   {path}")


def check_sigma(path):
    try:
        doc = yaml.safe_load(open(path, encoding="utf-8"))
        for key in ("title", "logsource", "detection"):
            assert key in doc, f"missing '{key}'"
        assert "condition" in doc["detection"], "detection missing 'condition'"
        tags = [t for t in doc.get("tags", []) if t.startswith("attack.t")]
        assert tags, "no MITRE attack.* technique tag"
        print(f"OK  SIGMA {path} -> {','.join(tags)}")
    except Exception as e:  # noqa: BLE001
        errors.append(f"SIGMA {path}: {e}")


def check_yaml(path):
    try:
        yaml.safe_load(open(path, encoding="utf-8"))
        print(f"OK  YAML  {path}")
    except Exception as e:  # noqa: BLE001
        errors.append(f"YAML  {path}: {e}")


for f in sorted(set(glob.glob("detections/wazuh-rules/*.xml") + glob.glob("deploy/config/wazuh_cluster/*.conf"))):
    check_xml(f)
for f in glob.glob("detections/sigma/*.yml"):
    check_sigma(f)
for f in ["deploy/docker-compose.yml", "deploy/generate-indexer-certs.yml", "deploy/config/certs.yml"]:
    check_yaml(f)

if errors:
    print("\nVALIDATION FAILED:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("\nAll detection content and config validated.")
