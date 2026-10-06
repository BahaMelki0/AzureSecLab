output "resource_group" { value = azurerm_resource_group.lab.name }
output "vm_name" { value = azurerm_linux_virtual_machine.workload.name }
output "vault_name" { value = azurerm_key_vault.lab.name }
output "identity_client_id" { value = azurerm_user_assigned_identity.workload.client_id }
output "identity_principal_id" { value = azurerm_user_assigned_identity.workload.principal_id }
output "workspace_id" { value = azurerm_log_analytics_workspace.lab.workspace_id }
output "security_mode" { value = var.security_mode }
