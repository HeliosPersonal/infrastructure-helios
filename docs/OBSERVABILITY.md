# Observability

Grafana Alloy in the `monitoring` namespace is the single collection point. It both receives OTLP pushes from apps and scrapes Prometheus endpoints from the cluster.

## Architecture

```
ASP.NET Core  ──OTLP──►
Next.js       ──OTLP──►  Grafana Alloy  ──►  Grafana Cloud
(stdout logs) ──K8s API►              (Prometheus / Tempo / Loki)
```

## Signal Routing

| Signal | Source | Method | Destination |
|--------|--------|--------|-------------|
| App metrics | OTLP exporter | Push | Alloy → Prometheus remote_write |
| Infra metrics | cAdvisor, kube-state-metrics, node-exporter, nginx, Redis | Pull (scrape) | Alloy → Prometheus remote_write |
| Traces | OTLP exporter | Push | Alloy → Tempo |
| ASP.NET logs | OpenTelemetry log exporter | Push (OTLP) | Alloy → Loki |
| Next.js logs | stdout | Pod log tail (K8s API) | Alloy → Loki |

> Do not enable pod log tailing for .NET services — it creates duplicate Loki entries.

## OTLP Endpoints

| Protocol | Address |
|----------|---------|
| gRPC | `grafana-alloy.monitoring.svc.cluster.local:4317` |
| HTTP | `http://grafana-alloy.monitoring.svc.cluster.local:4318` |

Also available via `terraform output otlp_grpc_endpoint` / `terraform output otlp_http_endpoint`.

---

## Alloy Config

Lives in `terraform/values/alloy-values.yaml` → `alloy.configMap.content`. Apply terraform after changes — no manual pod restart needed.

### Filter Metrics (drop by name)

```alloy
prometheus.scrape "example" {
  targets    = discovery.relabel.example.output
  forward_to = [prometheus.remote_write.grafanacloud.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "go_gc_.*"   # prefix match
    action        = "drop"
  }
}
```

### Filter Traces (drop health checks)

Add before the OTLP exporter:
```alloy
otelcol.processor.filter "drop_health" {
  error_mode = "ignore"
  traces {
    span = [
      "attributes[\"http.target\"] == \"/health\"",
      "attributes[\"http.target\"] == \"/ready\"",
    ]
  }
  output { traces = [otelcol.exporter.otlp.tempo.input] }
}
```
Then update `otelcol.processor.batch.default` output: `traces = [otelcol.processor.filter.drop_health.input]`

### Filter Logs (OTLP — errors only)

```alloy
otelcol.processor.filter "logs_errors_only" {
  error_mode = "ignore"
  logs {
    log_record = ["severity_number < SEVERITY_NUMBER_ERROR"]
  }
  output { logs = [otelcol.exporter.loki.grafanacloud.input] }
}
```

### Add Scrape Target

```alloy
discovery.relabel "my_service" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    regex         = "infra-production"
    action        = "keep"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
    regex         = "my-service"
    action        = "keep"
  }
  # Override port if needed
  rule {
    source_labels = ["__address__"]
    regex         = "([^:]+)(?::\\d+)?"
    replacement   = "$1:9090"
    target_label  = "__address__"
  }
}

prometheus.scrape "my_service" {
  targets         = discovery.relabel.my_service.output
  job_name        = "my-service"
  scrape_interval = "1m"
  forward_to      = [prometheus.remote_write.grafanacloud.receiver]
}
```

### Add Pod Log Tailing (Next.js / stdout-only services)

In the `discovery.relabel "pod_logs"` block, extend the allowlist:
```alloy
rule {
  source_labels = ["__meta_kubernetes_pod_label_app"]
  regex         = "overflow-webapp|my-nextjs-app"   # add with |
  action        = "keep"
}
```

---

## Instrumenting ASP.NET Core

### 1. NuGet Packages

```xml
<PackageReference Include="OpenTelemetry.Extensions.Hosting"              Version="1.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore"      Version="1.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http"            Version="1.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Runtime"         Version="1.*" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol"  Version="1.*" />
<!-- optional: <PackageReference Include="OpenTelemetry.Instrumentation.EntityFrameworkCore" Version="1.*" /> -->
```

### 2. Program.cs

```csharp
builder.Services
    .AddOpenTelemetry()
    .ConfigureResource(r => r.AddService(
        serviceName:       builder.Environment.ApplicationName,
        serviceVersion:    "1.0.0",
        serviceInstanceId: Environment.MachineName))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation(o =>
        {
            o.Filter = ctx => ctx.Request.Path != "/health" && ctx.Request.Path != "/ready";
        })
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter())
    .WithLogging(l => l.AddOtlpExporter());
```

### 3. Environment Variables

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://grafana-alloy.monitoring.svc.cluster.local:4318"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_SERVICE_NAME
    value: "my-service-name"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=$(ASPNETCORE_ENVIRONMENT)"
```

---

## Instrumenting Next.js

### 1. Packages

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/exporter-trace-otlp-http \
  @opentelemetry/exporter-metrics-otlp-http \
  @opentelemetry/sdk-metrics \
  @opentelemetry/auto-instrumentations-node
```

### 2. instrumentation.ts

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http'
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { Resource } from '@opentelemetry/resources'
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } from '@opentelemetry/semantic-conventions'

const otlpBaseUrl = process.env.OTEL_EXPORTER_OTLP_ENDPOINT
  ?? 'http://grafana-alloy.monitoring.svc.cluster.local:4318'

export function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    new NodeSDK({
      resource: new Resource({
        [SEMRESATTRS_SERVICE_NAME]:    process.env.OTEL_SERVICE_NAME ?? 'overflow-webapp',
        [SEMRESATTRS_SERVICE_VERSION]: process.env.npm_package_version ?? '0.0.0',
      }),
      traceExporter: new OTLPTraceExporter({ url: `${otlpBaseUrl}/v1/traces` }),
      metricReader: new PeriodicExportingMetricReader({
        exporter: new OTLPMetricExporter({ url: `${otlpBaseUrl}/v1/metrics` }),
        exportIntervalMillis: 60_000,
      }),
      instrumentations: [getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
      })],
    }).start()
  }
}
```

### 3. next.config.ts

```typescript
const nextConfig: NextConfig = {
  experimental: { instrumentationHook: true },  // not needed in Next.js 15+
}
```

### 4. Environment Variables

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://grafana-alloy.monitoring.svc.cluster.local:4318"
  - name: OTEL_SERVICE_NAME
    value: "overflow-webapp"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=production"
```

### Logs (stdout → Loki)

Alloy tails pod logs and extracts a `level` label:

| Keyword in log line | `level` label |
|---------------------|---------------|
| *(default)* | `info` |
| `warn` | `warn` |
| `error`, `failed`, `exception` | `error` |

Query: `{app="overflow-webapp", namespace="apps-production", level="error"}`
