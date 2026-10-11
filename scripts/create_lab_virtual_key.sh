#!/usr/bin/env bash
# Create a budgeted LiteLLM virtual key against a local proxy.
# Requires: curl, jq, LITELLM_MASTER_KEY, and a running proxy on :4000.
#
# Usage:
#   export LITELLM_MASTER_KEY=sk-lab-...
#   ./scripts/create_lab_virtual_key.sh
#
# Soft budget defaults match .env.example (LAB_VK_MAX_BUDGET / LAB_VK_BUDGET_DURATION).

set -euo pipefail

BASE_URL="${LITELLM_BASE_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:?Set LITELLM_MASTER_KEY}"
MAX_BUDGET="${LAB_VK_MAX_BUDGET:-5.00}"
BUDGET_DURATION="${LAB_VK_BUDGET_DURATION:-30d}"
KEY_ALIAS="${LAB_VK_ALIAS:-lab-dev}"

echo "Creating virtual key alias=${KEY_ALIAS} max_budget=${MAX_BUDGET} duration=${BUDGET_DURATION}"

RESP=$(curl -sS -X POST "${BASE_URL}/key/generate" \
  -H "Authorization: Bearer ${MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"key_alias\": \"${KEY_ALIAS}\",
    \"max_budget\": ${MAX_BUDGET},
    \"budget_duration\": \"${BUDGET_DURATION}\",
    \"models\": [\"gpt-4o-mini\", \"gpt-4o\"],
    \"metadata\": {\"purpose\": \"litellm-mcp-lab\"}
  }")

echo "${RESP}" | jq .
echo
echo "Use the returned 'key' as Authorization: Bearer <key> for client calls."
echo "Do not commit the key. Rotate or delete via /key/delete when done."
