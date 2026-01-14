#!/bin/bash

TOKEN_FILE=${1:-/tmp/access_token.txt}

if [ ! -f "$TOKEN_FILE" ]; then
  echo " Token file not found: $TOKEN_FILE"
  exit 1
fi

TOKEN=$(cat $TOKEN_FILE)

echo "========================================="
echo "Decoding JWT Token"
echo "========================================="

# Extract parts
HEADER_B64=$(echo $TOKEN | cut -d. -f1)
PAYLOAD_B64=$(echo $TOKEN | cut -d. -f2)

# Add padding and decode
decode_part() {
  local input="$1"
  local len=$((${#input} % 4))
  if [ $len -eq 2 ]; then input="${input}=="; fi
  if [ $len -eq 3 ]; then input="${input}="; fi
  echo "$input" | tr '_-' '/+' | base64 -d 2>/dev/null || echo "$input" | tr '_-' '/+' | base64 -D 2>/dev/null
}

HEADER=$(decode_part "$HEADER_B64")
PAYLOAD=$(decode_part "$PAYLOAD_B64")

echo ""
echo " HEADER:"
echo "$HEADER" | jq '.'

echo ""
echo " PAYLOAD:"
echo "$PAYLOAD" | jq '.'

echo ""
echo "========================================="
echo "WLCG-Specific Claims:"
echo "========================================="
echo "wlcg.ver:            $(echo "$PAYLOAD" | jq -r '.wlcg.ver // "not present"')"
echo "wlcg.groups:         $(echo "$PAYLOAD" | jq -r '.wlcg.groups // "not present"')"
echo "scope:               $(echo "$PAYLOAD" | jq -r '.scope // "not present"')"
echo "eduperson_assurance: $(echo "$PAYLOAD" | jq -r '.eduperson_assurance // "not present"')"
echo ""
echo "Standard Claims:"
echo "sub:                 $(echo "$PAYLOAD" | jq -r '.sub')"
echo "iss:                 $(echo "$PAYLOAD" | jq -r '.iss')"