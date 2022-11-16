output "web-subnetid" {
  value = azurerm_subnet.web-subnet.id
}
output "db-subnetid" {
  value = azurerm_subnet.db-subnet.id
}