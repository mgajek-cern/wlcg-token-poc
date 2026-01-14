#!/bin/bash
set -e

source .env

echo "========================================="
echo "Getting token for service: $SERVICE_CLIENT_ID"
echo "========================================="

RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${SERVICE_CLIENT_ID}" \
  -d "client_secret=${SERVICE_CLIENT_SECRET}" \
  -d "scope=wlcg storage.read storage.create")

ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ]; then
  echo " Failed to get token"
  echo $RESPONSE | jq
  exit 1
fi

echo " Service token obtained successfully!"
echo ""
echo "Access Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
echo ""
echo "Full response:"
echo $RESPONSE | jq

# Save token
echo $ACCESS_TOKEN > /tmp/service_token.txt

echo ""
echo " Token saved to /tmp/service_token.txt"
echo ""
echo "Run ./scripts/3-decode-token.sh /tmp/service_token.txt to see the decoded token"