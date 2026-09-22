#!/usr/bin/env bash
# Demo Trigger: RHSA Available (Lightwell resolved the CVE)
#
# Fires a webhook to EDA simulating the upstream fix being published.
# This triggers Demo 3 (container test → patch → verify → close loop).

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"

echo "=== Firing RHSA Available Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo ""
echo "Narrative: Project Lightwell resolved CVE-2026-31419 upstream."
echo "           Red Hat published RHSA-2026:25191."
echo ""

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "rhsa_available",
    "cve_id": "CVE-2026-31419",
    "advisory_id": "RHSA-2026:25191",
    "fixed_package": "kernel-core",
    "fixed_version": "6.12.0-211.22.1.el10_2",
    "resolved_by": "Project Lightwell",
    "resolution_date": "2026-06-11T12:00:00Z",
    "description": "Red Hat has released kernel 6.12.0-211.22.1.el10_2 which resolves the use-after-free in bonding driver",
    "source": "Red Hat Security Advisory"
  }' | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired. Check EDA UI for rule activation."
echo "Expected: Workflow 'Patch Test and Deploy' should launch."
