data "azurerm_client_config" "operator" {}

locals {
  tags = { project = "AzureSecLab", purpose = "isolated-security-lab", owner = "Bahaeddine-Melki" }
}

resource "azurerm_resource_group" "lab" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = local.tags
  lifecycle {
    precondition {
      condition     = var.security_mode != "vulnerable" || var.acknowledge_lab_risk
      error_message = "Vulnerable mode requires acknowledge_lab_risk=true. Only synthetic data is permitted."
    }
  }
}

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}
resource "azurerm_subnet" "workload" {
  name                            = "workload"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.42.1.0/24"]
  default_outbound_access_enabled = false
  service_endpoint {
    service = "Microsoft.KeyVault"
  }
}
resource "azurerm_network_security_group" "workload" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
resource "azurerm_public_ip" "egress" {
  name                = "${var.prefix}-egress"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}
resource "azurerm_network_interface" "workload" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.egress.id
  }
}
resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.prefix}-identity"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}
resource "azurerm_linux_virtual_machine" "workload" {
  name                            = "${var.prefix}-vm"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = "Standard_B1s"
  admin_username                  = "laboperator"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.workload.id]
  tags                            = local.tags
  admin_ssh_key {
    username   = "laboperator"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }
  depends_on = [azurerm_subnet_network_security_group_association.workload]
}
resource "azurerm_key_vault" "lab" {
  name                       = "${var.prefix}-kv"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.operator.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  tags                       = local.tags
  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    ip_rules                   = [var.operator_ipv4]
    virtual_network_subnet_ids = [azurerm_subnet.workload.id]
  }
}
resource "azurerm_role_assignment" "operator" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.operator.object_id
}
resource "azurerm_role_assignment" "workload" {
  count                = var.secrets_seeded ? 1 : 0
  scope                = var.security_mode == "vulnerable" ? azurerm_key_vault.lab.id : "${azurerm_key_vault.lab.id}/secrets/lab-canary"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "${var.prefix}-logs"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.tags
}
resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                       = "vault-audit"
  target_resource_id         = azurerm_key_vault.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id
  enabled_log {
    category = "AuditEvent"
  }
}
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "lab" {
  count                        = var.enable_sentinel ? 1 : 0
  workspace_id                 = azurerm_log_analytics_workspace.lab.id
  customer_managed_key_enabled = false
}
