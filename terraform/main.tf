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
  name         = "topic-${local.gh_repo}-${random_string.unique.result}"
  namespace_id = azurerm_servicebus_namespace.sbn.id
}

resource "azurerm_servicebus_subscription" "sub" {
  name               = "sub-${local.gh_repo}-${random_string.unique.result}"
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
  name                = "eh-${local.gh_repo}-${random_string.unique.result}"
  namespace_name      = azurerm_eventhub_namespace.ehn.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}