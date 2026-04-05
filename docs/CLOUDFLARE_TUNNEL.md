# Cloudflare Tunnel Setup
Replaces router port forwarding with an outbound-only Cloudflare Tunnel.
No open inbound ports on the router needed.
## Architecture
```
Browser
  |  HTTPS (Cloudflare edge terminates TLS)
  v
Cloudflare Edge
  |  Encrypted tunnel (QUIC/HTTP2, outbound only from k3s)
  v
cloudflared pod  (k3s, namespace: ingress)
  |
  └── *.devoverflow.org  ──►  http://ingress-nginx-controller.ingress:80
                                         |
                                         └── nginx routes to backend services
```
Key points:
- cloudflared initiates the **outbound** connection — zero inbound firewall rules needed
- Cloudflare terminates TLS at the edge (your cert is managed by Cloudflare)
- nginx receives plain HTTP from cloudflared; it sends `X-Forwarded-Proto: https`
- `use-forwarded-headers: "true"` is set on nginx so ssl-redirect does not loop
---
## Overview of steps
1. Create a tunnel in Cloudflare Zero Trust dashboard
2. Add a Public Hostname DNS route in the dashboard
3. Put the tunnel token in Terraform vars and apply
4. Verify the tunnel is healthy
5. Remove port forwarding from the router
6. (Optional) remove DDNS deployments
---
## Step 1 — Create the tunnel in Cloudflare Zero Trust
1. Open https://one.dash.cloudflare.com
2. In the left sidebar go to **Networks → Tunnels**
3. Click **Create a tunnel**
4. Choose connector type **Cloudflared** → click Next
5. Give the tunnel a name, e.g. `helios-k3s` → click Save tunnel
6. On the next screen Cloudflare shows install instructions.
   Switch to the **Docker** tab and copy the value after `--token`:
   ```
   docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token <COPY_THIS>
   ```
   Save that token — you will need it in Step 3.
7. Click **Next** (you will set the hostname route in Step 2).
> The tunnel will show as "INACTIVE" until cloudflared connects in Step 3. That is expected.
---
## Step 2 — Add a Public Hostname route
Still in the tunnel wizard (or via **Networks → Tunnels → your tunnel → Public Hostname → Add**):
| Field       | Value                                                                 |
|-------------|-----------------------------------------------------------------------|
| Subdomain   | `*`                                                                   |
| Domain      | `devoverflow.org`                                                 |
| Type        | **HTTP**                                                              |
| URL         | `ingress-nginx-controller.ingress.svc.cluster.local:80`               |
Click **Save hostname**.
Cloudflare automatically creates a wildcard CNAME record:
```
*.devoverflow.org  CNAME  <tunnel-id>.cfargotunnel.com
```
You can verify it under **Websites → devoverflow.org → DNS → Records**.
> **Note:** Wildcard Public Hostnames require a Cloudflare **Pro plan or higher**.
> On the Free plan, add each subdomain explicitly as a separate row:
> `keycloak`, `rabbit`, `redisinsight`, `k8s`, `typesense`, `typesense-api`, etc.
---
## Step 3 — Deploy cloudflared via Terraform
Add to `terraform.secret.tfvars` (do NOT commit this file):
```hcl
cloudflare_tunnel_token = "eyJhIjoiABC..."   # token from Step 1
cloudflared_enabled     = true
```
Apply:
```bash
cd terraform
terraform plan  -var-file="terraform.secret.tfvars"
terraform apply -var-file="terraform.secret.tfvars"
```
This creates three resources in namespace `ingress`:
- `Secret/cloudflared-tunnel-token` — stores the token
- `ConfigMap/cloudflared-config` — cloudflared ingress routing rules
- `Deployment/cloudflared` — 2 replicas, each opens an independent tunnel connection
The generated `config.yaml` inside the ConfigMap looks like:
```yaml
ingress:
  - hostname: "*.devoverflow.org"
    service: http://ingress-nginx-controller.ingress.svc.cluster.local:80
  - service: http_status:404   # required catch-all, must be last
```
---
## Step 4 — Verify
```bash
# Both pods should be Running
kubectl -n ingress get pods -l app=cloudflared
# Logs must contain "Registered tunnel connection"
kubectl -n ingress logs -l app=cloudflared --tail=40
# Readiness endpoint — image is distroless (no shell/wget), use port-forward instead
kubectl -n ingress port-forward deploy/cloudflared 2000:2000 &
curl -s localhost:2000/ready   # expected: {"status":"healthy"}
kill %1
# From your laptop — all should return 2xx/3xx
curl -I https://keycloak.devoverflow.org
curl -I https://rabbit.devoverflow.org
```
In the Cloudflare dashboard:
**Networks → Tunnels → helios-k3s** — status must be **HEALTHY** (green dot).
---
## Step 5 — Remove port forwarding from the router
Once the tunnel is confirmed healthy:
1. Log into your **Keenetic** router admin panel
2. Go to **Internet → Port Forwarding** (or equivalent)
3. Delete the rule: `TCP 443 → <k3s-node-IP>`
4. Delete port `80` forwarding too if it exists
Nothing on the internet can reach your router on those ports anymore,
and services continue to work because cloudflared connects outbound.
---
## Step 6 — Clean up DDNS (optional)
With the tunnel active, the DDNS A-records managed by the `cloudflare-ddns` deployments
in `ddns.tf` are obsolete — Cloudflare now resolves `*.devoverflow.org` to the tunnel
endpoint, not your public IP.
To remove them, edit `terraform.tfvars`:
```hcl
ddns_subdomains = []
```
Then `terraform apply`. Or remove the `cloudflare_ddns` blocks from `ddns.tf` entirely.
---
## Troubleshooting
| Symptom | Likely cause | Fix |
|---|---|---|
| Pod running, tunnel INACTIVE in dashboard | Token wrong or expired | Re-generate token in dashboard, update the Secret, rollout restart |
| `502 Bad Gateway` for any subdomain | nginx not reachable on port 80 | `kubectl -n ingress get svc ingress-nginx-controller` |
| `301` redirect loop | `use-forwarded-headers` not applied yet | Run `terraform apply` to update the nginx ConfigMap |
| Tunnel shows DEGRADED | One of two replicas failed | Normal on single node; set `replicas: 1` if it bothers you |
| `ERR_TUNNEL_CONNECTION_FAILED` | k3s node has no outbound internet | Check DNS + firewall on the node itself |
| Wildcard hostname not matching | Free Cloudflare plan | Add each subdomain as an explicit Public Hostname row |
---
## Notes
- **Two replicas** are used so each connects to a different Cloudflare PoP for redundancy.
  On a single-node cluster they coexist on the same host but the tunnel connections are independent.
- **Origin certificates** (`certs/origin.crt` / `origin.key`) in `ingress.tf` remain untouched.
  They can be removed once you are satisfied all traffic flows through the tunnel.
- The token embeds the tunnel ID and credentials — no `credentials-file` or `cert.pem` needed.
- The image (`cloudflare/cloudflared`) is **distroless** — no shell, wget, or curl inside the container.
  Use `kubectl port-forward` to reach the metrics/readiness endpoint from outside.
