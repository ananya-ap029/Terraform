resource "azurerm_resource_group" "test" {
  name = "rg-${var.project}-${var.env}-${var.region_short}-${var.deployment-number}"
  location = var.location
  tags = local.default_tags
}

resource "azurerm_key_vault" "kvmain" {
  name                       = "kv-${var.project}-${var.env}-${var.region_short}-${var.deployment-number}"
  resource_group_name        = azurerm_resource_group.test.name
  location                   = azurerm_resource_group.test.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku_names
  soft_delete_retention_days = 20
  enable_rbac_authorization  = true  
  purge_protection_enabled = false
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_eventgrid_system_topic" "kvmain-sys-topic" {
  name                   = "evst-${var.project}-${var.env}-${var.region_short}-keyvault-${var.deployment-number}"
  resource_group_name    = azurerm_resource_group.test.name
  location               = azurerm_resource_group.test.location
  source_arm_resource_id = azurerm_key_vault.primary.id
  topic_type             = "Microsoft.KeyVault.vaults"
} 

resource "azurerm_eventgrid_system_topic_event_subscription" "kvmain-sys-topic-event-subs" {
  name = "evss-${var.project}-${var.env}-${var.region_short}-keyvault-${var.deployment-number}"
  resource_group_name = azurerm_resource_group.test.name
  system_topic = azurerm_eventgrid_system_topic.kvmain-sys-topic.name
  event_delivery_schema = "EventGridSchema"
  service_bus_topic_endpoint_id = azurerm_servicebus_topic.azurekeyvaultevent.id
  included_event_types = [
    "Microsoft.KeyVault.SecretNewVersionCreated",
    "Microsoft.KeyVault.KeyNewVersionCreated"
  ]
  advanced_filtering_on_arrays_enabled =  true
  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}


resource "azurerm_storage_account" "st_acct" {
  name                     = "sa${var.env}${var.region_short}test${var.deployment-number}"
  resource_group_name      = azurerm_resource_group.test.name
  location                 = azurerm_resource_group.test.location
  account_tier             = "Standard"
  account_replication_type = var.storage_acc_replication_type 
  public_network_access_enabled = true
  shared_access_key_enabled = false
  tags = {
    environment = var.env
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_container" "st_acct_container" {
  name                  = "test"
  storage_account_id    = azurerm_storage_account.st_acct.id
  container_access_type = "private"
}

resource "azurerm_public_ip" "appgway_pip" {
  name                = local.public_ip_name
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  allocation_method   = "Static"
  zones               = var.create_zones == true ?  ["1", "2", "3"] : null
}


resource "azurerm_application_gateway" "appgateway" {
  depends_on          = [azurerm_public_ip.appgw-pip]
  name                = "app-gateway-${var.project}-${var.env}-${var.region_short}-${var.deployment-number}"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  zones               = var.create_zones == true ?  ["1", "2", "3"] : null

  lifecycle {
    ignore_changes = [tags, request_routing_rule]
  }

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
  }

  rewrite_rule_set {
    name = "CustomResponseHeaderRuleSet"

    rewrite_rule {
      name          = "CustomResponseHeaderRule"
      rule_sequence = 1

      response_header_configuration {
        header_name  = "Cross-Origin-Resource-Policy"
        header_value = "same-origin"
      }
      response_header_configuration {
        header_name  = "Cross-Origin-Opener-Policy"
        header_value = "same-origin"
      }
      response_header_configuration {
        header_name  = "Cross-Origin-Embedder-Policy"
        header_value = "require-corp"
      }
    }
  }
  
  autoscale_configuration {
      min_capacity = var.app_gateway_min_capacity
      max_capacity = var.app_gateway_max_capacity
  }
  
  enable_http2 = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uaid.id]
  }

  ssl_certificate {
    key_vault_secret_id = data.azurerm_kv_cert.cert1name.secret_id
    name                = "appgw-listener-cert"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgw-subnet.id
  }

  test_test_frontend_port {
    name = "${azurerm_virtual_network.appgw-vnet.name}-http-feport"
    port = "80"
  }

  test_frontend_port {
    name = "${azurerm_virtual_network.appgw-vnet.name}-ssl-feport"
    port = "443"
  }


  frontend_ip_configuration {
    name                 = "${azurerm_virtual_network.appgw-vnet.name}-feip"
    public_ip_address_id = azurerm_public_ip.appgw-pip.id
  }

  backend_address_pool {
    name  = "web"
    fqdns = ["${azurerm_windows_web_app.webapp.name}.azurewebsites.net"]
  }


  probe {
    name                                      = local.backend_probe_name_1
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 120
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                                      = local.backend_probe_name_2
    protocol                                  = "Https"
    path                                      = "/api/Home/Status"
    interval                                  = 30
    timeout                                   = 120
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = "wellknown-settings"
    probe_name                          = local.backend_probe_name_3
    cookie_based_affinity               = "Disabled"
    path                                = ""
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = "test-ssl"
    frontend_ip_configuration_name = "${azurerm_virtual_network.appgw-vnet.name}-feip"
    test_frontend_port_name             = "${azurerm_virtual_network.appgw-vnet.name}-ssl-feport"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-listener-cert"

    custom_error_configuration {
      status_code = "HttpStatus504"
      custom_error_page_url = "https://xxxx.blob.core.windows.net/$test/error504.html"
    }

  }

  request_routing_rule {
    name                       = "fe-ssl-rule"
    rule_type                  = "Basic"
    http_listener_name         = "fe-ssl-root"
    priority                   = 3
    backend_address_pool_name  = "fe"
    backend_http_settings_name = "fe-root-settings"
    rewrite_rule_set_name      = "CustomResponseHeaderRuleSet"
  }


  url_path_map {
    name                               = "web-ssl-rules"
    default_backend_address_pool_name  = "fe"
    default_backend_http_settings_name = "fe-root-settings"


    path_rule {
      name                       = "wellknown-path-rules"
      paths                      = ["/.well-known/*"]
      backend_address_pool_name  = "testbe"
      backend_http_settings_name = "wellknown-settings"
      rewrite_rule_set_name      = "CustomResponseHeaderRuleSet" 
    }
  }
}
