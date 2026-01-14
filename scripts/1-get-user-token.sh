#!/bin/bash
set -e

source .env

echo "========================================="
echo "Getting token for user: $ALICE_USERNAME"
echo "========================================="

RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "username=${ALICE_USERNAME}" \
  -d "password=${ALICE_PASSWORD}" \
  -d "scope=wlcg storage.read storage.create")

ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')
REFRESH_TOKEN=$(echo $RESPONSE | jq -r '.refresh_token')

if [ "$ACCESS_TOKEN" == "null" ]; then
  echo " Failed to get token"
  echo $RESPONSE | jq
  exit 1
fi

echo " Token obtained successfully!"
echo ""
echo "Access Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
echo ""
echo "Full response:"
echo $RESPONSE | jq

# Save tokens for other scripts
echo $ACCESS_TOKEN > /tmp/access_token.txt
echo $REFRESH_TOKEN > /tmp/refresh_token.txt

echo ""
echo " Tokens saved to /tmp/access_token.txt and /tmp/refresh_token.txt"
echo ""
echo "Run ./scripts/3-decode-token.sh to see the decoded token"