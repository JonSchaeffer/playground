#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Envoy Composite Cluster Retry Bug — Minimal Reproduction               ║
# ║                                                                          ║
# ║  Envoy v1.37.3 does NOT retry to the next composite sub-cluster when     ║
# ║  the first sub-cluster has zero hosts (no_healthy_upstream).             ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

ENVOY="http://localhost:10000"
ADMIN="http://localhost:9901"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
header() {
  echo -e "\n${CYAN}══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

header "COMPOSITE CLUSTER RETRY BUG — MINIMAL REPRO"
echo ""
echo "  Setup:"
echo "    composite_cluster → [primary_cluster, secondary_cluster]"
echo "    primary_cluster:   STRICT_DNS → 'does-not-exist.invalid' (0 hosts)"
echo "    secondary_cluster: STRICT_DNS → 'secondary:8080' (healthy echo)"
echo ""
echo "    retry_policy:"
echo "      retry_on: gateway-error,reset,connect-failure,retriable-status-codes"
echo "      retriable_status_codes: [503]"
echo "      num_retries: 1"
echo ""
echo "  Expected behavior:"
echo "    Attempt 1 → primary_cluster (0 hosts, can't route)"
echo "    Retry     → secondary_cluster (healthy, returns 200)"
echo ""
echo "  Actual behavior:"
echo "    Attempt 1 → primary_cluster (0 hosts)"
echo "    → 503 'no healthy upstream' returned immediately, no retry"

# ─── Start environment ───────────────────────────────────────────────────────
header "STARTING ENVIRONMENT"

docker compose down 2>/dev/null || true
docker compose up -d 2>&1 | grep -v "Creat\|Start\|Network\|Runn" || true

echo -n "  Waiting for secondary_cluster to be healthy..."
for i in $(seq 1 30); do
  OUT=$(curl -s "$ADMIN/clusters" 2>/dev/null || true)
  if echo "$OUT" | grep -q "secondary_cluster.*::healthy"; then
    echo -e " ${GREEN}ready${NC}"
    break
  fi
  [ $i -eq 30 ] && {
    echo " TIMEOUT"
    exit 1
  }
  sleep 1
  echo -n "."
done

# ─── Verify cluster state ───────────────────────────────────────────────────
header "CLUSTER STATE"

echo ""
echo "  primary_cluster:"
P_HOSTS=$(curl -s "$ADMIN/clusters" | grep "primary_cluster.*health_flags" || true)
if [ -z "$P_HOSTS" ]; then
  echo -e "    ${RED}0 hosts (DNS 'does-not-exist.invalid' never resolved)${NC}"
else
  echo "    $P_HOSTS"
fi

echo ""
echo "  secondary_cluster:"
S_HOST=$(curl -s "$ADMIN/clusters" | grep "secondary_cluster.*health_flags" | awk -F'::' '{print $2 " → " $NF}')
echo -e "    ${GREEN}${S_HOST}${NC}"

# ─── Send request ───────────────────────────────────────────────────────────
header "SENDING REQUEST"
echo ""

# Reset stats
curl -s -X POST "$ADMIN/reset_counters" >/dev/null

STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$ENVOY/test")
BODY=$(curl -s "$ENVOY/test")
RESP_TIME=$(curl -s -o /dev/null -w '%{time_total}' "$ENVOY/test")

echo "  $ curl localhost:10000/test"
echo ""
echo "  HTTP ${STATUS}  (${RESP_TIME}s)"
if [ "$STATUS" = "503" ]; then
  echo -e "  Body: ${RED}${BODY}${NC}"
else
  echo "  Body: $(echo "$BODY" | head -c 100)"
fi

echo ""
echo "  Retry stats:"
RETRIES=$(curl -s "$ADMIN/stats" | grep "composite_cluster.upstream_rq_retry:" | awk '{print $2}')
echo "    upstream_rq_retry: ${RETRIES:-0}"
NO_HEALTHY=$(curl -s "$ADMIN/stats" | grep "primary_cluster.upstream_cx_none_healthy:" | awk '{print $2}')
echo "    primary_cluster.upstream_cx_none_healthy: ${NO_HEALTHY:-0}"

# ─── Verdict ─────────────────────────────────────────────────────────────────
header "RESULT"
echo ""

if [ "$STATUS" = "503" ] && [ "${RETRIES:-0}" = "0" ]; then
  echo -e "  ${RED}${BOLD}BUG CONFIRMED${NC}"
  echo ""
  echo "  • HTTP 503 'no healthy upstream' returned to client"
  echo "  • Zero retry attempts (secondary_cluster never tried)"
  echo "  • secondary_cluster is healthy and would have returned 200"
  echo ""
elif [ "$STATUS" = "200" ]; then
  echo -e "  ${GREEN}${BOLD}WORKING — retry succeeded!${NC}"
  echo ""
  echo "  The request was retried from primary_cluster (0 hosts) to"
  echo "  secondary_cluster and got HTTP 200."
fi

echo ""
