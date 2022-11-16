resource "azurerm_resource_group" "newrsgrp" {
  name     = var.name
  location = var.location
}

module "Vnet" {
  source          = "./Vnet"
  name            = azurerm_resource_group.newrsgrp.name
  location        = var.location
  create_vm_count = var.create_vm_count
}

module "vm" {
  source          = "./VM"
  name            = azurerm_resource_group.newrsgrp.name
  location        = var.location
  web-sub_id      = module.Vnet.web-subnetid
  db-sub_id         = module.Vnet.db-subnetid
  username        = var.username
  create_vm_count = var.create_vm_count
}
/* data "azurerm_virtual_machine" "my_data" {
  depends_on = [a]
  name                =  "Webvm"
  resource_group_name = var.name
}
data "azurerm_virtual_machine" "my_data1" {
  name                = "DBvm"
  resource_group_name = var.name
} */
