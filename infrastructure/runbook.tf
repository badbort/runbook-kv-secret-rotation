locals {
  script_root = format("%s/../scripts", path.module)
}

resource "azurerm_automation_account" "automation" {
  name                = "myAutomationAccount"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_automation_runbook" "update_team_keyvault" {
  name                    = "Update-TeamKeyVault"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Loops through primary key secrets, invokes Update-SubscriptionSecrets and Update-DestinationKeyVault"
  runbook_type            = "PowerShell72"
  content                 = file("${local.script_root}/Update-TeamKeyVault.ps1")
}

resource "azurerm_automation_runbook" "update_subscription_secrets" {
  name                    = "Update-SubscriptionSecrets"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Handles individual subscription secret updates"
  runbook_type            = "PowerShell72"
  content                 = file("${local.script_root}/Update-SubscriptionSecrets.ps1")
}

resource "azurerm_automation_runbook" "update_destination_keyvault" {
  name                    = "Update-DestinationKeyVault"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Copies ActiveKey secret to the destination secret"
  runbook_type            = "PowerShell72"
  content                 = file("${local.script_root}/Update-DestinationKeyVault.ps1")
}

resource "azurerm_role_assignment" "automation_key_vault_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_automation_account.automation.identity.0.principal_id
}