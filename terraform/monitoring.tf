resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-miniprojet-${var.students}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "miniproj"
}

resource "azurerm_monitor_metric_alert" "web_high_cpu" {
  name                = "alert-vm-web-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.tier["web"].id]
  description         = "Alert when vm-web average CPU exceeds 80% over 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}
