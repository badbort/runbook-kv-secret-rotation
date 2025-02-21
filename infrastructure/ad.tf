# Create an Azure AD Application for GitHub Actions
# resource "azuread_application" "github_app" {
#   display_name = "GitHubActionsApp"
# }
# 
# # Create a Service Principal for the Application
# resource "azuread_service_principal" "github_sp" {
#   client_id = azuread_application.github_app.client_id
# }
# 
# # Create Federated Credentials for GitHub Actions OIDC
# resource "azuread_application_federated_identity_credential" "github_oidc" {
#   application_object_id = azuread_application.github_app.object_id
#   display_name          = "GitHubOIDC"
#   description           = "Federated credential for GitHub Actions OIDC"
# 
#   audiences = ["api://AzureADTokenExchange"]
#   issuer    = "https://token.actions.githubusercontent.com"
#   subject   = "repo:my-org/my-repo:ref:refs/heads/main"
# }
# 
# # Assign a Role (e.g., Contributor) to the Service Principal
# resource "azurerm_role_assignment" "github_role" {
#   scope                = azurerm_resource_group.rg.id
#   role_definition_name = "Contributor"
#   principal_id         = azuread_service_principal.github_sp.object_id
# }
