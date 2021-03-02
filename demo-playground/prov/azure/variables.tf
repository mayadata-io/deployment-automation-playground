variable "setup_name" {
  type        = string
  description = "Name for the setup, all the resources will have their own names prepended with it"
  default     = "demo"
}

variable "location" {
  type = string
  description = "Azure location for the setup"
  default = "eastus"
}

variable "k8s_installer" {
  type = string
  default = "None"
}

# find other images with az vm image list --all --publisher OpenLogic --offer CentOS
variable "image" {
  description = "Image details for the cluster nodes"
  type = object({
    publisher      = string
    offer          = string
    sku            = string
    version        = string
  })
  default = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_3-gen2"
    version   = "latest"
  }
}
#ssh connection vars
variable "ssh_user" {
  type = string
  default = "demo-user"
}

variable "ssh_private_key" {
  description = "The private key to use when connecting to the instances."
  type        = string
  default = "~/.ssh/id_rsa"
}

variable "ssh_public_key" {
  description = "SSH public key to be use when creating the instances."
  type        = string
  default = "~/.ssh/id_rsa.pub"
}

# Mayastor node vars
variable "storage_nodes" {
  description = "Mayastor storage node properties"
  type = object({
    count        = string
    type         = string
    os_disk_size = string
    msp          = string
  })
  default = {
    count = 3
    type = "Standard_L8s_v2"
    os_disk_size = 40
    msp = "/dev/nvme0n1"
  }
}

# k8s master node vars
variable "master_nodes" {
  description = "Mayastor master node properties"
  type = object({
    count        = string
    type         = string
    os_disk_size = string
  })
  default = {
    count = 1
    type = "Standard_D2s_v4"
    os_disk_size = 50
  }
}

# k8s client worker node vars
variable "worker_nodes" {
  description = "Mayastor worker node properties"
  type = object({
    count        = string
    type         = string
    os_disk_size = string
  })
  default = {
    count = 3
    type = "Standard_D8s_v4"
    os_disk_size = 40
  }
}


