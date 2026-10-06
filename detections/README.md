# Key Vault managed identity access

The query finds both successful and denied reads of the unrelated synthetic payroll secret by the workload identity. Replace the principal ID placeholder and run it in the deployed Log Analytics workspace; Sentinel onboarding is optional. The diagnostic setting uses AzureDiagnostics, not the resource-specific AZKVAuditLogs table.

Start with a one-hour lookback and allow for ingestion delay. Verify the actual columns with `AzureDiagnostics | where ResourceProvider == "MICROSOFT.KEYVAULT" | take 5`. If the identity field is absent, inspect the schema and adapt the query; do not remove identity filtering and claim the result is equivalent.

Analytic proposal: run every 5 minutes with a 15-minute lookback; alert on at least one matching event. Overlapping windows can create duplicate alerts; tune incident grouping by identity and vault. This is a hunting query, not an automatically deployed or cloud-validated analytic rule.

ATT&CK: T1552.005 (Cloud Instance Metadata API) describes the metadata credential path; T1078.004 (Cloud Accounts) describes use of cloud identity. This lab starts from an explicitly authorized VM execution capability; it does not demonstrate initial compromise. Normal application traffic, operator testing and RBAC propagation retries are expected false-positive contexts.
