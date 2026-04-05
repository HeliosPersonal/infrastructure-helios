# Redis

Single shared **Redis 8** instance in `infra-production`. All apps use **key prefixes** for isolation.

```
apps-staging     → redis.infra-production:6379  (prefix: staging:<app>:)
apps-production  → redis.infra-production:6379  (prefix: production:<app>:)
```

## Connection

| | |
|---|---|
| Host | `redis.infra-production.svc.cluster.local` |
| Port | `6379` |
| DB | `0` (always — use key prefixes, not DB numbers) |
| Auth | Password from `terraform.secret.tfvars → redis_password` |
| Redis Insight | `https://redisinsight.devoverflow.org` |

---

## Key Naming Convention

```
<environment>:<app>:<purpose>:<optional-id>
```

| Good | Bad |
|------|-----|
| `staging:overflow:session:abc123` | `session:abc123` |
| `production:overflow:cache:user:42` | `user_cache_42` |
| `staging:overflow:lock:job:export` | `lock:export` |

**Rules:**
- Always start with `$REDIS_KEY_PREFIX` — never hardcode `staging:` in code
- Use `:` as separator
- Keep IDs at the end so prefix scans work
- Never use `KEYS *` — always use `SCAN`

---

## App Environment Variables

| Variable | Example | Source |
|----------|---------|--------|
| `REDIS_HOST` | `redis.infra-production.svc.cluster.local` | ConfigMap |
| `REDIS_PORT` | `6379` | ConfigMap |
| `REDIS_PASSWORD` | `<secret>` | Kubernetes Secret |
| `REDIS_KEY_PREFIX` | `staging:myapp:` | ConfigMap |

---

## TTL Reference

| Use case | TTL | Strategy |
|----------|-----|---------|
| Session | 1–24 h | Sliding (reset on access) |
| Response cache | 5–60 min | Fixed |
| Distributed lock | 10–60 s | Fixed |
| Rate limit | Match window | Fixed |
| OTP / verification | 5–15 min | Fixed |
| Idempotency key | 24 h | Fixed |

> Always set a TTL. Never store keys without expiry.

---

## Code Examples

### C# — StackExchange.Redis

```csharp
// Program.cs
var configOptions = new ConfigurationOptions
{
    EndPoints = { $"{config["REDIS_HOST"]}:{config["REDIS_PORT"]}" },
    Password  = config["REDIS_PASSWORD"],
};
builder.Services.AddSingleton<IConnectionMultiplexer>(ConnectionMultiplexer.Connect(configOptions));
builder.Services.AddSingleton(new RedisKeyPrefix(config["REDIS_KEY_PREFIX"] ?? "dev:myapp:"));

// Key prefix helper
public sealed class RedisKeyPrefix(string prefix)
{
    public string Of(string key) => $"{prefix}{key}";
}

// Usage
await _db.StringSetAsync(prefix.Of($"session:{id}"), json, TimeSpan.FromHours(1));
var value = await _db.StringGetAsync(prefix.Of($"session:{id}"));
```

IDistributedCache:
```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.ConfigurationOptions = configOptions;
    options.InstanceName = keyPrefix;   // prepended automatically
});
```

### Node.js — ioredis

```typescript
import Redis from 'ioredis';

export const redis = new Redis({
  host:      process.env.REDIS_HOST     ?? 'localhost',
  port:      Number(process.env.REDIS_PORT ?? 6379),
  password:  process.env.REDIS_PASSWORD,
  keyPrefix: process.env.REDIS_KEY_PREFIX ?? 'dev:myapp:',  // prepended automatically
  lazyConnect: true,
});
```

### Python — redis-py

```python
import redis, os

KEY_PREFIX = os.getenv("REDIS_KEY_PREFIX", "dev:myapp:")
_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    password=os.getenv("REDIS_PASSWORD"),
    decode_responses=True,
)
def key(name: str) -> str:
    return f"{KEY_PREFIX}{name}"
```

---

## Common Patterns

### Distributed Lock

```csharp
var lockKey   = prefix.Of("lock:invoice:export");
var lockToken = Guid.NewGuid().ToString();

bool acquired = await _db.StringSetAsync(lockKey, lockToken, TimeSpan.FromSeconds(30), When.NotExists);
if (!acquired) throw new InvalidOperationException("Resource is locked");

try { /* exclusive work */ }
finally
{
    const string lua = """
        if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) end
        return 0
        """;
    await _db.ScriptEvaluateAsync(lua, new RedisKey[] { lockKey }, new RedisValue[] { lockToken });
}
```

### Rate Limiting

```csharp
var count = await _db.StringIncrementAsync(prefix.Of($"ratelimit:{clientIp}"));
if (count == 1) await _db.KeyExpireAsync(prefix.Of($"ratelimit:{clientIp}"), TimeSpan.FromMinutes(1));
if (count > 100) return Results.StatusCode(429);
```

### Pub/Sub

```csharp
// Publisher
await _redis.GetSubscriber().PublishAsync(
    RedisChannel.Literal(prefix.Of("events:order-created")), JsonSerializer.Serialize(orderEvent));
```

> Pub/Sub is fire-and-forget. For durable messaging use **RabbitMQ**.

---

## Clearing Staging Data

Never `FLUSHALL` / `FLUSHDB` — that wipes all apps.

```bash
kubectl port-forward -n infra-production svc/redis 6379:6379
redis-cli -a <password> --scan --pattern "staging:myapp:*" \
  | xargs --no-run-if-empty redis-cli -a <password> DEL
```

---

## Observability

- Metrics: `redis-exporter` sidecar on port `9121`, scraped by Alloy every 60 s
- Grafana dashboard: import **[ID 11835](https://grafana.com/grafana/dashboards/11835)**, filter `job=redis`

Key PromQL:
```promql
# Hit rate %
rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m])) * 100

# Evictions (should be 0)
rate(redis_evicted_keys_total[5m])

# Memory MB
redis_used_memory_bytes / 1024 / 1024
```

---

## Helm Details

| | |
|---|---|
| Chart | `cloudpirates/redis` `0.26.8` |
| Namespace | `infra-production` |
| Persistence | AOF + RDB, PVC size: `redis_storage_size` (default `4Gi`) |
| Metrics | `redis-exporter` sidecar `:9121` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `WRONGPASS` | Check `redis_password` in `terraform.secret.tfvars` matches pod secret |
| `Connection refused` | `kubectl get pods -n infra-production -l app.kubernetes.io/name=redis` |
| Keys from other app visible | Enforce `REDIS_KEY_PREFIX` in all key construction |
| High memory / evictions | Audit keys without TTL: `redis-cli --scan \| xargs -L1 redis-cli TTL` |
| `KEYS` command slow | Replace all `KEYS` with `SCAN` |
| PVC pending | `kubectl get storageclass` — K3s default is `local-path` |
