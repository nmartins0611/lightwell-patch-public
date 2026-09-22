#!/usr/bin/env bash
# Demo Trigger: App Dependency Fix
#
# Fires a webhook to EDA simulating Lightwell publishing a fixed library
# to an internal package index.
#
# Use: ./demo/trigger_app_dependency_fix.sh [cicd|gitops|maven]

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"
MODE="${1:-cicd}"
GITEA_HOST="${GITEA_HOST:-builder.example.com}"

echo "=== App Dependency Fix Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo "Mode: ${MODE}"
echo ""

if [[ "${MODE}" == "maven" ]]; then
  EVENT_TYPE="app_dependency_fix_gitops"
  WORKFLOW_DESC="GitOps PR on simple-webapp (pom.xml) → merge → Gitea Actions Maven build"
  CVE_ID="CVE-2026-61002"
  LIBRARY="gson"
  AFFECTED="< 2.11.0"
  FIXED="2.11.0"
  APP_NAME="simple-webapp"
  DEP_FILE="pom.xml"
  PIN_STYLE="maven"
  APP_REPO="http://${GITEA_HOST}:3000/demo-admin/simple-webapp"
  LIGHTWELL_INDEX="http://${GITEA_HOST}:8082/"
  DESCRIPTION="Lightwell published gson 2.11.0 resolving CVE-2026-61002"
  echo "Narrative: Project Lightwell resolved ${CVE_ID} (gson)"
  echo "           and published the fixed JAR to the internal Maven index."
elif [[ "${MODE}" == "gitops" ]]; then
  EVENT_TYPE="app_dependency_fix_gitops"
  WORKFLOW_DESC="GitOps PR → Gitea Actions build → SBOM ingest"
  CVE_ID="CVE-2026-52891"
  LIBRARY="pyyaml"
  AFFECTED="< 6.0.2"
  FIXED="6.0.2"
  APP_NAME="config-service"
  DEP_FILE="requirements.txt"
  PIN_STYLE="pip"
  APP_REPO="http://${GITEA_HOST}:3000/demo-admin/config-service"
  LIGHTWELL_INDEX="http://${GITEA_HOST}:8081/simple/"
  DESCRIPTION="Lightwell published pyyaml 6.0.2 resolving deserialization RCE (${CVE_ID})"
  echo "Narrative: Project Lightwell resolved ${CVE_ID} (pyyaml deserialization)"
  echo "           and published the fixed package to internal PyPI index."
else
  EVENT_TYPE="app_dependency_fix"
  WORKFLOW_DESC="Update dep → trigger CI/CD → build artifact → deploy → health check"
  CVE_ID="CVE-2026-52891"
  LIBRARY="pyyaml"
  AFFECTED="< 6.0.2"
  FIXED="6.0.2"
  APP_NAME="config-service"
  DEP_FILE="requirements.txt"
  PIN_STYLE="pip"
  APP_REPO="http://${GITEA_HOST}:3000/demo-admin/config-service"
  LIGHTWELL_INDEX="http://${GITEA_HOST}:8081/simple/"
  DESCRIPTION="Lightwell published pyyaml 6.0.2 resolving deserialization RCE (${CVE_ID})"
  echo "Narrative: Project Lightwell resolved ${CVE_ID} (pyyaml deserialization)"
  echo "           and published the fixed package to internal PyPI index."
fi

echo ""
echo "KEY DISTINCTION: This is a BUILD-TIME fix, not deploy-time."
echo "The library is an application dependency — remediation requires"
echo "rebuilding the application via CI/CD, not running dnf update."
echo ""

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"${EVENT_TYPE}\",
    \"cve_id\": \"${CVE_ID}\",
    \"affected_library\": \"${LIBRARY}\",
    \"affected_versions\": \"${AFFECTED}\",
    \"fixed_version\": \"${FIXED}\",
    \"app_name\": \"${APP_NAME}\",
    \"app_repo\": \"${APP_REPO}\",
    \"target_branch\": \"main\",
    \"dependency_file\": \"${DEP_FILE}\",
    \"pin_style\": \"${PIN_STYLE}\",
    \"remediation_mode\": \"${MODE}\",
    \"lightwell_index\": \"${LIGHTWELL_INDEX}\",
    \"resolved_by\": \"Project Lightwell\",
    \"resolution_date\": \"2026-07-30T15:00:00Z\",
    \"description\": \"${DESCRIPTION}\",
    \"source\": \"Lightwell Package Registry\",
    \"remediation_note\": \"App dependency — requires CI/CD rebuild, not host-level patching\"
  }" | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired (mode=${MODE}). Check EDA UI for rule activation."
echo ""
echo "Expected workflow: ${WORKFLOW_DESC}"
echo ""
echo "=== Remediation Flow Comparison ==="
echo ""
echo "  OS Package (Demo 3):        Python (Demo 4):              Java (Demo 5):"
echo "  ─────────────────────        ──────────────────            ─────────────────"
echo "  Lightwell → RHSA             Lightwell → PyPI              Lightwell → Maven"
echo "  dnf update on host           Pin requirements.txt          Pin pom.xml"
echo "  Package installed live        Rebuild via Gitea Actions     Rebuild via Gitea Actions"
echo ""
