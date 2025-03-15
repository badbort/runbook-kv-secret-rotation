resource "azurerm_key_vault" "kv" {
  name                      = var.keyvault_name
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

resource "terraform_data" "origin_timestamp" {
  for_each = { for sub in var.subscriptions : sub.SubscriptionId => sub }
  input = {
    Age = each.value.RotationDuration
  }
}

resource "time_static" "rotation_origin" {
  for_each   = { for sub in var.subscriptions : sub.SubscriptionId => sub }
  depends_on = [terraform_data.origin_timestamp]
  lifecycle {
    replace_triggered_by = [terraform_data.origin_timestamp[each.key]]
  }
}

resource "azurerm_key_vault_secret" "primary" {
  for_each     = { for sub in var.subscriptions : sub.SubscriptionId => sub }
  name         = "${each.key}-PrimaryKey"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [terraform_data.kv_roles]

  tags = merge(
    {
      SubscriptionId = each.key
      Origin         = time_static.rotation_origin[each.key].rfc3339
    },
    each.value.RotationDuration != null ? { Age = each.value.RotationDuration } : {}
  )

  lifecycle {
    ignore_changes = [value, expiration_date, tags["LastScan"], tags["ForceRotation"]]
  }
}

resource "azurerm_key_vault_secret" "secondary" {
  for_each = { for sub in var.subscriptions : sub.SubscriptionId => sub }

  name         = "${each.key}-SecondaryKey"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [terraform_data.kv_roles]

  lifecycle {
    ignore_changes = [value, expiration_date, tags]
  }
}

resource "azurerm_key_vault_secret" "active" {
  for_each = { for sub in var.subscriptions : sub.SubscriptionId => sub }

  name         = "${each.key}-ActiveKey"
  value        = "placeholder"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [terraform_data.kv_roles]

  tags = {
    SubscriptionId = each.key
  }

  lifecycle {
    ignore_changes = [value, expiration_date, tags]
  }
}

resource "terraform_data" "kv_roles" {
  depends_on = [
    azurerm_role_assignment.kv_secrets_officer,
    azurerm_role_assignment.kv_reader,
  ]
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = "5b7e73a8-ae54-46ef-a687-b34345720e61"
}

resource "azurerm_role_assignment" "kv_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = "5b7e73a8-ae54-46ef-a687-b34345720e61"
}
