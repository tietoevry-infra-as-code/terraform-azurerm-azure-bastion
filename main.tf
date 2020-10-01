#----------------------------------------------------------
# Resource Group, VNet, Subnet selection & Random Resources
#----------------------------------------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "random_string" "str" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    domain_name_label = var.azure_bastion_service_name
  }
}

#-----------------------------------------------------------------------
# Subnets Creation for Azure Bastion Service - at least /27 or larger.
#-----------------------------------------------------------------------
resource "azurerm_subnet" "abs_snet" {
  count                = var.azure_bastion_subnet_address_prefix != null ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = var.azure_bastion_subnet_address_prefix
}

#---------------------------------------------
# Public IP for Azure Bastion Service
#---------------------------------------------
resource "azurerm_public_ip" "pip" {
  name                = lower("${var.azure_bastion_service_name}-${data.azurerm_resource_group.rg.location}-pip")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = var.public_ip_allocation_method
  sku                 = var.public_ip_sku
  domain_name_label   = var.domain_name_label != null ? var.domain_name_label : format("gw%s%s", lower(replace(var.azure_bastion_service_name, "/[[:^alnum:]]/", "")), random_string.str.result)
  tags                = merge({ "ResourceName" = lower("${var.azure_bastion_service_name}-${data.azurerm_resource_group.rg.location}-pip") }, var.tags, )
}

#---------------------------------------------
# Azure Bastion Service host
#---------------------------------------------
resource "azurerm_bastion_host" "main" {
  name                = var.azure_bastion_service_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "${var.azure_bastion_service_name}-network"
    subnet_id            = azurerm_subnet.abs_snet.0.id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

