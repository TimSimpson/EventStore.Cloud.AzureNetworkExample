terraform {
  required_providers {
    eventstorecloud = {
      source = "EventStore/eventstorecloud"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}
provider "eventstorecloud" {}

provider "azurerm" {
  features {}
}

locals {
  # Event Store Production Application ID with access to peering creation
  eventstore_application_id = "38bd60cb-6efa-49e8-a1cd-3b9f61d9435e"
}

variable "project_id" {
  type        = string
  description = "Project ID where the Network and Peering will live"
}

variable "region" {
  type        = string
  description = "Azure region where resources should live"
  default     = "West US2"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscruption ID"
}



data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "AzurePeeringExampleGroup"
  location = var.region
}

resource "azurerm_virtual_network" "example" {
  name                = "AzurePeeringExampleNetwork"
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
}

// Access to Event Store Application should be granted to create peering between Azure Virtual Networks
resource "azuread_service_principal" "peering" {
  application_id               = local.eventstore_application_id
  app_role_assignment_required = false

  # If this already exists, you can uncomment the following line.
  # But note Terraform will delete it when you remove it later.

  #   use_existing                 = true
}

resource "azurerm_role_definition" "example" {
  name        = "ESCPeering/${data.azurerm_subscription.current.id}/${azurerm_resource_group.example.name}/${azurerm_virtual_network.example.name}"
  scope       = data.azurerm_subscription.current.id
  description = "Grants ESC access to manage peering connections on network ${azurerm_virtual_network.example.id}"

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/virtualNetworks/peer/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_virtual_network.example.id,
  ]
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_virtual_network.example.id
  role_definition_name = azurerm_role_definition.example.name
  principal_id         = azuread_service_principal.peering.id
}


resource "eventstorecloud_network" "example" {
  name = "Azure Network Peering Example"

  project_id = var.project_id

  resource_provider = "azure"
  region            = azurerm_resource_group.example.location
  cidr_block        = "10.2.0.0/16"
}

resource "eventstorecloud_peering" "example" {
  name = "Example Peering"

  project_id = eventstorecloud_network.example.project_id
  network_id = eventstorecloud_network.example.id

  peer_resource_provider = eventstorecloud_network.example.resource_provider
  peer_network_region    = eventstorecloud_network.example.region

  peer_account_id = data.azurerm_client_config.current.tenant_id
  peer_network_id = azurerm_virtual_network.example.id
  routes          = azurerm_virtual_network.example.address_space

  depends_on = [
    azurerm_role_assignment.example,
  ]
}

output "eventstore_network_id" {
  value = eventstorecloud_network.example.id
}

output "eventstore_peering_id" {
  value = eventstorecloud_peering.example.id
}
