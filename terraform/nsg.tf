locals {
  nsg_rules = {
    web = [
      {
        name              = "allow-http-https"
        priority          = 100
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = "Internet"
        destination_ports = ["80", "443"]
      },
      {
        name              = "allow-admin-ssh"
        priority          = 110
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = var.admin_ip_cidr
        destination_ports = ["22"]
      },
      {
        name              = "deny-all-inbound"
        priority          = 4096
        access            = "Deny"
        protocol          = "*"
        source_prefix     = "*"
        destination_ports = ["*"]
      }
    ]
    app = [
      {
        name              = "allow-web-api"
        priority          = 100
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = "10.1.1.0/24"
        destination_ports = ["5000"]
      },
      {
        name              = "allow-web-ssh"
        priority          = 110
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = "10.1.1.0/24"
        destination_ports = ["22"]
      },
      {
        name              = "deny-all-inbound"
        priority          = 4096
        access            = "Deny"
        protocol          = "*"
        source_prefix     = "*"
        destination_ports = ["*"]
      }
    ]
    db = [
      {
        name              = "allow-app-mysql"
        priority          = 100
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = "10.2.1.0/24"
        destination_ports = ["3306"]
      },
      {
        name              = "allow-app-ssh"
        priority          = 110
        access            = "Allow"
        protocol          = "Tcp"
        source_prefix     = "10.2.1.0/24"
        destination_ports = ["22"]
      },
      {
        name              = "deny-all-inbound"
        priority          = 4096
        access            = "Deny"
        protocol          = "*"
        source_prefix     = "*"
        destination_ports = ["*"]
      }
    ]
  }
}

resource "azurerm_network_security_group" "tier" {
  for_each            = local.tiers
  name                = each.value.nsg_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  dynamic "security_rule" {
    for_each = local.nsg_rules[each.key]
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.destination_ports
      source_address_prefix      = security_rule.value.source_prefix
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "tier" {
  for_each                  = local.tiers
  subnet_id                 = azurerm_subnet.tier[each.key].id
  network_security_group_id = azurerm_network_security_group.tier[each.key].id
}
