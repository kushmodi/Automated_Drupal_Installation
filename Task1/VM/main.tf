# Dynamic private key and public key resource
resource "tls_private_key" "ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "web-vault" {
  name                       = "web-secret-key"
  location                   = var.location
  resource_group_name        = var.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge",
      "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey",
    ]

    secret_permissions = [
      "Get", "Set", "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore"
    ]

    storage_permissions = [
      "Get","Backup", "Delete", "Get", "List", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "Update",
    ]
  }
}

resource "azurerm_key_vault_secret" "secret-key" {
  key_vault_id = azurerm_key_vault.web-vault.id
  name         = "private-key"
  value        = tls_private_key.ssh-key.private_key_pem
}

# NIC for Both VM
resource "azurerm_network_interface" "web-nic" {
  count               = var.create_vm_count
  name                = "nicwebvm-${count.index}"
  location            = var.location
  resource_group_name = var.name

  ip_configuration {
    name                          = "web-internal-${count.index}"
    subnet_id                     = var.web-sub_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web-public_ip[count.index].id
  }

}

# NSG association with NIC

resource "azurerm_network_interface_security_group_association" "web-nsg-as" {
  count                     = var.create_vm_count
  network_interface_id      = azurerm_network_interface.web-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.web-nsg[count.index].id
}

# NIC resource

resource "azurerm_network_interface" "db-nic" {
  name                = "nicdbvm"
  location            = var.location
  resource_group_name = var.name

  ip_configuration {
    name                          = "db-internal"
    subnet_id                     = var.db-sub_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.db-public_ip.id
  }

}

#NSG association with NIC

resource "azurerm_network_interface_security_group_association" "db-nsg-as" {
  network_interface_id      = azurerm_network_interface.db-nic.id
  network_security_group_id = azurerm_network_security_group.db-nsg.id
}

# NSG for both VM

resource "azurerm_network_security_group" "web-nsg" {
  count               = var.create_vm_count
  name                = "Networksecuritygrpvm-${count.index}"
  location            = var.location
  resource_group_name = var.name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


resource "azurerm_network_security_group" "db-nsg" {
  depends_on = [azurerm_linux_virtual_machine.web-server]
  name                = "Networksecuritygrpvm2"
  location            = var.location
  resource_group_name = var.name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "MySQL"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefixes      = azurerm_linux_virtual_machine.web-server.*.public_ip_address
    destination_address_prefixes = [azurerm_linux_virtual_machine.database-server.public_ip_address]
  }
}

# Public IP for both VM

resource "azurerm_public_ip" "web-public_ip" {
  count               = var.create_vm_count
  name                = "web_public_ip-${count.index}"
  resource_group_name = var.name
  location            = var.location
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "db-public_ip" {
  name                = "db_public_ip"
  resource_group_name = var.name
  location            = var.location
  allocation_method   = "Dynamic"
}

# Virtual machine for web server
resource "azurerm_linux_virtual_machine" "web-server" {
  count                           = var.create_vm_count
  location                        = var.location
  name                            = "Webvm-${count.index}"
  network_interface_ids           = [azurerm_network_interface.web-nic[count.index].id]
  resource_group_name             = var.name
  size                            = "Standard_DS1"
  disable_password_authentication = true


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_username = var.username
  computer_name  = "web-server"

  connection {
    type     = "ssh"
    user     = var.username
    private_key = azurerm_key_vault_secret.secret-key.value
    host     = self.public_ip_address
  }
  admin_ssh_key {
    public_key = tls_private_key.ssh-key.public_key_openssh
    username   = var.username
  }
}



# Virtual machine for database server

resource "azurerm_linux_virtual_machine" "database-server" {
  depends_on = [azurerm_linux_virtual_machine.web-server]
  location                        = var.location
  name                            = "DBvm"
  network_interface_ids           = [azurerm_network_interface.db-nic.id]
  resource_group_name             = var.name
  size                            = "Standard_DS1"
  disable_password_authentication = true


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name  = "database-server"
  admin_username = var.username

  connection {
    type     = "ssh"
    user     = var.username
    private_key = azurerm_key_vault_secret.secret-key.value
    host     = self.public_ip_address
  }
  admin_ssh_key {
    public_key = tls_private_key.ssh-key.public_key_openssh
    username   = var.username
  }
}

#Creating inventory file dynamically
 resource "local_file" "ip" {
  #depends_on = [azurerm_linux_virtual_machine.web-server, azurerm_linux_virtual_machine.database-server]
  filename   = "../ansible/host.ini"
  content    = <<-EOT
 [webservers]
  %{for ip in azurerm_linux_virtual_machine.web-server.*.public_ip_address~}
     ${ip} ansible_ssh_user=${var.username} ansible_connection=ssh
    %{endfor~}

[DBservers]
ansible_ssh_host=${azurerm_linux_virtual_machine.database-server.public_ip_address} ansible_ssh_user=${var.username} ansible_connection=ssh
EOT

}

# Null resource to run ansible playbook

/*resource "null_resource" "example" {
  depends_on = [local_file.ip]
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=${azurerm_key_vault_secret.secret-key.value} -i ../ansible/host.ini ../ansible/playbook.yaml"
  }
} */


