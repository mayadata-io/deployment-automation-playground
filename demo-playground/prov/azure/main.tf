provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = "${var.setup_name}-rg"
  location = var.location
  tags = {
    environment = var.setup_name
  }
}

resource "azurerm_virtual_network" "net" {
    name                = "${var.setup_name}-net"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    tags = {
        environment = var.setup_name
    }
}

resource "azurerm_subnet" "subnet" {
    name                 = "${var.setup_name}-subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.net.name
    address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "sg" {
    name                = "${var.setup_name}-sg"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name

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
    tags = {
        environment = var.setup_name
    }
}

resource "azurerm_subnet_network_security_group_association" "sg-association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.sg.id
}

# create storage VMs
resource "azurerm_network_interface" "storage-nic" {
  count               = var.storage_nodes.count
  name                = "${var.setup_name}-storage-nic-${format("%d", count.index + 1)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "${var.setup_name}-nic-conf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    //public_ip_address_id          = element(azurerm_public_ip.YugaByte_Public_IP.*.id, count.index)
  }

  tags = {
    environment = var.setup_name
  }
}

resource "azurerm_network_interface_security_group_association" "storage-nic-sg-association" {
  count                     = var.storage_nodes.count
  network_interface_id      = element(azurerm_network_interface.storage-nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_virtual_machine" "storage-node" {
  count                 = var.storage_nodes.count
  name                  = "${var.setup_name}-storage-${format("%d", count.index + 1)}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.storage-nic.*.id, count.index)]
  vm_size               = var.storage_nodes.type
  zones                 = ["1"]
  depends_on            = [azurerm_network_interface_security_group_association.storage-nic-sg-association]

  storage_os_disk {
    name              = "${var.setup_name}-storage-disk-${format("%d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = var.storage_nodes.os_disk_size
  }

  storage_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_profile {
    computer_name  = "${var.setup_name}-storage-${format("%d", count.index + 1)}"
    admin_username = var.ssh_user
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.ssh_user}/.ssh/authorized_keys"
      key_data = file(var.ssh_public_key)
    }
  }

  tags = {
    environment = var.setup_name
  }
}

# create master VMs
resource "azurerm_public_ip" "pub-ip" {
  count               = var.master_nodes.count
  name                = "${var.setup_name}-pub-ip-${format("%d", count.index)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]

  tags = {
    environment = var.setup_name
  }
}

resource "azurerm_network_interface" "master-nic" {
  count               = var.master_nodes.count
  name                = "${var.setup_name}-master-nic-${format("%d", count.index + 1)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.setup_name}-nic-conf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.pub-ip.*.id, count.index)
  }

  tags = {
    environment = var.setup_name
  }
}

resource "azurerm_network_interface_security_group_association" "master-nic-sg-association" {
  count                     = var.master_nodes.count
  network_interface_id      = element(azurerm_network_interface.master-nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_virtual_machine" "master-node" {
  count                 = var.master_nodes.count
  name                  = "${var.setup_name}-master-${format("%d", count.index + 1)}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.master-nic.*.id, count.index)]
  vm_size               = var.master_nodes.type
  zones                 = ["1"]
  depends_on            = [azurerm_network_interface_security_group_association.master-nic-sg-association]

  storage_os_disk {
    name              = "${var.setup_name}-master-disk-${format("%d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = var.master_nodes.os_disk_size
  }

  storage_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_profile {
    computer_name  = "${var.setup_name}-master-${format("%d", count.index + 1)}"
    admin_username = var.ssh_user
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.ssh_user}/.ssh/authorized_keys"
      key_data = file(var.ssh_public_key)
    }
  }

  tags = {
    environment = var.setup_name
  }
}

# create worker VMs
resource "azurerm_network_interface" "worker-nic" {
  count               = var.worker_nodes.count
  name                = "${var.setup_name}-worker-nic-${format("%d", count.index + 1)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "${var.setup_name}-nic-conf"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  //  public_ip_address_id          = element(azurerm_public_ip.pub-ip.*.id, count.index)
  }

  tags = {
    environment = var.setup_name
  }
}

resource "azurerm_network_interface_security_group_association" "worker-nic-sg-association" {
  count                     = var.worker_nodes.count
  network_interface_id      = element(azurerm_network_interface.worker-nic.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.sg.id
}

resource "azurerm_virtual_machine" "worker-node" {
  count                 = var.worker_nodes.count
  name                  = "${var.setup_name}-worker-${format("%d", count.index + 1)}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.worker-nic.*.id, count.index)]
  vm_size               = var.worker_nodes.type
  zones                 = ["1"]
  depends_on            = [azurerm_network_interface_security_group_association.worker-nic-sg-association]

  storage_os_disk {
    name              = "${var.setup_name}-worker-disk-${format("%d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = var.worker_nodes.os_disk_size
  }

  storage_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_profile {
    computer_name  = "${var.setup_name}-worker-${format("%d", count.index + 1)}"
    admin_username = var.ssh_user
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.ssh_user}/.ssh/authorized_keys"
      key_data = file(var.ssh_public_key)
    }
  }

  tags = {
    environment = var.setup_name
  }
}
