#!/bin/bash
set -e

source .env

echo "========================================="
echo "Assigning Users to Groups"
echo "========================================="

# Wait for Keycloak to be fully ready
echo " Waiting for Keycloak to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s -f "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" > /dev/null 2>&1; then
    echo " Keycloak is ready!"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "   Attempt $RETRY_COUNT/$MAX_RETRIES - waiting 2 seconds..."
  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo " Keycloak did not start in time"
  exit 1
fi

echo ""
echo " Getting admin token..."

# Get admin token
ADMIN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin")

ADMIN_TOKEN=$(echo "$ADMIN_RESPONSE" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo " Failed to get admin token"
  echo "Response: $ADMIN_RESPONSE"
  exit 1
fi

echo " Admin token obtained"
echo ""

# Get Alice's user ID
echo " Looking up Alice..."
ALICE_RESPONSE=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=alice" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

ALICE_ID=$(echo "$ALICE_RESPONSE" | jq -r '.[0].id')

# Get Bob's user ID
echo " Looking up Bob..."
BOB_RESPONSE=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=bob" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

BOB_ID=$(echo "$BOB_RESPONSE" | jq -r '.[0].id')

if [ "$ALICE_ID" == "null" ] || [ "$BOB_ID" == "null" ] || [ -z "$ALICE_ID" ] || [ -z "$BOB_ID" ]; then
  echo " Failed to find users"
  echo "Alice response: $ALICE_RESPONSE"
  echo "Bob response: $BOB_RESPONSE"
  exit 1
fi

echo ""
echo " Looking up groups..."

# Get all groups
GROUPS_LIST=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/groups" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

# Find /atlas group and get its ID
ATLAS_ID=$(echo "$GROUPS_LIST" | jq -r '.[] | select(.path=="/atlas") | .id')

if [ -z "$ATLAS_ID" ] || [ "$ATLAS_ID" == "null" ]; then
  echo " /atlas group not found"
  echo "Available groups:"
  echo "$GROUPS_LIST" | jq -r '.[].path'
  exit 1
fi

echo "   Found /atlas group ID: $ATLAS_ID"

# Fetch subgroups using the /children endpoint
SUBGROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/groups/${ATLAS_ID}/children" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

echo "   Fetched subgroups"

# Check if response is valid
if ! echo "$SUBGROUPS" | jq -e 'type == "array"' > /dev/null 2>&1; then
  echo " Invalid subgroups response"
  echo "$SUBGROUPS"
  exit 1
fi

SUBGROUPS_COUNT=$(echo "$SUBGROUPS" | jq 'length')
echo "   Found $SUBGROUPS_COUNT subgroup(s)"

# Extract subgroup IDs
ATLAS_PROD_ID=$(echo "$SUBGROUPS" | jq -r '.[] | select(.name=="production") | .id')
ATLAS_USERS_ID=$(echo "$SUBGROUPS" | jq -r '.[] | select(.name=="users") | .id')

if [ -z "$ATLAS_PROD_ID" ] || [ -z "$ATLAS_USERS_ID" ]; then
  echo " Failed to find required subgroups"
  echo "Available subgroups:"
  echo "$SUBGROUPS" | jq -r '.[].name'
  exit 1
fi

echo " Found all groups and users"
echo ""
echo "User IDs:"
echo "  Alice: $ALICE_ID"
echo "  Bob:   $BOB_ID"
echo ""
echo "Group IDs:"
echo "  /atlas:            $ATLAS_ID"
echo "  /atlas/production: $ATLAS_PROD_ID"
echo "  /atlas/users:      $ATLAS_USERS_ID"
echo ""

# Assign Alice to /atlas/production
echo " Assigning Alice to /atlas/production..."
HTTP_STATUS=$(curl -s -w "%{http_code}" -o /dev/null -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ALICE_ID}/groups/${ATLAS_PROD_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json")

if [ "$HTTP_STATUS" == "204" ]; then
  echo "    Success"
else
  echo "     Status: $HTTP_STATUS"
fi

# Assign Alice to /atlas/users
echo " Assigning Alice to /atlas/users..."
HTTP_STATUS=$(curl -s -w "%{http_code}" -o /dev/null -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ALICE_ID}/groups/${ATLAS_USERS_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json")

if [ "$HTTP_STATUS" == "204" ]; then
  echo "    Success"
else
  echo "     Status: $HTTP_STATUS"
fi

# Assign Bob to /atlas/users
echo " Assigning Bob to /atlas/users..."
HTTP_STATUS=$(curl -s -w "%{http_code}" -o /dev/null -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${BOB_ID}/groups/${ATLAS_USERS_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json")

if [ "$HTTP_STATUS" == "204" ]; then
  echo "    Success"
else
  echo "     Status: $HTTP_STATUS"
fi

echo ""
echo "========================================="
echo " Group assignments complete!"
echo "========================================="
echo ""
echo "Verification:"
echo ""

# Verify Alice's groups
ALICE_GROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ALICE_ID}/groups" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[].path')

echo "Alice's groups:"
if [ -z "$ALICE_GROUPS" ]; then
  echo "  (none)"
else
  echo "$ALICE_GROUPS" | sed 's/^/  /'
fi

echo ""

# Verify Bob's groups
BOB_GROUPS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${BOB_ID}/groups" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[].path')

echo "Bob's groups:"
if [ -z "$BOB_GROUPS" ]; then
  echo "  (none)"
else
  echo "$BOB_GROUPS" | sed 's/^/  /'
fi

echo ""
echo " You can now run: ./scripts/1-get-user-token.sh"