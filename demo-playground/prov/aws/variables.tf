variable "setup_name" {
  type        = string
  description = "Name for the setup, all the resources will have their own names prepended with it"
  default     = "demo"
}

variable "location" {
  type = string
  description = "AWS Region name for the setup"
  default = "us-east-1"
}

variable "k8s_installer" {
  type = string
  default = "None"
}

# Centos AMIs per AZ: https://wiki.centos.org/Cloud/AWS
# Ubuntu AMIs per AZ: https://cloud-images.ubuntu.com/locator/ec2/
variable "image" {
  description = "Image details for the cluster nodes - different AZs will require different AMIs"
  type = object({
    ami_id = string
    user   = string
  })
  default = {
    ami_id = "ami-0d6e9a57f6259ba3a"
    user   = "centos"
  }
}
#ssh connection vars
#ssh username is default in the AMI, we will use image.user
variable "ssh_user" {
  type = string
  default = "user"
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
    type = "i3.2xlarge"
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
    type = "m5.2xlarge"
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
    type = "c5.2xlarge"
    os_disk_size = 40
  }
}


