locals {
  ssh_private_key_path = trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")
}

output "web_public_ip" {
  description = "Public IPv4 address of vm-web."
  value       = azurerm_public_ip.web.ip_address
}

output "resource_group_name" {
  description = "Resource group containing the project."
  value       = azurerm_resource_group.main.name
}

output "web_fqdn" {
  description = "DNS name of the public web endpoint."
  value       = azurerm_public_ip.web.fqdn
}

output "ssh_commands" {
  description = "SSH commands for web, app, and the two-hop DB jump through web and app."
  value = join("\n", [
    "Web: ssh -i '${local.ssh_private_key_path}' azureuser@${azurerm_public_ip.web.fqdn}",
    "App: ssh -i '${local.ssh_private_key_path}' -J azureuser@${azurerm_public_ip.web.fqdn} azureuser@10.2.1.4",
    "DB:  ssh -i '${local.ssh_private_key_path}' -J azureuser@${azurerm_public_ip.web.fqdn},azureuser@10.2.1.4 azureuser@10.3.1.4"
  ])
}

output "ssh_private_key_path" {
  description = "Expanded private key path used by verify.sh."
  value       = local.ssh_private_key_path
}

output "mysql_paas_fqdn" {
  description = "Private FQDN of the Azure Database for MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "mysql_paas_private_ip" {
  description = "Private Endpoint IP of Azure Database for MySQL inside subnet-db."
  value       = azurerm_private_endpoint.mysql.private_service_connection[0].private_ip_address
}
