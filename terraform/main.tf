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

variable "stage" {
  type        = string
  description = "gives all resources a common name"
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

variable "ssh_password" {
  type        = string
  description = "password for SSH user created in the VM"
  sensitive   = true
}


locals {
  # Event Store Production Application ID with access to peering creation
  eventstore_application_id = "38bd60cb-6efa-49e8-a1cd-3b9f61d9435e"
  name_prefix               = "${var.stage}-EscAzNetworkExample"
  az_name_prefix            = replace(local.name_prefix, "-", "")
  az_short_name_prefix      = replace("${var.stage}-EscNetEx", "-", "")
}


data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "${local.name_prefix}-ResourceGroup"
  location = var.region
}

resource "azurerm_virtual_network" "example" {
  name                = "${local.name_prefix}-Network"
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
  name        = "${local.name_prefix}-ESCPeering/${data.azurerm_subscription.current.id}/${azurerm_resource_group.example.name}/${azurerm_virtual_network.example.name}"
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
  name = "${local.name_prefix}-Network"

  project_id = var.project_id

  resource_provider = "azure"
  region            = azurerm_resource_group.example.location
  cidr_block        = "10.2.0.0/16"
}

resource "eventstorecloud_peering" "example" {
  name = "${local.name_prefix}-Peering"

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

resource "azurerm_public_ip" "box_ip" {
  name                = "${local.name_prefix}-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "box_ngs" {
  name                = "${local.name_prefix}-network-security-groups"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "24"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "example" {
  name                = "${local.name_prefix}-network-interface"
  location            = var.region
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "ipconfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = azurerm_public_ip.box_ip.id
  }
}

resource "azurerm_storage_account" "example" {
  // This can only be 24 characters long
  name                     = lower(local.az_short_name_prefix)
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_container" "example" {
  name                  = lower("${local.name_prefix}-vhd")
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.example]
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${local.name_prefix}-vm"
  location              = var.region
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = ["${azurerm_network_interface.example.id}"]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${local.name_prefix}-disk"
    vhd_uri       = "${azurerm_storage_account.example.primary_blob_endpoint}${azurerm_storage_container.example.name}/${local.name_prefix}-disk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = local.name_prefix
    admin_username = "cloudperson"
    admin_password = var.ssh_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "staging"
  }
}

output "eventstore_network_id" {
  value = eventstorecloud_network.example.id
}

output "eventstore_peering_id" {
  value = eventstorecloud_peering.example.id
}

output "azuread_service_principal_id" {
  value = azuread_service_principal.peering.id
}

output "vm_ip_address" {
  value = azurerm_public_ip.box_ip.ip_address
}
