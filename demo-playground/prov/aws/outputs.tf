### The Ansible inventory file
resource "local_file" "AnsibleInventory" {
  content = templatefile("../inventory.tmpl",
  {
    setup_name = var.setup_name
#    bastion-ip = aws_instance.master_node.0.public_ip
    bastion-ip = "${ length(aws_instance.master_node) > 0 ? aws_instance.master_node.0.public_ip : aws_instance.storage_node.0.public_ip }"
#    master-ip  = aws_instance.master_node.*.private_ip
    master-ip  = "${ length(aws_instance.master_node) > 0 ? aws_instance.master_node.*.private_ip : [] }"
    storage-ip = aws_instance.storage_node.*.private_ip
    worker-ip  = aws_instance.worker_node.*.private_ip
    ssh_user   = var.image.user
    ssh_key    = var.ssh_private_key
    msp_disk   = var.storage_nodes.msp
    k8s        = var.k8s_installer
    aio        = var.aio
  })
 filename = "inventory.ini"
}

#resource "local_file" "ssh_conf" {
#  content = templatefile("../ssh.tmpl",
#  {
#    setup_name = var.setup_name
#    bastion-ip = aws_instance.master_node.0.public_ip
#    master-ip  = aws_instance.master_node.*.private_ip
#    storage-ip = aws_instance.storage_node.*.private_ip
#    worker-ip  = aws_instance.worker_node.*.private_ip
#    ssh_user   = var.image.user
#    ssh_key    = var.ssh_private_key
#  })
#  filename = "ssh.cfg"
#}
