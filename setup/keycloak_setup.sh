#!/bin/bash
set -euo pipefail

KC_URL="http://localhost:8180"
KC_ADMIN_USER="${KC_ADMIN_USER:?Set KC_ADMIN_USER}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:?Set KC_ADMIN_PASSWORD}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:?Set OIDC_CLIENT_SECRET}"
KC_DEMO_USER_PASSWORD="${KC_DEMO_USER_PASSWORD:?Set KC_DEMO_USER_PASSWORD}"

echo "Waiting for Keycloak to be ready..."
for i in $(seq 1 30); do
  if curl -sf "$KC_URL/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; then
    echo "Keycloak ready"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Keycloak not ready after 300s"
    exit 1
  fi
  sleep 10
done

echo "Getting admin token..."
TOKEN=$(curl -sf -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN_USER}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi
echo "Token acquired (length: ${#TOKEN})"

echo "Creating trustification realm..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm": "trustification", "enabled": true}')
if [ "$HTTP" = "201" ] || [ "$HTTP" = "409" ]; then
  echo " - realm ok (HTTP $HTTP)"
else
  echo "ERROR: realm creation failed (HTTP $HTTP)"
  exit 1
fi

FRONTEND_JSON=$(python3 -c 'import json; print(json.dumps({
  "clientId": "frontend",
  "publicClient": True,
  "directAccessGrantsEnabled": True,
  "redirectUris": ["http://localhost:*", "http://127.0.0.1:*"],
  "webOrigins": ["http://localhost:*", "http://127.0.0.1:*"],
  "enabled": True
}))')

echo "Creating frontend client (public)..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$FRONTEND_JSON")
echo " - frontend client (HTTP $HTTP)"

WALKER_JSON=$(python3 -c 'import json, os; print(json.dumps({
  "clientId": "walker",
  "publicClient": False,
  "directAccessGrantsEnabled": True,
  "serviceAccountsEnabled": True,
  "secret": os.environ["OIDC_CLIENT_SECRET"],
  "redirectUris": ["http://localhost:*", "http://127.0.0.1:*"],
  "enabled": True
}))')

echo "Creating walker client (confidential, service account)..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$WALKER_JSON")
echo " - walker client (HTTP $HTTP)"

USER_JSON=$(python3 -c 'import json, os; print(json.dumps({
  "username": "demo-user",
  "enabled": True,
  "credentials": [{"type": "password", "value": os.environ["KC_DEMO_USER_PASSWORD"], "temporary": False}]
}))')

echo "Creating testing user..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$USER_JSON")
echo " - demo user (HTTP $HTTP)"

echo "KEYCLOAK_SETUP_COMPLETE"
echo "OIDC Issuer URL: $KC_URL/realms/trustification"
