# Redis — Integration Guide

## Overview

A single shared **Redis 8** instance runs in the `infra-production` namespace using the [CloudPirates Redis Helm chart](https://hub.docker.com/r/cloudpirates/redis).

All applications (staging and production) connect to the **same Redis instance** and use **key prefixes** for isolation, matching the multi-tenant philosophy of this infrastructure.

```
apps-staging     → redis.infra-production:6379  (prefix: staging:<app>:)
apps-production  → redis.infra-production:6379  (prefix: production:<app>:)
```

---

## Connection Reference

| Parameter | Value |
|-----------|-------|
| **Host** | `redis.infra-production.svc.cluster.local` |
| **Port** | `6379` |
| **Database** | `0` (always — use key prefixes, not DB numbers) |
| **Auth** | Password — read from Kubernetes Secret (see below) |
| **TLS** | Not enabled (cluster-internal traffic only) |

---

## Redis Insight

**Redis Insight** is a browser-based GUI deployed alongside Redis in the `infra-production` namespace. It lets you browse keys, run commands, monitor memory usage, and manage streams/pub-sub.

| | |
|---|---|
| **URL** | `https://redisinsight.<base_domain>` (see `redis_insight_url` Terraform output) |
| **Terraform output** | `redis_insight_url` |
| **Enable/disable** | `redis_insight_enabled = true` (default) in `terraform.tfvars` |

### First-time connection setup

When you open Redis Insight for the first time you need to add the Redis connection manually:

1. Click **"Add Redis Database"**
2. Fill in:
   - **Host**: `redis.infra-production.svc.cluster.local`
   - **Port**: `6379`
   - **Password**: value of `redis_password` from `terraform.secret.tfvars`
   - **Name**: `infra-production` (or any label you like)
3. Click **"Test Connection"**, then **"Add Redis Database"**

> Connection details are persisted in a `256Mi` PVC (`redis-insight-data`) so they survive pod restarts.

---

## Environment Variable Contract

Every application that uses Redis **must** accept these environment variables:

| Variable | Example value | Source |
|----------|--------------|--------|
| `REDIS_HOST` | `redis.infra-production.svc.cluster.local` | ConfigMap |
| `REDIS_PORT` | `6379` | ConfigMap |
| `REDIS_PASSWORD` | `<secret>` | Kubernetes Secret |
| `REDIS_KEY_PREFIX` | `staging:myapp:` | ConfigMap |

> `REDIS_KEY_PREFIX` encodes **both** the environment and the app name. Your app must prepend this to **every** key it writes or reads.

---

## Key Naming Convention

```
<environment>:<app>:<purpose>:<optional-id>
```

| Good ✅ | Bad ❌ |
|---------|--------|
| `staging:overflow:session:abc123` | `session:abc123` |
| `production:overflow:cache:user:42` | `user_cache_42` |
| `staging:overflow:lock:job:export` | `lock:export` |
| `production:overflow:ratelimit:192.0.2.1` | `ratelimit:ip` |

**Rules:**
- Always start with `$REDIS_KEY_PREFIX` (never hardcode `staging:` or `production:` in code)
- Use `:` as separator (Redis convention)
- Keep IDs at the end so prefix scans work: `SCAN 0 MATCH staging:overflow:session:*`
- Never use `KEYS *` in production — always use `SCAN` instead

---

## Terraform: Wiring Up Your Project

### 1. Read infrastructure outputs (`data.tf`)

```hcl
data "terraform_remote_state" "infra" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-helios-tfstate"
    storage_account_name = "stheliosinfrastate"
    container_name       = "tfstate"
    key                  = "infrastructure-helios.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  redis_host = data.terraform_remote_state.infra.outputs.redis_host
  redis_port = data.terraform_remote_state.infra.outputs.redis_port
}
```

### 2. Create a Kubernetes Secret (per namespace)

```hcl
resource "kubernetes_secret" "redis" {
  metadata {
    name      = "redis-credentials"
    namespace = local.namespace_apps_staging   # repeat for production namespace
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }
}
```

> `var.redis_password` must be passed into your project's Terraform from your own `terraform.secret.tfvars`.
> It is **not** exposed as a Terraform output — only non-sensitive connection details are.

### 3. Create a ConfigMap

```hcl
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "myapp-config"
    namespace = local.namespace_apps_staging
  }

  data = {
    REDIS_HOST       = local.redis_host
    REDIS_PORT       = tostring(local.redis_port)
    REDIS_KEY_PREFIX = "staging:myapp:"
  }
}
```

---

## Kubernetes: Mounting into a Deployment

```yaml
spec:
  containers:
    - name: myapp
      image: myapp:latest
      env:
        # Non-sensitive config from ConfigMap
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: REDIS_HOST
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: REDIS_PORT
        - name: REDIS_KEY_PREFIX
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: REDIS_KEY_PREFIX
        # Password from Secret
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: REDIS_PASSWORD
```

---

## Code Examples

### C# / .NET — StackExchange.Redis

**Registration (`Program.cs`)**
```csharp
var redisHost     = builder.Configuration["REDIS_HOST"] ?? "localhost";
var redisPort     = builder.Configuration["REDIS_PORT"] ?? "6379";
var redisPassword = builder.Configuration["REDIS_PASSWORD"];
var keyPrefix     = builder.Configuration["REDIS_KEY_PREFIX"] ?? "dev:myapp:";

var configOptions = new ConfigurationOptions
{
    EndPoints          = { $"{redisHost}:{redisPort}" },
    Password           = redisPassword,
    AbortOnConnectFail = false,
};

builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(configOptions));

// Register a typed prefix helper — services never construct raw keys
builder.Services.AddSingleton(new RedisKeyPrefix(keyPrefix));
```

**Key prefix helper**
```csharp
public sealed class RedisKeyPrefix(string prefix)
{
    public string Of(string key) => $"{prefix}{key}";
}
```

**Usage in a service**
```csharp
public class SessionService(IConnectionMultiplexer redis, RedisKeyPrefix prefix)
{
    private readonly IDatabase _db = redis.GetDatabase();

    public async Task SetAsync(string sessionId, string value, TimeSpan ttl)
        => await _db.StringSetAsync(prefix.Of($"session:{sessionId}"), value, ttl);

    public async Task<string?> GetAsync(string sessionId)
        => await _db.StringGetAsync(prefix.Of($"session:{sessionId}"));

    public async Task DeleteAsync(string sessionId)
        => await _db.KeyDeleteAsync(prefix.Of($"session:{sessionId}"));
}
```

**`IDistributedCache` (ASP.NET Core)**
```csharp
// Install: dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.ConfigurationOptions = configOptions;
    options.InstanceName = keyPrefix;   // prepended to all IDistributedCache keys automatically
});
```

---

### Node.js — ioredis

```typescript
import Redis from 'ioredis'; // npm install ioredis

const KEY_PREFIX = process.env.REDIS_KEY_PREFIX ?? 'dev:myapp:';

export const redis = new Redis({
  host:      process.env.REDIS_HOST     ?? 'localhost',
  port:      Number(process.env.REDIS_PORT ?? 6379),
  password:  process.env.REDIS_PASSWORD,
  keyPrefix: KEY_PREFIX,   // ioredis prepends this to every command automatically
  lazyConnect: true,
});

// Usage — keys are automatically prefixed by ioredis
await redis.set('session:abc123', JSON.stringify(payload), 'EX', 3600);
const value = await redis.get('session:abc123');
await redis.del('session:abc123');
```

---

### Python — redis-py

```python
import os
import redis  # pip install redis

KEY_PREFIX = os.getenv("REDIS_KEY_PREFIX", "dev:myapp:")

_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    password=os.getenv("REDIS_PASSWORD"),
    decode_responses=True,
)

def key(name: str) -> str:
    """Always use this to construct keys — never hardcode prefixes."""
    return f"{KEY_PREFIX}{name}"

# Usage
_client.setex(key("session:abc123"), 3600, "value")
value = _client.get(key("session:abc123"))
_client.delete(key("session:abc123"))
```

---

## Use Cases & Patterns

### Session Storage

```
Key:   <prefix>session:<session-id>
Type:  String (JSON)
TTL:   sliding — reset on each access (e.g. 1–24 h)
```

```csharp
// Set
await _db.StringSetAsync(prefix.Of($"session:{id}"), json, TimeSpan.FromHours(1));

// Get + refresh TTL (sliding)
var value = await _db.StringGetAsync(prefix.Of($"session:{id}"));
if (!value.IsNull)
    await _db.KeyExpireAsync(prefix.Of($"session:{id}"), TimeSpan.FromHours(1));
```

---

### Response / Object Caching

```
Key:   <prefix>cache:<entity>:<id>
Type:  String (JSON)
TTL:   fixed (e.g. 5–60 min)
```

```csharp
var cacheKey = prefix.Of($"cache:user:{userId}");
var cached   = await _db.StringGetAsync(cacheKey);

if (cached.IsNull)
{
    var user = await _userRepo.GetByIdAsync(userId);
    await _db.StringSetAsync(cacheKey, JsonSerializer.Serialize(user), TimeSpan.FromMinutes(15));
    return user;
}

return JsonSerializer.Deserialize<User>(cached!);
```

---

### Distributed Lock

```
Key:   <prefix>lock:<resource>
Type:  String (random token)
TTL:   short (e.g. 10–60 s) — auto-releases if holder crashes
```

```csharp
var lockKey   = prefix.Of("lock:invoice:export");
var lockToken = Guid.NewGuid().ToString();

bool acquired = await _db.StringSetAsync(
    lockKey, lockToken, TimeSpan.FromSeconds(30), When.NotExists);

if (!acquired)
    throw new InvalidOperationException("Resource is locked by another instance");

try
{
    // do exclusive work
}
finally
{
    // Lua script ensures we only delete if we still own the lock
    const string lua = """
        if redis.call('get', KEYS[1]) == ARGV[1] then
            return redis.call('del', KEYS[1])
        end
        return 0
        """;
    await _db.ScriptEvaluateAsync(lua,
        new RedisKey[]   { lockKey },
        new RedisValue[] { lockToken });
}
```

---

### Rate Limiting (sliding counter)

```
Key:   <prefix>ratelimit:<client-id>
Type:  String (counter)
TTL:   window duration (set on first increment)
```

```csharp
var limitKey = prefix.Of($"ratelimit:{clientIp}");
var count    = await _db.StringIncrementAsync(limitKey);

if (count == 1)
    await _db.KeyExpireAsync(limitKey, TimeSpan.FromMinutes(1)); // TTL set on first hit

if (count > 100)
    return Results.StatusCode(429);
```

---

### Pub/Sub (lightweight in-process events)

```
Channel: <prefix>events:<topic>
```

```csharp
// Publisher
var pub = _redis.GetSubscriber();
await pub.PublishAsync(
    RedisChannel.Literal(prefix.Of("events:order-created")),
    JsonSerializer.Serialize(orderEvent));

// Subscriber (long-lived — use a dedicated IConnectionMultiplexer)
var sub = _redis.GetSubscriber();
await sub.SubscribeAsync(
    RedisChannel.Literal(prefix.Of("events:order-created")),
    (_, message) => HandleOrderCreated(message));
```

> ⚠️ Redis Pub/Sub is **fire-and-forget** — messages are dropped if no subscriber is connected at publish time. For durable, reliable messaging use **RabbitMQ** instead.

---

## TTL Reference

| Use case | Recommended TTL | Strategy |
|----------|----------------|---------|
| Session | 1–24 h | Sliding — reset on each access |
| Response cache | 5–60 min | Fixed |
| Distributed lock | 10–60 s | Fixed — safety release on crash |
| Rate limit window | Match window (e.g. 1 min) | Fixed |
| OTP / verification code | 5–15 min | Fixed |
| Idempotency key | 24 h | Fixed |
| Job deduplication | 1–7 days | Fixed |

> **Always set a TTL.** Never store keys without expiry unless you have an explicit eviction policy (`maxmemory-policy`).

---

## Clearing Staging Data

To flush **only your app's keys** during a staging reset — never use `FLUSHALL` or `FLUSHDB` (they wipe every app's data):

```bash
# 1. Port-forward
kubectl port-forward -n infra-production svc/redis 6379:6379

# 2. Delete only your prefix (scan-based, non-blocking)
redis-cli -a <password> --scan --pattern "staging:myapp:*" \
  | xargs --no-run-if-empty redis-cli -a <password> DEL
```

---

## Observability

### How it works

The CloudPirates chart deploys a **`redis-exporter` sidecar** in the Redis pod when `metrics.enabled = true`. It exposes Prometheus metrics on port `9121` at `/metrics`.

**Grafana Alloy** scrapes this endpoint every 60 s and forwards the metrics to **Grafana Cloud Prometheus**.

```
redis pod
  ├─ redis-server   :6379  (data)
  └─ redis-exporter :9121  (metrics) ← Alloy scrapes this
                                           ↓
                                    Grafana Cloud
                                    (Prometheus + dashboards)
```

---

### Grafana Dashboard

Import **[Dashboard ID 11835](https://grafana.com/grafana/dashboards/11835)** — *"Redis Exporter 1.x"* — into your Grafana Cloud instance.

> Grafana Cloud: **Dashboards → Import → ID `11835`**

After import, filter by `job = redis` to scope it to this cluster.

---

### Key Metrics

| Metric | What it tells you |
|--------|------------------|
| `redis_up` | `1` = healthy, `0` = down — use for alerting |
| `redis_connected_clients` | Active client connections |
| `redis_used_memory_bytes` | Current memory consumption |
| `redis_used_memory_peak_bytes` | All-time peak memory |
| `redis_mem_fragmentation_ratio` | > 1.5 indicates fragmentation; > 2 is concerning |
| `redis_total_commands_processed_total` | Total commands — rate shows throughput |
| `redis_keyspace_hits_total` | Cache hits |
| `redis_keyspace_misses_total` | Cache misses |
| `redis_expired_keys_total` | Keys expired by TTL (expected; normal churn) |
| `redis_evicted_keys_total` | Keys evicted due to `maxmemory` — **should be 0** |
| `redis_db_keys{db="db0"}` | Total keys in the database |
| `redis_rdb_last_save_timestamp_seconds` | Unix timestamp of last successful RDB snapshot |
| `redis_aof_enabled` | `1` = AOF persistence is active |
| `redis_blocked_clients` | Clients blocked on `BLPOP`/`BRPOP` etc. |
| `redis_instantaneous_ops_per_sec` | Real-time ops/sec |

---

### Cache Hit Rate

The most important business metric for a cache. Calculate it in Grafana:

```promql
# Hit rate % — should be high (> 80%) for a healthy cache
rate(redis_keyspace_hits_total[5m])
/
(rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
* 100
```

---

### Useful PromQL Queries

```promql
# Memory usage in MB
redis_used_memory_bytes / 1024 / 1024

# Memory usage as % of peak
redis_used_memory_bytes / redis_used_memory_peak_bytes * 100

# Command throughput (ops/sec over last 5 min)
rate(redis_total_commands_processed_total[5m])

# Key expiry rate (keys/sec)
rate(redis_expired_keys_total[5m])

# Eviction rate — alert if > 0 sustained
rate(redis_evicted_keys_total[5m])

# Connection rate
rate(redis_total_connections_received_total[5m])

# Total keys per prefix (approximate — from your app's perspective, not Redis)
redis_db_keys{db="db0"}
```

---

### Recommended Alerts

Add these in Grafana Cloud → Alerting:

| Alert | Condition | Severity |
|-------|-----------|---------|
| Redis down | `redis_up == 0` for 1 min | Critical |
| High memory | `redis_used_memory_bytes / redis_used_memory_peak_bytes > 0.9` | Warning |
| Evictions occurring | `rate(redis_evicted_keys_total[5m]) > 0` for 5 min | Warning |
| Low cache hit rate | Hit rate < 50% sustained for 15 min | Info |
| High connection count | `redis_connected_clients > 200` | Warning |

---

### What You'll See in Grafana (Dashboard 11835)

After importing the dashboard, you get panels for:

- **Uptime & version** — instance health at a glance
- **Connected clients** — connection pool usage
- **Memory used / peak / fragmentation** — memory health
- **Commands per second** — throughput over time
- **Hit rate %** — cache effectiveness
- **Expired vs evicted keys** — TTL behaviour and memory pressure
- **Network I/O** — bytes in/out per second
- **Keys per DB** — total key count over time
- **RDB last save** — persistence health

---

```bash
# Port-forward Redis
kubectl port-forward -n infra-production svc/redis 6379:6379

# Interactive CLI
redis-cli -h 127.0.0.1 -p 6379 -a <password>

# Health check
redis-cli -h 127.0.0.1 -p 6379 -a <password> PING

# Memory usage
redis-cli -h 127.0.0.1 -p 6379 -a <password> INFO memory

# Scan keys by prefix (production-safe — use instead of KEYS)
redis-cli -h 127.0.0.1 -p 6379 -a <password> --scan --pattern "staging:myapp:*"

# Check key TTL
redis-cli -h 127.0.0.1 -p 6379 -a <password> TTL "staging:myapp:session:abc123"

# Live command monitor (dev only — high CPU overhead)
redis-cli -h 127.0.0.1 -p 6379 -a <password> MONITOR

# Pod status
kubectl get pods -n infra-production -l app.kubernetes.io/name=redis

# Pod logs
kubectl logs -n infra-production -l app.kubernetes.io/name=redis

# Metrics endpoint (redis-exporter sidecar)
kubectl port-forward -n infra-production svc/redis-metrics 9121:9121
curl http://localhost:9121/metrics
```

---

## Helm / Infrastructure Details

| Property | Value |
|----------|-------|
| Chart | `cloudpirates/redis` |
| Source | `oci://registry-1.docker.io/cloudpirates` |
| Version | `0.26.4` |
| Architecture | `standalone` — single master, no replica |
| Namespace | `infra-production` |
| Service | `redis` |
| Port | `6379` |
| Metrics | `redis-exporter` sidecar on port `9121` |
| Persistence | AOF + RDB snapshots, PVC size via `redis_storage_size` (default `4Gi`) |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `WRONGPASS` | Password mismatch | Verify `redis_password` in `terraform.secret.tfvars` matches the secret mounted in your pod |
| `Connection refused` | Pod not running | `kubectl get pods -n infra-production -l app.kubernetes.io/name=redis` |
| Keys from other app visible | Missing prefix | Enforce `REDIS_KEY_PREFIX` in all key construction — never write bare keys |
| High memory / evictions | Keys without TTL | Audit: `redis-cli --scan \| xargs -L1 redis-cli TTL` and fix any returning `-1` |
| `KEYS` command slow / blocking | `KEYS *` in application code | Replace all `KEYS` calls with `SCAN` + pattern |
| Staging data leaking into production | Wrong prefix in config | Assert at app startup that `REDIS_KEY_PREFIX` starts with the expected environment |
| PVC pending | Storage class unavailable | `kubectl get storageclass` — K3s default is `local-path` |
