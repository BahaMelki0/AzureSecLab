# Security

Run this project only in your own isolated Azure lab. Use synthetic secrets. Do not submit real tokens, credentials, Terraform state, private keys or raw production logs in issues or pull requests.

Vulnerable mode deliberately grants excessive secret-read scope to the lab workload. Default mode is hardened; first provision grants no workload secret role. The repository never deploys cloud resources in CI.

For vulnerabilities in the tooling, use GitHub private vulnerability reporting when available. Report the affected version, reproducible synthetic input and impact. Avoid posting an active secret publicly.
