# Deployment and acceptance runbook

## 1. Prerequisites and spending

Do not apply until the subscription owner has agreed a spending limit. Inspect the pricing calculator and any credits; configure a budget alert separately. This project does not promise a free tier or enforce a financial stop. Run Command requires VM permissions and demonstrates an authorized lab foothold.

Install Azure CLI and Terraform 1.16.x. A checksum-verified Windows Terraform executable is available locally at `.tools/terraform.exe` in the initial workspace, but is ignored by Git; portable users should install Terraform themselves. The examples below assume Terraform is on PATH. Authenticate and deliberately choose the lab subscription:

```powershell
az login
az account set --subscription YOUR-SUBSCRIPTION-ID
az account show --query '{name:name,id:id}'
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\azureseclab"
Copy-Item infra/terraform.tfvars.example infra/terraform.tfvars
```

Edit the ignored tfvars with the subscription ID, unique lowercase prefix, your public IPv4 and the generated `.pub` key. Never paste the private key. Authentication remains in Azure CLI, not tfvars. Ensure the caller can write role assignments as well as resources; Contributor alone is insufficient. Check that Standard_B1s and the Ubuntu image are available in the chosen region. The AzureRM provider may register required resource providers and fail if your account cannot do that.

## 2. Provision the base and seed

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=base.tfplan
# Review every resource, subscription, network rule and cost-bearing service.
terraform -chdir=infra apply base.tfplan
python -m scripts.seed
```

The initial default is hardened with `secrets_seeded=false`, so no workload role is created. If seeding returns Forbidden, inspect your operator IP and Secrets Officer assignment, allow RBAC propagation, and retry. Never seed production data. Only two clearly public canary values are created. Sentinel is disabled unless explicitly enabled in your reviewed configuration.

## 3. Reproduce the excessive scope

```powershell
terraform -chdir=infra plan -var="secrets_seeded=true" -var="security_mode=vulnerable" -var="acknowledge_lab_risk=true" -out=vulnerable.tfplan
terraform -chdir=infra apply vulnerable.tfplan
python -m scripts.probe --phase vulnerable
python -m scripts.report --input evidence/live/vulnerable.json --output reports/live-vulnerable.html
```

Expect canary=200 and payroll=200. The VM obtains its own managed identity token via IMDS, calls the Key Vault data plane, and emits only target names and HTTP statuses. Tokens and secret bodies are not printed or stored. Unexpected networking or token errors fail the probe instead of creating passing evidence.

## 4. Investigate

Get `terraform -chdir=infra output -raw identity_principal_id`, replace the placeholder in `detections/keyvault-secret-access.kql` and run the query in the workspace. Allow ingestion delay and inspect the actual identity/request columns. Preserve sanitized logs showing the payroll SecretGet and caller identity. The VM result alone does not prove log delivery or an alert.

## 5. Harden and prove both access outcomes

```powershell
terraform -chdir=infra plan -var="secrets_seeded=true" -var="security_mode=hardened" -out=hardened.tfplan
terraform -chdir=infra apply hardened.tfplan
python -m scripts.probe --phase hardened
python -m scripts.report --input evidence/live/hardened.json --output reports/live-hardened.html
```

Expect canary=200 and payroll=403. Confirm the old vault-wide assignment was removed; allow propagation and rerun rather than changing expected values. Inspect the audit denial reason. The probe reports access outcomes, not a diagnosis of each possible 403. Independent network and permission evidence is required.

All scenario variables above are command-line overrides and are not persisted. For later plans, supply the intended values again or put the hardened/seeded values in your ignored tfvars. Never blindly apply an old saved vulnerable plan after remediation.

## 6. Acceptance checklist

- Terraform fmt/validate and Python tests pass locally.
- Reviewed cloud plan targets only the isolated lab subscription/group.
- Both synthetic secrets exist and no real values appear in state or evidence.
- Vulnerable probe reads both targets; hardened probe retains only canary access.
- Key Vault logs identify the workload and both attempts; denial reason is understood.
- If Sentinel is enabled, separately create/test the analytic proposal and retain its actual incident evidence.
- Export sanitized before/after results and screenshots; clearly distinguish live evidence from fixtures.
- Run destroy and verify deletion and ongoing charges.

## 7. Cleanup

```powershell
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

Review the destroy plan before applying. Verify the resource group is gone and inspect Cost Management afterward. Purge-protected vaults remain soft-deleted until retention expires. Local state, plans, keys and live artifacts are ignored by Git but still need local protection. Do not commit them or publish tenant identifiers and unredacted cloud logs.
