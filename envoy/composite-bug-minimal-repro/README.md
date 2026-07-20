# Composite Cluster Retry Bug — Minimal Reproduction

**Envoy v1.37.3** does not retry to the next composite sub-cluster when the
first sub-cluster has zero hosts (`no_healthy_upstream`).

## The Bug

When a composite cluster's primary sub-cluster has **no endpoints** (DNS
unresolvable, all hosts removed, etc.), Envoy immediately returns 503
`no healthy upstream` **without attempting a retry** — even with
`retry_on: connect-failure,gateway-error` configured with `num_retries: 1`.

The secondary sub-cluster is healthy and could serve the request, but is
never tried.

## Quick Start

```bash
docker compose up -d
./test.sh
docker compose down
```

## Files

```
docker-compose.yaml  — 2 containers: envoy + secondary echo server
envoy.yaml           — Minimal config reproducing the bug
test.sh              — Automated test showing the failure
```

## Config

```yaml
composite_cluster:
  sub-clusters: [primary_cluster, secondary_cluster]

primary_cluster: STRICT_DNS → "does-not-exist.invalid" (0 hosts)
secondary_cluster: STRICT_DNS → "secondary:8080" (healthy)

retry_policy:
  retry_on: gateway-error,reset,connect-failure,retriable-status-codes
  retriable_status_codes: [503]
  num_retries: 1
```

## Output

```
HTTP 503  (0.001s)
Body: "no healthy upstream"

Retry stats:
  upstream_rq_retry: 0     ← no retry attempted
  secondary never contacted despite being healthy
```

## Root Cause

In `source/common/router/router.cc`, when `chooseHost()` returns nullptr,
the router calls `sendNoHealthyUpstreamResponse()` directly without
consulting `retry_state_`:

```cpp
// ~line 785 (continueDecodeHeaders) and ~line 2420 (continueDoRetry)
HostConstSharedPtr host = cluster->chooseHost(context);
if (host == nullptr) {
  sendNoHealthyUpstreamResponse();  // bypasses retry logic
  return;
}
```

## Why This Matters for Composite Clusters

Composite clusters use retry attempt count to select sub-clusters:

- Attempt 0 → sub-cluster[0] (primary)
- Attempt 1 → sub-cluster[1] (secondary)

If the router retried on `no_healthy_upstream`, the second attempt would
select the secondary sub-cluster and succeed. But since it doesn't retry,
the per-request failover that composite clusters are designed for is broken
when a sub-cluster loses all its endpoints.

## Proposed Fix

Add `no-healthy-upstream` as a new `retry_on` condition. Before calling
`sendNoHealthyUpstreamResponse()`, check if the retry policy allows
retrying on this condition and if retries remain.
