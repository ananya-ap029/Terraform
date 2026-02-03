terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  tenant_id                       = "XXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
  resource_provider_registrations = "none"
  storage_use_azuread = true
  features {    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
     resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
