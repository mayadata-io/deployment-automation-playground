# E2E automation framework

This is a set of scripts that provision cloud instances, deploy K8S, tune nodes and deploy mayastor and other platforms

Provisioning is done via Terraform
The rest is done by Ansible
The glue script representing a pipeline is `up.sh`

## General approach

Each part of the process can be decoupled from the rest. We can skip provisioning or K8S installation if we have a working inventory for ansible plays to use, and a working Kubernetes setup for example.

All we require is ssh connectivity to the first master node in the inventory. It is used as the bastion host for `sshuttle` which provides VPN-like functionality right into the private network. If the host executing the scripts is already local to the rest of the setup, remove the `start_vpn` stage from `STAGES`

## Workflow

### Provision a cluster, deploy mayastor

1. Edit the `vars` file.
2. Run `up.sh`
3. Wait...

### Teardown the setup

Run `down.sh`

### `vars` file settings

The file is heavily commented, please review it before running `up.sh`

Important:

- Set the STAGES to execute, if provisioning is selected, set the platform and it's __specific variables__.
- If k8s install is selected, set the K8S_INSTALLER type.
- Add the playbooks you wish to apply in the PLAYBOOKS variable (in the order you want them to be applied)

## Skipping stages

Any stage can be skipped. If a stage is skipped, the setup might be missing certain files that would need to be added manually.

#### Skipped provisioning

If the provisioning stage is skipped (you are installing on baremetal or on your own, already installed set of VMs), a manually created inventory needs to be placed in the `workspace` directory.

Here is an example `workspace/inventory.ini`:

```
# general host configuration and per-host variables
[all]
maya-demo-master-0 ansible_host=10.0.1.69 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
maya-demo-worker-0 ansible_host=10.0.1.102 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
maya-demo-worker-1 ansible_host=10.0.1.100 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
maya-demo-worker-2 ansible_host=10.0.1.54 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

# the nodes containing storage need to have an additonal msp_disk variable pointing to the device that Mayastor will use. For now it can be a single disk only
maya-demo-storage-0 ansible_host=10.0.1.132 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' msp_disk='/dev/nvme1n1'
maya-demo-storage-1 ansible_host=10.0.1.228 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' msp_disk='/dev/nvme1n1'
maya-demo-storage-2 ansible_host=10.0.1.219 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' msp_disk='/dev/nvme1n1'

# Bastion host for remote access, typically the public IP of the first master node. Can be skipped if the nodes are local to the ansible executor.
bastion ansible_host=3.89.245.139 ansible_user=centos ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

# Kubespray inventory - add only if kubespray will be used
[kube-master]
maya-demo-master-0

[etcd]
maya-demo-master-0
maya-demo-worker-0
maya-demo-worker-1

[kube-node]
maya-demo-worker-0
maya-demo-worker-1
maya-demo-worker-2
maya-demo-storage-0
maya-demo-storage-1
maya-demo-storage-2

[calico-rr]

[k8s-cluster:children]
kube-master
kube-node

# K3S inventory - add only if K3S is going to be used
[master]
maya-demo-master-0

[node]
maya-demo-worker-0
maya-demo-worker-1
maya-demo-worker-2
maya-demo-storage-0
maya-demo-storage-1
maya-demo-storage-2

[k3s_cluster:children]
master
node

# Mayastor inventory (we need to separate between client workers and storage workers in this one)
[mayastor_clients]
maya-demo-worker-0
maya-demo-worker-1
maya-demo-worker-2

[mayastor_storage]
maya-demo-storage-0
maya-demo-storage-1
maya-demo-storage-2

```

#### Skipped Kubernetes install

In case K8S install stage is skipped (using GKE, or already running your own K8S for example) we will need to add the kubeconfig credentials file as `workspace/admin.conf`

## Extending this framework

- Additional plays can be added to the `deployments` directory, and optionally added to `vars` in the `PLAYBOOKS` variable.
- Additional cloud platforms can be implemented under `prov/PLATFORM_NAME` as long as the TF code builds the same format of `inventory.ini`.
- Different Kubernetes (and Openshift) deployments and distributions can be added to `up.sh` as a function and triggered via the `vars` file `K8S_INSTALLER` variable.
- The `STAGES` variable describes the stages, and if a stage is to be skipped, it can be removed in `vars`.

