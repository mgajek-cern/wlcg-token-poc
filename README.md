# WLCG Token PoC

Trivial Proof of Concept demonstrating WLCG-compliant JWT token issuance using Keycloak.

## What This Demonstrates

- Keycloak configured with WLCG token profile v1.2
- User authentication with WLCG groups (`wlcg.groups`)
- Service account tokens with storage scopes
- Offline token validation
- WLCG-compliant claims: `wlcg.ver`, `scope`, `eduperson_assurance`

## Quick Start

### Prerequisites
- Docker & Docker Compose
- `curl`, `jq`
- macOS/Linux

### Run

```bash
# Start Keycloak
docker compose up -d

# Wait ~30 seconds, then assign users to groups
./scripts/0-assign-groups.sh

# Get user token
./scripts/1-get-user-token.sh

# Decode token
./scripts/3-decode-token.sh

# Validate offline
./scripts/4-validate-token-offline.sh
```

### Expected Output

**Alice's Token:**
```json
{
  "wlcg.ver": "1.2",
  "wlcg.groups": ["/atlas/production", "/atlas/users"],
  "scope": "storage.read storage.create wlcg",
  "eduperson_assurance": ["https://refeds.org/assurance/profile/espresso"]
}
```

## Test Credentials

| User | Password | Groups |
|------|----------|--------|
| `alice` | `alice123` | `/atlas/production`, `/atlas/users` |
| `bob` | `bob123` | `/atlas/users` |

| Service | Secret |
|---------|--------|
| `rucio-service` | `rucio-secret-key-12345` |
| `fts-service` | `fts-secret-key-67890` |

## Key Endpoints

- **Admin Console:** http://localhost:8080 (admin/admin)
- **Token:** `http://localhost:8080/realms/wlcg/protocol/openid-connect/token`
- **JWKS:** `http://localhost:8080/realms/wlcg/protocol/openid-connect/certs`

## Testing Scenarios

```bash
# Service account token
./scripts/2-get-service-token.sh
./scripts/3-decode-token.sh /tmp/service_token.txt

# Token refresh
curl -s -X POST "http://localhost:8080/realms/wlcg/protocol/openid-connect/token" \
  -d "grant_type=refresh_token" \
  -d "client_id=wlcg-cli" \
  -d "refresh_token=$(cat /tmp/refresh_token.txt)" | jq

# Token introspection
curl -s -X POST "http://localhost:8080/realms/wlcg/protocol/openid-connect/token/introspect" \
  -u "rucio-service:rucio-secret-key-12345" \
  -d "token=$(cat /tmp/access_token.txt)" | jq
```

## Cleanup

```bash
docker compose down -v
rm /tmp/*_token.txt
```

## References

- [WLCG Common JWT Profile v1.2](https://github.com/WLCG-AuthZ-WG/common-jwt-profile/blob/master/profile.md)
- [Keycloak Documentation](https://www.keycloak.org/documentation)