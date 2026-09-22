#!/usr/bin/env bash
# Inject a CVE disclosure event into Splunk via HEC
#
# This simulates a security scanner or threat feed pushing a CVE advisory
# into the cve_events index. The Splunk saved search fires every minute,
# detects the event, and sends a webhook to EDA.
#
# Usage:
#   SPLUNK_HOST=splunk.example.com SPLUNK_HEC_TOKEN=... ./inject_splunk_cve.sh

set -euo pipefail

SPLUNK_HOST="${SPLUNK_HOST:-}"
SPLUNK_HEC_PORT="${SPLUNK_HEC_PORT:-8088}"
SPLUNK_HEC_TOKEN="${SPLUNK_HEC_TOKEN:-}"

if [[ -z "${SPLUNK_HOST}" || -z "${SPLUNK_HEC_TOKEN}" ]]; then
  echo "ERROR: SPLUNK_HOST and SPLUNK_HEC_TOKEN must both be set."
  echo "Set SPLUNK_HOST=<host> SPLUNK_HEC_TOKEN=<token> to use."
  exit 1
fi

echo "=== Injecting CVE Disclosure into Splunk ==="
echo "Target: http://${SPLUNK_HOST}:${SPLUNK_HEC_PORT}/services/collector/event"
echo ""

RESPONSE=$(curl -sk "http://${SPLUNK_HOST}:${SPLUNK_HEC_PORT}/services/collector/event" \
  -H "Authorization: Splunk ${SPLUNK_HEC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "index": "cve_events",
    "sourcetype": "cve_advisory",
    "source": "threat_intel_feed",
    "event": {
      "event_type": "cve_disclosure",
      "cve_id": "CVE-2026-31419",
      "affected_package": "kernel",
      "affected_version_range": "< 6.12.0-211.22.1.el10_2",
      "cvss_vector": "CVSS:3.1/AV:L/AC:H/PR:L/UI:N/S:U/C:H/I:H/A:H",
      "cvss_score": 7.0,
      "cwe_ids": "[\"CWE-416\"]",
      "description": "Use-after-free vulnerability in Linux kernel bonding driver (bond_xmit_broadcast) leads to denial of service via double-free of socket buffer",
      "source": "Red Hat Security Advisory",
      "fix_available": false,
      "published_date": "2026-06-11T06:00:00Z",
      "severity": "important"
    }
  }')

echo "Splunk response: ${RESPONSE}"
echo ""
echo "Event injected into index=cve_events, sourcetype=cve_advisory"
echo ""
echo "Next steps:"
echo "  1. Verify in Splunk UI:  http://${SPLUNK_HOST}:8000/en-US/app/search/search?q=index%3Dcve_events"
echo "  2. The saved search runs every minute and will fire the webhook to EDA"
echo "  3. Check EDA UI for rule activation: 'Splunk alert — CVE disclosure detected'"
echo "  4. Expected workflow: 'SBOM Correlate and Mitigate'"
