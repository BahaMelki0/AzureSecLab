# Validation record

Verified locally on October 6, 2026:

- Terraform 1.16.5 downloaded with SHA256 verification; AzureRM 5.8.0 installed with HashiCorp signature verification.
- Terraform init, fmt and validate succeed.
- Provider checksums locked for Windows amd64 and Linux amd64.
- Four Terraform mock-provider runs pass: unseeded base, canary-scoped hardening, vault-scoped vulnerable mode and required risk acknowledgment.
- Eleven Python tests pass for access expectations, incomplete/malformed evidence, provenance and safe probe generation.
- Both synthetic HTML reports generate successfully.

Mock-provider apply operations do not create Azure resources. Provider schema validation does not prove real API behavior. No subscription authentication, real plan/apply, VM probe, audit ingestion, Sentinel incident, cost measurement or live destroy has been performed. Follow RUNBOOK.md to complete those checks.
