resource "azurerm_virtual_network" "vnet" {
  name                = "myazvnet"
  address_space       = ["10.172.0.0/16"]
  location            = var.location
  resource_group_name = var.name
}

resource "azurerm_subnet" "web-subnet" {
  name                 = "AppSubnet"
  resource_group_name  = var.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.172.10.0/24"]
}
resource "azurerm_subnet" "db-subnet" {
  name                 = "DBSubnet"
  resource_group_name  = var.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.172.20.0/24"]
}

