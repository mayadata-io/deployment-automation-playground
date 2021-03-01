#!/bin/bash
set -ex -o pipefail

# required packages:
# - ansible 2.9.17
# - pip3

### PROVISIONING
function provisioning
{
  cd $DIR/prov/$PLATFORM

    #Create the provisioning tfvars file, if more vars are introduced, this will need to be expanded
  cat <<EOF >$DIR/workspace/prov.tfvars
setup_name = "$SETUP_NAME"
location = "$LOCATION"
ssh_user = "$SSH_USER"
ssh_private_key = "$SSH_KEY"
ssh_public_key = "$SSH_PUBKEY"
image = $OS_IMAGE
storage_nodes = $STORAGE_NODES
master_nodes = $MASTER_NODES
worker_nodes = $WORKER_NODES
EOF

  terraform init
  terraform apply -auto-approve -var-file="$DIR/workspace/prov.tfvars"

  cp -f $DIR/prov/$PLATFORM/inventory.ini $DIR/workspace/
  cp -f $DIR/prov/$PLATFORM/ssh.cfg $DIR/workspace/
}

function kubespray {
### K8S deployment
  cd $DIR
  if [ -d kubespray ]; then
    cd kubespray
  else
    git clone https://github.com/kubernetes-sigs/kubespray.git
    cd kubespray
  fi
  git checkout "$KSPRAY_RELEASE"
  pip3 install ansible==2.9.17
  pip3 install -r requirements.txt
  pip3 install openshift
  #TODO: move to virtualenv

  cp -rfp inventory/sample inventory/$SETUP_NAME
  cp -f $DIR/workspace/inventory.ini inventory/$SETUP_NAME/

  #Remove the bastion group, we don't want to confuse Kubespray
  sed -i '/^bastion/d' inventory/$SETUP_NAME/inventory.ini || echo "no bastion found"
  sed -i "s/kube_network_plugin: calico/kube_network_plugin: flannel/g" inventory/$SETUP_NAME/group_vars/k8s-cluster/k8s-cluster.yml
  sed -i "s/cluster_name: cluster.local/cluster_name: $SETUP_NAME.local/g" inventory/$SETUP_NAME/group_vars/k8s-cluster/k8s-cluster.yml

  # Deploy Kubespray
  ansible-playbook -i inventory/$SETUP_NAME/inventory.ini --become --become-user=root cluster.yml

  # Pull out kubeconfig
  cd $DIR/workspace
  sleep 5
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SSH_USER@$BASTION "sudo cat /etc/kubernetes/admin.conf" > admin.conf
  export KUBECONFIG="$DIR/workspace/admin.conf"
}

function k3s {
  cd $DIR
  if [ -d k3s-ansible ]; then
    cd k3s-ansible
  else
    git clone https://github.com/k3s-io/k3s-ansible.git
    cd k3s-ansible
  fi
  git checkout master
  pip3 install ansible==2.9.17

  cp -rfp inventory/sample inventory/$SETUP_NAME
  cp -f $DIR/workspace/inventory.ini inventory/$SETUP_NAME/

  ansible-playbook -i inventory/$SETUP_NAME/inventory.ini --become --become-user=root site.yml

  # Pull out kubeconfig
  cd $DIR/workspace
  sleep 5
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SSH_USER@$BASTION "sudo cat ~/.kube/config" > admin.conf
  export KUBECONFIG="$DIR/workspace/admin.conf"
}

function start_vpn { #Start VPN
  cd $DIR/deployments
  BASTION=$(grep -e '^bastion' $DIR/workspace/inventory.ini|awk -F'ansible_host=' '{ print $NF }'|awk '{ print $1 }')
  #ansible -m wait_for_connection -i $DIR/workspace/inventory.ini bastion
  ansible -m wait_for -a "timeout=300 port=22 host=$BASTION search_regex=OpenSSH" -i $DIR/workspace/inventory.ini -e ansible_connection=local bastion
  ansible-playbook -i $DIR/workspace/inventory.ini $DIR/deployments/bastion.yml
  pkill sshuttle || echo "sshuttle starting"
  nohup sshuttle -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -r $SSH_USER@$BASTION 10.0.1.0/24 &
  # Wait for all nodes to come up and become available
  #ansible -m wait_for_connection --forks 1 -vvvv -i $DIR/workspace/inventory.ini all
  ansible -m wait_for -a "timeout=300 port=22 host=$BASTION search_regex=OpenSSH" -i $DIR/workspace/inventory.ini -e ansible_connection=local all
  cd $DIR
}

### PREPARE NODES
function prep_nodes {
  cd $DIR/deployments
  cp -f $DIR/workspace/ssh.cfg .

  #Create the vars file, if more variables are introduced, this will need to be extended
  cat <<EOF >$DIR/workspace/ansible_vars.yml
kernel_settings_sysctl:
  - name: vm.nr_hugepages
    value: $NR_HUGEPAGES
kernel_settings_sysfs:
  - name: /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
    value: $NR_HUGEPAGES
DIR: "$DIR"
limits:
  cpu: "$CPU_LIMIT"
  memory: "$MEMORY_LIMIT"
  hugepages2Mi: "$HUGEPAGES_2MI"
storage_protocol: "$STORAGE_PROTOCOL"
replica_count: $REPLICA_COUNT
pvc: $PVC
project_namespace: "$PROJECT_NAMESPACE"
run_fio: $RUN_FIO
EOF

  #Install prerequisite roles and collections
  ansible-galaxy collection install --force-with-deps -p ./collections community.kubernetes
  ansible-galaxy role install --force-with-deps -p ./roles linux-system-roles.kernel_settings

  ansible-playbook -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/ansible_vars.yml" node-config.yml
}

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}
STARTTIME=$(date +%s)
DIR=${PWD}
if [ ! -d workspace ]; then mkdir workspace; fi
source $DIR/vars

for s in $STAGES; do
  if [[ "$s" == "prov" ]]; then
    provisioning
  fi
done

for s in $STAGES; do
  if [[ "$s" == "start_vpn" ]]; then
    start_vpn
  fi
done

for s in $STAGES; do
  if [[ "$s" == "k8s" ]]; then
    $K8S_INSTALLER
  fi
done

if [ ! -f $DIR/workspace/admin.conf ]; then
  echo "Missing admin.conf, please download it from the K8S master node, usually under /etc/kubernetes or a user's ~/.kube/config"
  exit 1
fi
prep_nodes

for p in $PLAYBOOKS; do
  cd $DIR/deployments
  ansible-playbook -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/ansible_vars.yml" $p
done


ENDTIME=$(date +%s)
RUNTIME=$(($ENDTIME - $STARTTIME))
secs_to_human $RUNTIME


