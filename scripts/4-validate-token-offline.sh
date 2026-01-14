#!/bin/bash
set -e

source .env

TOKEN_FILE=${1:-/tmp/access_token.txt}

if [ ! -f "$TOKEN_FILE" ]; then
  echo " Token file not found: $TOKEN_FILE"
  exit 1
fi

TOKEN=$(cat $TOKEN_FILE)

echo "========================================="
echo "Offline JWT Token Validation"
echo "========================================="

# Decode function
decode_part() {
  local input="$1"
  local len=$((${#input} % 4))
  if [ $len -eq 2 ]; then input="${input}=="; fi
  if [ $len -eq 3 ]; then input="${input}="; fi
  echo "$input" | tr '_-' '/+' | base64 -d 2>/dev/null || echo "$input" | tr '_-' '/+' | base64 -D 2>/dev/null
}

# Decode payload
PAYLOAD_B64=$(echo $TOKEN | cut -d. -f2)
PAYLOAD_JSON=$(decode_part "$PAYLOAD_B64")

# Get public keys
echo " Fetching public keys from Keycloak..."
JWKS=$(curl -s "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs")
echo " Public keys retrieved"

# Extract claims
ISSUER=$(echo "$PAYLOAD_JSON" | jq -r '.iss')
EXPIRY=$(echo "$PAYLOAD_JSON" | jq -r '.exp')
ISSUED_AT=$(echo "$PAYLOAD_JSON" | jq -r '.iat')
SCOPE=$(echo "$PAYLOAD_JSON" | jq -r '.scope')
WLCG_VER=$(echo "$PAYLOAD_JSON" | jq -r '.wlcg.ver // "not present"')
WLCG_GROUPS=$(echo "$PAYLOAD_JSON" | jq -r '.wlcg.groups // "not present"')

# Validate temporal claims
CURRENT_TIME=$(date +%s)
echo ""
echo " Temporal Validation:"
echo "   Current time: $CURRENT_TIME ($(date))"
echo "   Issued at:    $ISSUED_AT ($(date -r $ISSUED_AT 2>/dev/null || echo 'N/A'))"
echo "   Expires at:   $EXPIRY ($(date -r $EXPIRY 2>/dev/null || echo 'N/A'))"

if [ $CURRENT_TIME -lt $ISSUED_AT ]; then
  echo "    Token not yet valid"
  exit 1
elif [ $CURRENT_TIME -gt $EXPIRY ]; then
  echo "    Token expired"
  exit 1
else
  echo "    Token is valid (within lifetime)"
fi

# Validate issuer
echo ""
echo " Issuer Validation:"
echo "   Expected: ${KEYCLOAK_URL}/realms/${REALM}"
echo "   Actual:   $ISSUER"
if [ "$ISSUER" == "${KEYCLOAK_URL}/realms/${REALM}" ]; then
  echo "    Issuer valid"
else
  echo "    Issuer mismatch"
fi

# Validate WLCG version
echo ""
echo " WLCG Profile Validation:"
echo "   wlcg.ver: $WLCG_VER"
if [ "$WLCG_VER" == "1.2" ]; then
  echo "    WLCG version valid"
else
  echo "     WLCG version missing or invalid"
fi

# Check scopes
echo ""
echo " Scope Authorization:"
echo "   Scopes: $SCOPE"
if echo "$SCOPE" | grep -q "storage.read"; then
  echo "    Has storage.read scope"
else
  echo "    Missing storage.read scope"
fi

# Check groups
echo ""
echo " Group Membership:"
if [ "$WLCG_GROUPS" != "not present" ]; then
  echo "$WLCG_GROUPS" | jq -r '.[]' | while read group; do
    echo "    $group"
  done
else
  echo "     No groups in token"
fi

echo ""
echo "========================================="
echo " Offline validation complete"
echo "========================================="