# Azure Terraform State Backend

## Why This Exists

Terraform needs somewhere to store its **state file** — a JSON record of every resource it manages
(Helm releases, Kubernetes secrets, namespaces, deployments, etc.) and their current real-world
values. Without state, Terraform cannot tell what already exists, what needs to change, or what
to destroy.

### Why We Moved Away from the Kubernetes Backend

Previously, state was stored as a Kubernetes secret in the `kube-system` namespace of the Helios
k3s cluster itself (`tfstate-default-infrastructure-helios`). This created a **circular dependency
problem**:

- Terraform manages the cluster's workloads
- The cluster holds Terraform's state
- If the cluster is unavailable, unhealthy, or being rebuilt → state is inaccessible → Terraform
  cannot run → you cannot fix the cluster with Terraform

Azure Blob Storage is an **external, independent** store with no dependency on the Helios cluster,
so Terraform can always reach its state regardless of what is happening on the cluster.

---

## What Was Created in Azure

All resources live in the **Overflow** subscription (`9e1a****-****-****-****-********ac7`).

### 1. Resource Group — `rg-helios-tfstate`

| Property | Value |
|---|---|
| Name | `rg-helios-tfstate` |
| Region | West Europe |
| Purpose | Logical container for all tfstate-related Azure resources |

A resource group is Azure's way of grouping related resources for lifecycle management, access
control, and billing. Everything tfstate-related lives here so it can be managed (and if needed,
deleted) as a single unit.

---

### 2. Storage Account — `stheliosinfrastate`

| Property | Value |
|---|---|
| Name | `stheliosinfrastate` |
| SKU | Standard LRS (Locally Redundant Storage) |
| Region | West Europe |
| Public blob access | Disabled |
| Minimum TLS | TLS 1.2 |
| Blob versioning | **Enabled** |

The storage account is the top-level Azure Storage resource. Think of it as the "server" that
holds your blob containers.

**Why Standard LRS?** The state file is small (< 1 MB) and is already versioned. Triple
replication within one datacenter is more than sufficient — there is no need for geo-redundancy
(GRS) for a file this size.

**Why versioning enabled?** Every time Terraform writes a new state (after `apply`), Azure
automatically keeps the previous version. This means you can recover an older state if something
goes wrong — no manual backups needed.

---

### 3. Blob Container — `tfstate`

| Property | Value |
|---|---|
| Name | `tfstate` |
| Access level | Private (no public access) |
| State file blob | `infrastructure-helios.tfstate` |

A container is like a bucket or folder inside the storage account. The single blob
`infrastructure-helios.tfstate` inside it is the actual Terraform state file. Blob-level leasing
is used by Terraform for **state locking** — only one `terraform apply` can run at a time.

---

### 4. Service Principal — `sp-helios-terraform-ci`

| Property | Value |
|---|---|
| Display name | `sp-helios-terraform-ci` |
| App (Client) ID | `1d1c****-****-****-****-********ce7` |
| Object ID | `f175****-****-****-****-********704` |
| Secret expiry | 2027-02-23 |
| Role: Storage Blob Data Owner | Scoped to `stheliosinfrastate` |
| Role: Reader | Scoped to `stheliosinfrastate` |

A Service Principal is Azure's equivalent of a machine/CI user. It exists so that GitHub Actions
(and local runs with `ARM_*` env vars) can authenticate to Azure **without using your personal
credentials**.

**Why only scoped to the storage account?** Least-privilege principle. The SP can only read/write
blobs in that one storage account — it has no access to create, modify, or delete any other Azure
resource. If the secret ever leaks, the blast radius is limited to the state file.

**Why `Storage Blob Data Owner` and not `Contributor`?** When using AAD auth (`use_azuread_auth = true`),
the `azurerm` backend sets blob ownership metadata during state lock/unlock operations. This requires
`Owner`-level blob permissions. `Contributor` is enough for read/write but will return a 403 on the
lock step.

---

## How It All Works Together

```
┌─────────────────────────────────────────────┐
│  Developer / GitHub Actions (self-hosted)   │
│                                             │
│  ARM_CLIENT_ID        ──┐                   │
│  ARM_CLIENT_SECRET    ──┤→ Azure AD auth    │
│  ARM_TENANT_ID        ──┤   (SP login)      │
│  ARM_SUBSCRIPTION_ID  ──┘                   │
└──────────────────────┬──────────────────────┘
                       │ terraform init / plan / apply
                       ▼
┌─────────────────────────────────────────────┐
│  Azure Blob Storage                         │
│  rg-helios-tfstate                          │
│  └─ stheliosinfrastate                      │
│     └─ tfstate/                             │
│        └─ infrastructure-helios.tfstate     │
│           (+ previous versions)             │
└──────────────────────┬──────────────────────┘
                       │ state read/write
                       │ blob lease = state lock
                       ▼
┌─────────────────────────────────────────────┐
│  Helios k3s Cluster (10.12.15.60)           │
│  (kubernetes + helm providers)              │
│                                             │
│  Namespaces, Helm releases, Secrets,        │
│  Deployments, Ingresses, Services...        │
└─────────────────────────────────────────────┘
```

### terraform init

Authenticates to Azure using `ARM_*` env vars, locates the blob container, and downloads the
current state file into memory. Uses AAD auth (`use_azuread_auth = true`) — no storage account
key needed, just the SP's blob role.

### terraform plan / apply

Reads state from Azure, compares against real cluster resources (via kubeconfig), computes a
diff, and writes updated state back to Azure after a successful apply. The blob is **leased
(locked)** for the duration of the operation to prevent concurrent runs.

### State Locking

Azure Blob Storage has a native lease mechanism. Terraform acquires an exclusive lease on the
blob before any write operation. If a run is interrupted, the lease expires automatically after
60 seconds — no manual unlock needed in most cases.

### State Versioning / Recovery

If a bad `apply` corrupts state, open the Azure Portal:

```
Storage accounts → stheliosinfrastate → Containers → tfstate
→ infrastructure-helios.tfstate → ... → Version history
```

Select a previous version and click **Promote** (or download and `terraform state push` it).

---

## Authentication Summary

| Context | How auth works |
|---|---|
| Local development | `~/.config/fish/conf.d/azure-terraform.fish` — auto-loaded in every shell session |
| GitHub Actions | `ARM_*` env vars injected from GitHub Secrets |
| Azure backend only | Uses SP + AAD auth (`use_azuread_auth = true` in `provider.tf`) |
| k8s/helm providers | Separate — uses `KUBECONFIG` / `kubeconfig_path` variable, unrelated to Azure |

---

## Cleanup (if ever needed)

To fully remove the Azure tfstate infrastructure:

```bash
# 1. First push state somewhere safe or export it
terraform state pull > terraform.tfstate.final

# 2. Delete everything in Azure
az group delete --name rg-helios-tfstate --yes

# 3. Delete the Service Principal
az rest --method DELETE \
  --url "https://graph.microsoft.com/v1.0/applications/<app-object-id>"
```

