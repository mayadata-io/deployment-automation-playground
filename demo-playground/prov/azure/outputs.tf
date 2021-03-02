### The Ansible inventory file
resource "local_file" "AnsibleInventory" {
  content = templatefile("../inventory.tmpl",
  {
    setup_name = var.setup_name
    bastion-ip = azurerm_public_ip.pub-ip.0.ip_address
    master-ip  = azurerm_network_interface.master-nic.*.private_ip_address
    storage-ip = azurerm_network_interface.storage-nic.*.private_ip_address
    worker-ip  = azurerm_network_interface.worker-nic.*.private_ip_address
    ssh_user   = var.ssh_user
    ssh_key    = var.ssh_private_key
    msp_disk   = var.storage_nodes.msp
    k8s        = var.k8s_installer
  })
 filename = "inventory.ini"
}

resource "local_file" "ssh_conf" {
  content = templatefile("../ssh.tmpl",
    {
      setup_name = var.setup_name
      bastion-ip = azurerm_public_ip.pub-ip.0.ip_address
      master-ip  = azurerm_network_interface.master-nic.*.private_ip_address
      storage-ip = azurerm_network_interface.storage-nic.*.private_ip_address
      worker-ip  = azurerm_network_interface.worker-nic.*.private_ip_address
      ssh_user   = var.ssh_user
      ssh_key    = var.ssh_private_key
    })
  filename = "ssh.cfg"
}
