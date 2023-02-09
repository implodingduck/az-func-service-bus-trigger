terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.29.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

locals {
  func_name = "func${random_string.unique.result}"
  loc_for_naming = lower(replace(var.location, " ", ""))
  gh_repo = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

data "azurerm_network_security_group" "basic" {
    name                = "basic"
    resource_group_name = "rg-network-eastus"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}

resource "azurerm_servicebus_namespace" "sbn" {
  name                = "sb-${local.gh_repo}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_servicebus_topic" "topic" {
  name         = "funcservicebustopic"
  namespace_id = azurerm_servicebus_namespace.sbn.id
}

resource "azurerm_servicebus_subscription" "sub" {
  name               = "subfuncservicebustopic"
  topic_id           = azurerm_servicebus_topic.topic.id
  max_delivery_count = 1
}

resource "azurerm_servicebus_subscription" "sub2" {
  name               = "subfuncservicebustopic2"
  topic_id           = azurerm_servicebus_topic.topic.id
  max_delivery_count = 1
}

resource "azurerm_eventhub_namespace" "ehn" {
  name                = "ehn-${local.gh_repo}-${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1

  tags = local.tags
}

resource "azurerm_eventhub" "eh" {
  name                = "funceventhub"
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_application_insights" "app" {
  name                = "${local.func_name}-insights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "other"
  workspace_id        = data.azurerm_log_analytics_workspace.default.id
}


resource "azurerm_storage_account" "sa" {
  name                          = "sa${local.func_name}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "func" {
  name                = "${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  service_plan_id            = azurerm_service_plan.asp.id

  site_config {
    application_insights_key = azurerm_application_insights.app.instrumentation_key
    always_on                = true
    application_stack {
      node_version = "16"
    }

  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT"                 = "1"
    "BUILD_FLAGS"                                    = "UseExpressBuild"
    "ENABLE_ORYX_BUILD"                              = "true"
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"       = azurerm_storage_account.sa.primary_connection_string
    "WEBSITE_CONTENTSHARE"                           = "${local.func_name}"
    "SERVICE_BUS_NAMESPACE__fullyQualifiedNamespace" = "sb-${local.gh_repo}-${random_string.unique.result}.servicebus.windows.net"
    "TOPIC_NAME"                                     = "funcservicebustopic"
    "EVENT_HUB_NAMESPACE__fullyQualifiedNamespace"   = "ehn-${local.gh_repo}-${random_string.unique.result}.servicebus.windows.net"
    "XDG_CACHE_HOME"                                 = "/tmp/.cache"
    "AzureWebJobs.EventHubTrigger.Disabled"          = "1"

  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "asbdo" {
  role_definition_name = "Azure Service Bus Data Owner"
  scope = azurerm_resource_group.rg.id
  principal_id = azurerm_linux_function_app.func.identity.0.principal_id
}

resource "azurerm_role_assignment" "aehdo" {
  role_definition_name = "Azure Event Hubs Data Owner"
  scope = azurerm_resource_group.rg.id
  principal_id = azurerm_linux_function_app.func.identity.0.principal_id
}

resource "local_file" "localsettings" {
  content  = <<-EOT
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": ""
  }
}
EOT
  filename = "../func/local.settings.json"
}

resource "null_resource" "publish_func" {
  depends_on = [
    azurerm_linux_function_app.func,
    local_file.localsettings
  ]
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    working_dir = "../func"
    command     = "sleep 10 && timeout 10m func azure functionapp publish ${azurerm_linux_function_app.func.name} --build remote"

  }
}