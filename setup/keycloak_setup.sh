#!/bin/bash
set -euo pipefail

KC_URL="${KC_URL:-http://localhost:8180}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:?Set KC_ADMIN_PASSWORD}"
KC_SERVICE_SECRET="${KC_SERVICE_SECRET:?Set KC_SERVICE_SECRET}"
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
  -d "username=admin" \
  -d "password=$KC_ADMIN_PASSWORD" \
  -d "grant_type=password" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi
echo "Token acquired (length: ${#TOKEN})"

echo "Allow HTTP on master realm (no TLS in this demo)..."
MASTER=$(curl -sf -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/master")
echo "$MASTER" | python3 -c "import sys,json; d=json.load(sys.stdin); d['sslRequired']='none'; json.dump(d, sys.stdout)" > /tmp/kc-master.json
curl -sf -X PUT "$KC_URL/admin/realms/master" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/kc-master.json -o /dev/null
echo " - master sslRequired=none"

echo "Creating trustification realm..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm": "trustification", "enabled": true, "sslRequired": "none"}')
if [ "$HTTP" = "201" ] || [ "$HTTP" = "409" ]; then
  echo " - realm ok (HTTP $HTTP)"
else
  echo "ERROR: realm creation failed (HTTP $HTTP)"
  exit 1
fi

echo "Creating frontend client (public)..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "frontend",
    "publicClient": true,
    "directAccessGrantsEnabled": true,
    "redirectUris": ["*"],
    "webOrigins": ["*"],
    "enabled": true
  }')
echo " - frontend client (HTTP $HTTP)"

echo "Creating walker client (confidential, service account)..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "walker",
    "publicClient": false,
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true,
    "secret": "'"$KC_SERVICE_SECRET"'",
    "redirectUris": ["*"],
    "enabled": true
  }')
echo " - walker client (HTTP $HTTP)"

echo "Creating testing user..."
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/trustification/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "demo-user",
    "enabled": true,
    "credentials": [{"type": "password", "value": "'"$KC_DEMO_USER_PASSWORD"'", "temporary": false}]
  }')
echo " - demo user (HTTP $HTTP)"

echo "KEYCLOAK_SETUP_COMPLETE"
echo "OIDC Issuer URL: $KC_URL/realms/trustification"
