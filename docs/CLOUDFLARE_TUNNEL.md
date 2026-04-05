# Cloudflare Tunnel

Outbound-only tunnel — no open inbound firewall rules needed.

```
Browser → Cloudflare Edge (TLS termination) → cloudflared pod (outbound) → NGINX ingress → services
```

---

## Setup Steps

### 1. Create Tunnel

1. Open [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → **Networks → Tunnels → Create a tunnel**
2. Choose **Cloudflared** → name it `helios-k3s` → Save
3. Switch to the **Docker** tab, copy the token after `--token`
4. Click **Next** (hostname configured in step 2)

### 2. Add Public Hostname

In the tunnel wizard or **Networks → Tunnels → helios-k3s → Public Hostname → Add**:

| Field | Value |
|-------|-------|
| Subdomain | `*` |
| Domain | `devoverflow.org` |
| Type | HTTP |
| URL | `ingress-nginx-controller.ingress.svc.cluster.local:80` |

Cloudflare auto-creates: `*.devoverflow.org CNAME <tunnel-id>.cfargotunnel.com`

> Wildcard hostnames require **Cloudflare Pro+**. On Free, add each subdomain individually.

### 3. Deploy via Terraform

```hcl
# terraform.secret.tfvars
cloudflare_tunnel_token = "eyJhIjoiABC..."
cloudflared_enabled     = true
```

```bash
cd terraform
terraform apply -var-file="terraform.secret.tfvars"
```

Creates in namespace `ingress`: `Secret/cloudflared-tunnel-token`, `ConfigMap/cloudflared-config`, `Deployment/cloudflared` (2 replicas).

### 4. Verify

```bash
kubectl -n ingress get pods -l app=cloudflared

kubectl -n ingress logs -l app=cloudflared --tail=40
# look for: "Registered tunnel connection"

kubectl -n ingress port-forward deploy/cloudflared 2000:2000
curl -s localhost:2000/ready   # expected: {"status":"healthy"}
```

Cloudflare dashboard: **Networks → Tunnels → helios-k3s** → status must be **HEALTHY**.

### 5. Remove Router Port Forwarding

Once tunnel is healthy, delete TCP 443 (and 80) port forwarding rules from the Keenetic router.

### 6. Clean Up DDNS (optional)

```hcl
# terraform.tfvars
ddns_subdomains = []
```
Then `terraform apply`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Tunnel INACTIVE in dashboard | Token wrong/expired | Re-generate token, update Secret, rollout restart |
| `502 Bad Gateway` | NGINX not reachable on port 80 | `kubectl -n ingress get svc ingress-nginx-controller` |
| `301` redirect loop | `use-forwarded-headers` not applied | Run `terraform apply` to update NGINX ConfigMap |
| Tunnel DEGRADED | One replica failed on single node | Normal; set `replicas: 1` if it bothers you |
| `ERR_TUNNEL_CONNECTION_FAILED` | No outbound internet from node | Check DNS + firewall on k3s node |
| Wildcard not matching | Free Cloudflare plan | Add each subdomain as explicit Public Hostname row |
