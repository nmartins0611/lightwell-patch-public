#!/usr/bin/env bash
# Demo Trigger: CVE Disclosure (no fix available yet)
#
# Fires a webhook to EDA simulating a CVE advisory notification.
# This triggers Demo 1 (SBOM correlation) + Demo 2 (CME mitigation).

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"

echo "=== Firing CVE Disclosure Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo ""

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "cve_disclosure",
    "cve_id": "CVE-2026-31419",
    "affected_package": "kernel",
    "affected_version_range": "< 6.12.0-211.22.1.el10_2",
    "cvss_vector": "CVSS:3.1/AV:L/AC:H/PR:L/UI:N/S:U/C:H/I:H/A:H",
    "cvss_score": 7.0,
    "cwe_ids": ["CWE-416"],
    "description": "Use-after-free vulnerability in Linux kernel bonding driver (bond_xmit_broadcast) leads to denial of service via double-free of socket buffer",
    "source": "Red Hat Security Advisory",
    "fix_available": false,
    "published_date": "2026-06-11T06:00:00Z"
  }' | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired. Check EDA UI for rule activation."
echo "Expected: Workflow 'SBOM Correlate and Mitigate' should launch."
