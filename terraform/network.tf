locals {
  tiers = {
    web = {
      vnet_name   = "vnet-web"
      subnet_name = "subnet-web"
      vm_name     = "vm-web"
      nsg_name    = "nsg-web"
      vnet_cidr   = "10.1.0.0/16"
      subnet_cidr = "10.1.1.0/24"
      private_ip  = "10.1.1.4"
    }
    app = {
      vnet_name   = "vnet-app"
      subnet_name = "subnet-app"
      vm_name     = "vm-app"
      nsg_name    = "nsg-app"
      vnet_cidr   = "10.2.0.0/16"
      subnet_cidr = "10.2.1.0/24"
      private_ip  = "10.2.1.4"
    }
    db = {
      vnet_name   = "vnet-db"
      subnet_name = "subnet-db"
      vm_name     = "vm-db"
      nsg_name    = "nsg-db"
      vnet_cidr   = "10.3.0.0/16"
      subnet_cidr = "10.3.1.0/24"
      private_ip  = "10.3.1.4"
    }
  }

  private_tiers = {
    for name, tier in local.tiers : name => tier if name != "web"
  }

  peerings = {
    web-to-app = { local = "web", remote = "app" }
    app-to-web = { local = "app", remote = "web" }
    app-to-db  = { local = "app", remote = "db" }
    db-to-app  = { local = "db", remote = "app" }
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-miniprojet-${var.students}"
  location = var.location
}

resource "azurerm_virtual_network" "tier" {
  for_each            = local.tiers
  name                = each.value.vnet_name
  address_space       = [each.value.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "tier" {
  for_each                        = local.tiers
  name                            = each.value.subnet_name
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.tier[each.key].name
  address_prefixes                = [each.value.subnet_cidr]
  default_outbound_access_enabled = each.key == "web"
}

resource "azurerm_public_ip" "web" {
  name                = "pip-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "miniprojet-${var.students}"
}

resource "azurerm_public_ip" "nat" {
  for_each            = local.private_tiers
  name                = "pip-nat-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "private" {
  for_each                = local.private_tiers
  name                    = "nat-${each.key}"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "private" {
  for_each             = local.private_tiers
  nat_gateway_id       = azurerm_nat_gateway.private[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  for_each       = local.private_tiers
  subnet_id      = azurerm_subnet.tier[each.key].id
  nat_gateway_id = azurerm_nat_gateway.private[each.key].id

  depends_on = [azurerm_subnet_network_security_group_association.tier]
}

resource "azurerm_virtual_network_peering" "tier" {
  for_each                     = local.peerings
  name                         = "peer-${each.key}"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.tier[each.value.local].name
  remote_virtual_network_id    = azurerm_virtual_network.tier[each.value.remote].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [
    azurerm_subnet_network_security_group_association.tier,
    azurerm_subnet_nat_gateway_association.private
  ]
}
