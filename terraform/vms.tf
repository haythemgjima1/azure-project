resource "azurerm_network_interface" "tier" {
  for_each            = local.tiers
  name                = "nic-${each.value.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tier[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = each.key == "web" ? azurerm_public_ip.web.id : null
  }
}

resource "azurerm_linux_virtual_machine" "tier" {
  for_each                        = local.tiers
  name                            = each.value.vm_name
  computer_name                   = each.value.vm_name
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = each.key == "web" ? var.web_vm_size : var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.tier[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = each.key == "db" ? base64encode(templatefile("${path.module}/cloud-init/db.yaml", {
    db_password = var.db_password
    })) : base64encode(templatefile("${path.module}/cloud-init/${each.key}.yaml", {
    repo_url    = var.repo_url
    app_subdir  = var.app_subdir
    db_password = var.db_password
  }))

  depends_on = [
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.private,
    azurerm_subnet_network_security_group_association.tier
  ]
}
