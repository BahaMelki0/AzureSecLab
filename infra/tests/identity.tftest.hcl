mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/workload" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/networkSecurityGroups/test-nsg" }
  }
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/publicIPAddresses/test-ip" }
  }
  mock_resource "azurerm_network_interface" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-nic" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-mi"
      principal_id = "00000000-0000-0000-0000-000000000003"
    }
  }
  mock_resource "azurerm_key_vault" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/test-vault" }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-logs" }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  prefix          = "azureseclabtest"
  operator_ipv4   = "192.0.2.1"
  ssh_public_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBmYHPCUlGiukBkHgKnrADwb8tLTBxFCuqIX8cqzPVoj fixture"
}

run "base_has_no_workload_secret_role" {
  command = apply
  assert {
    condition     = length(azurerm_role_assignment.workload) == 0
    error_message = "Unseeded base must not grant workload secret access."
  }
  assert {
    condition     = length(azurerm_sentinel_log_analytics_workspace_onboarding.lab) == 0
    error_message = "Sentinel must remain opt-in."
  }
}

run "hardened_is_canary_scoped" {
  command = apply
  variables { secrets_seeded = true }
  assert {
    condition     = azurerm_role_assignment.workload[0].scope == "${azurerm_key_vault.lab.id}/secrets/lab-canary"
    error_message = "Hardened mode must grant only canary access."
  }
}

run "vulnerable_is_vault_scoped" {
  command = apply
  variables {
    secrets_seeded       = true
    security_mode        = "vulnerable"
    acknowledge_lab_risk = true
  }
  assert {
    condition     = azurerm_role_assignment.workload[0].scope == azurerm_key_vault.lab.id
    error_message = "Controlled vulnerable mode must demonstrate vault-wide scope."
  }
}

run "risk_acknowledgment_required" {
  command = plan
  variables { security_mode = "vulnerable" }
  expect_failures = [azurerm_resource_group.lab]
}
