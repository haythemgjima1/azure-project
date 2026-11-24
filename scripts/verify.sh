#!/usr/bin/env bash
set -uo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$PROJECT_DIR/terraform"
USER_NAME="azureuser"
FAILED=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED + 1)); }

for tool in terraform az curl jq ssh nc; do
  if ! command -v "$tool" >/dev/null; then
    echo "Missing required command: $tool" >&2
    exit 2
  fi
done

if ! az account show --output none; then
  echo "Run az login and select the correct subscription first." >&2
  exit 2
fi

RG_NAME="$(terraform -chdir="$TF_DIR" output -raw resource_group_name)" || exit 2
WEB_IP="$(terraform -chdir="$TF_DIR" output -raw web_public_ip)" || exit 2
WEB_FQDN="$(terraform -chdir="$TF_DIR" output -raw web_fqdn)" || exit 2
SSH_KEY="$(terraform -chdir="$TF_DIR" output -raw ssh_private_key_path)" || exit 2

if [[ ! -r "$SSH_KEY" ]]; then
  echo "Cannot read SSH private key at $SSH_KEY" >&2
  exit 2
fi

BASE_URL="http://${WEB_FQDN}"
INITIAL="$(curl --connect-timeout 5 --max-time 20 -fsS "$BASE_URL/api/instruments")"
if printf '%s' "$INITIAL" | jq -e 'type == "array" and length == 6' >/dev/null; then
  pass "GET /api/instruments returns six seeded assignments"
else
  fail "GET /api/instruments should return six seeded assignments"
fi

CREATE_BODY='{"course_code":"VERIFY","title":"CRUD verification","description":"Temporary verification record","due_date":"2027-02-01","status":"Not Started"}'
CREATED="$(curl --connect-timeout 5 --max-time 20 -fsS -X POST "$BASE_URL/api/instruments" -H 'Content-Type: application/json' -d "$CREATE_BODY")"
ASSIGNMENT_ID="$(printf '%s' "$CREATED" | jq -r '.id // empty' 2>/dev/null)"
if [[ -n "$ASSIGNMENT_ID" ]]; then
  pass "POST /api/instruments creates a record"

  UPDATE_BODY='{"course_code":"VERIFY","title":"CRUD updated","description":"Updated verification record","due_date":"2027-02-02","status":"In Progress"}'
  UPDATED="$(curl --connect-timeout 5 --max-time 20 -fsS -X PUT "$BASE_URL/api/instruments/$ASSIGNMENT_ID" -H 'Content-Type: application/json' -d "$UPDATE_BODY")"
  if printf '%s' "$UPDATED" | jq -e '.title == "CRUD updated" and .status == "In Progress"' >/dev/null; then
    pass "PUT /api/instruments/{id} updates a record"
  else
    fail "PUT /api/instruments/{id} did not return updated values"
  fi

  if curl --connect-timeout 5 --max-time 20 -fsS -X DELETE "$BASE_URL/api/instruments/$ASSIGNMENT_ID" >/dev/null; then
    pass "DELETE /api/instruments/{id} deletes a record"
  else
    fail "DELETE /api/instruments/{id} failed"
  fi
  if [[ "$(curl --connect-timeout 5 --max-time 20 -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/instruments/$ASSIGNMENT_ID")" == "404" ]]; then
    pass "Deleted assignment is no longer available"
  else
    fail "Deleted assignment should return HTTP 404"
  fi
else
  fail "POST /api/assignments failed to create a record"
fi

PUBLIC_IPS="$(az vm list-ip-addresses --resource-group "$RG_NAME" --query '[].virtualMachine.network.publicIpAddresses[].ipAddress' --output tsv)"
PUBLIC_IP_COUNT="$(printf '%s\n' "$PUBLIC_IPS" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
if [[ "$PUBLIC_IP_COUNT" == "1" && "$PUBLIC_IPS" == "$WEB_IP" ]]; then
  pass "Only vm-web is attached to a VM public IP"
else
  fail "Expected only vm-web public IP ($WEB_IP); found: ${PUBLIC_IPS:-none}"
fi

SSH_OPTIONS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if ssh "${SSH_OPTIONS[@]}" "$USER_NAME@$WEB_FQDN" 'curl -fsS http://10.2.1.4:5000/api/health' >/dev/null; then
  pass "vm-web can reach the app health endpoint"
else
  fail "vm-web could not reach app health endpoint"
fi

if ssh "${SSH_OPTIONS[@]}" "$USER_NAME@$WEB_FQDN" 'command -v nc >/dev/null && ! nc -zv -w 3 10.3.1.4 3306'; then
  pass "vm-web cannot reach MySQL through non-transitive peering"
else
  fail "vm-web unexpectedly reached MySQL or could not run the connectivity check"
fi

if ssh "${SSH_OPTIONS[@]}" -J "$USER_NAME@$WEB_FQDN" "$USER_NAME@10.2.1.4" 'command -v nc >/dev/null && nc -zv -w 3 10.3.1.4 3306'; then
  pass "vm-app can reach MySQL on vm-db"
else
  fail "vm-app could not reach MySQL on vm-db"
fi

if nc -zv -w 3 "$WEB_IP" 5000 >/dev/null 2>&1; then
  fail "App port 5000 is reachable from the administrator's machine"
else
  pass "App port 5000 is blocked from the administrator's machine"
fi

ROUTES="$(az network nic show-effective-route-table --resource-group "$RG_NAME" --name nic-vm-web --output json)"
if printf '%s' "$ROUTES" | jq -e 'any(.. | strings; . == "10.2.0.0/16")' >/dev/null; then
  pass "vm-web effective routes include the app VNet"
else
  fail "vm-web effective routes do not show 10.2.0.0/16"
fi
if printf '%s' "$ROUTES" | jq -e 'any(.. | strings; . == "10.3.0.0/16")' >/dev/null; then
  fail "vm-web effective routes unexpectedly include the DB VNet"
else
  pass "vm-web effective routes do not include the DB VNet"
fi

if (( FAILED > 0 )); then
  printf 'Verification finished with %s failure(s).\n' "$FAILED"
  exit 1
fi
echo "All verification checks passed."
