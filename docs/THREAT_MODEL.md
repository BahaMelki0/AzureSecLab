# Threat model

## Assets and boundaries

Assets: synthetic vault secrets, workload managed identity token, role assignments, Terraform state, cloud audit trail. Boundaries: operator to Azure management plane; VM process to instance metadata; managed identity to Key Vault data plane; Key Vault to Log Analytics.

Starting capability: a process executing inside the dedicated lab VM, invoked by the authorized operator using Run Command. This is a post-compromise permission exercise, not an initial access exploit. Someone with Run Command rights can execute code inside that VM; those rights must be controlled independently in real environments.

Attack path: VM execution -> IMDS identity token -> vault-wide Secrets User role -> unrelated payroll secret read. No production tenant or third-party endpoint is targeted. Removing excessive scope addresses this specific path while preserving required application access.

## Controls and residual risk

| Risk | Control | Remaining limitation |
|---|---|---|
| Workload reads unrelated secrets | Canary-scoped role after remediation | Secret-level role management is a lab demonstration; separate vaults per application are often easier to govern |
| Unauthenticated network exposure | Inbound NSG deny; Key Vault firewall allowlist | VM still has a public IP for outbound; Key Vault is not a private endpoint |
| Secret leakage in infrastructure artifacts | Azure CLI creates public synthetic values; no Terraform secret resource | State still contains resource identifiers; real secrets must never be used |
| Token leakage in reports | Probe discards bodies and prints only statuses | A VM process with access can independently obtain its identity token |
| Missed detection | AuditEvent diagnostic setting and identity-filtered query | Daily cap, ingestion delay, schema changes and logging failures can reduce visibility |
| Unexpected costs | Small VM, optional Sentinel, explicit teardown | No enforced budget stop; disks/IP/logging remain billable when compute stops |
| Misleading evidence | Fixture provenance and separate live directory | Live HTTP statuses need corroborating audit records |

## Validation boundaries

Offline validation establishes syntax, provider schema compatibility and deterministic evidence processing. It cannot establish deployment permissions, VM image/SKU availability, RBAC propagation, network reachability, log ingestion or Sentinel alerts. Mark the lab operational only after the runbook produces real before/after evidence.
