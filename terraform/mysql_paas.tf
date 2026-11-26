resource "azurerm_mysql_flexible_server" "main" {
  name                          = "mysql-miniprojet-${var.students}-01"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  administrator_login           = "mysqladmin"
  administrator_password        = var.db_password
  sku_name                      = "B_Standard_B1ms"
  version                       = "8.0.21"
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access         = "Disabled"

  storage {
    size_gb = 20
  }
}

resource "azurerm_mysql_flexible_server_configuration" "tls_optional" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "OFF"
}

resource "azurerm_mysql_flexible_database" "university" {
  name                = "university_assignments"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  for_each              = local.private_tiers
  name                  = "link-mysql-${each.key}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.tier[each.key].id
}

resource "azurerm_private_endpoint" "mysql" {
  name                = "pe-mysql-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.tier["db"].id

  private_service_connection {
    name                           = "psc-mysql-db"
    private_connection_resource_id = azurerm_mysql_flexible_server.main.id
    subresource_names              = ["mysqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-mysql-db"
    private_dns_zone_ids = [azurerm_private_dns_zone.mysql.id]
  }
}
