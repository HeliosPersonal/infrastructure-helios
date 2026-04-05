# Azure Terraform State Backend

Terraform state is stored in Azure Blob Storage — external to the helios cluster, so Terraform can always reach it regardless of cluster health.

## Resources (Overflow subscription)

| Resource | Name | Notes |
|----------|------|-------|
| Resource group | `rg-helios-tfstate` | West Europe |
| Storage account | `stheliosinfrastate` | Standard LRS, TLS 1.2, versioning enabled |
| Container | `tfstate` | Private |
| State blob | `infrastructure-helios.tfstate` | Blob lease = state lock |
| Service Principal | `sp-helios-terraform-ci` | Role: Storage Blob Data Owner (scoped to storage account only) |

> Blob versioning means every `apply` keeps the previous state automatically — no manual backups needed.

## Authentication

| Context | Method |
|---------|--------|
| Local | `ARM_*` env vars from `~/.config/fish/conf.d/azure-terraform.fish` |
| GitHub Actions | `ARM_*` injected from GitHub Secrets |

Required env vars: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`

`use_azuread_auth = true` in `provider.tf` — no storage account key needed, SP's blob role is sufficient.

> SP secret expires **2027-02-23** — rotate before then in Azure AD and update GitHub Secrets.

## State Recovery

Via Azure Portal:
```
stheliosinfrastate → Containers → tfstate → infrastructure-helios.tfstate → Version history → Promote
```

Via CLI:
```bash
terraform state pull > terraform.tfstate.backup
terraform state push terraform.tfstate.fixed
```

## Cleanup (if ever needed)

```bash
terraform state pull > terraform.tfstate.final
az group delete --name rg-helios-tfstate --yes
az rest --method DELETE \
  --url "https://graph.microsoft.com/v1.0/applications/<app-object-id>"
```
