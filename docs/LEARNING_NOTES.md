# Engineering decisions and learning record

This project connects managed identity, Azure RBAC, network controls and detection evidence rather than treating each as a separate certificate topic.

Implemented decisions:

- Keep synthetic secrets out of Terraform state through separate CLI seeding.
- Default to no workload secret role; require explicit seeding before enabling the scenario.
- Make vulnerable mode an intentional input and guard it with a risk acknowledgment.
- Retain required access after remediation, so a blanket network failure cannot masquerade as a successful hardening result.
- Separate access probes from actual logging and SIEM alert validation.
- Configure explicit VM outbound connectivity and deny inbound access.

Add verified lessons after the first live run: subscription permissions needed, actual cost, role propagation delay, telemetry latency, discovered schema differences, false positives, and teardown behavior. Do not write these as personal experience until they have been observed.
