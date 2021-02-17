#!/bin/bash
set -ex -o pipefail

# required packages:
# - ansible 2.9.17
# - pip3
# - crudini

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}

STARTTIME=$(date +%s)

DIR=${PWD}
if [ ! -d workspace ]; then mkdir workspace; fi
source $DIR/vars

### PROVISIONING
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

### K8S deployment
cd $DIR
if [ -d kubespray ]; then
  cd kubespray
  git pull
else
  git clone https://github.com/kubernetes-sigs/kubespray.git
  cd kubespray
fi
git checkout "$KSPRAY_RELEASE"
pip3 install -r requirements.txt
pip3 install openshift
#TODO: move to virtualenv

cp -rfp inventory/sample inventory/$SETUP_NAME
cp -f $DIR/workspace/inventory.ini inventory/$SETUP_NAME/

#Remove the bastion group, we don't want to confuse Kubespray
sed -i '/^bastion/d' inventory/$SETUP_NAME/inventory.ini
sed -i "s/kube_network_plugin: calico/kube_network_plugin: flannel/g" inventory/$SETUP_NAME/group_vars/k8s-cluster/k8s-cluster.yml
sed -i "s/cluster_name: cluster.local/cluster_name: $SETUP_NAME.local/g" inventory/$SETUP_NAME/group_vars/k8s-cluster/k8s-cluster.yml

cp -f $DIR/workspace/ssh.cfg .
ACFG=$(crudini --get ansible.cfg ssh_connection ssh_args)

if [[ "$ACFG" != *"-F ./ssh.cfg"* ]]; then
  crudini --inplace --set ansible.cfg ssh_connection ssh_args "$ACFG -F ./ssh.cfg"
fi
crudini --inplace --set ansible.cfg ssh_connection control_path "~/.ssh/ansible-%%r@%%h:%%p"

# Wait for nodes to come up and become available
ansible -m wait_for_connection -i inventory/$SETUP_NAME/inventory.ini all

# Deploy Kubespray
ansible-playbook -i inventory/$SETUP_NAME/inventory.ini --become --become-user=root cluster.yml

### EXTRACT KUBECONFIG AND START VPN
cd $DIR/workspace
BASTION=$(grep -e '^bastion' inventory.ini|awk -F'ansible_host=' '{ print $NF }'|awk '{ print $1 }')
sudo pkill sshuttle || echo "sshuttle not active"
nohup sshuttle -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -r $SSH_USER@$BASTION 10.0.1.0/24 &
sleep 5
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SSH_USER@$BASTION "sudo cat /etc/kubernetes/admin.conf" > admin.conf
export KUBECONFIG="$DIR/workspace/admin.conf"

### PREPARE NODES
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

### Mayastor deployment
ansible-playbook -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/ansible_vars.yml" mayastor.yml
cd $DIR

ENDTIME=$(date +%s)
RUNTIME=$(($ENDTIME - $STARTTIME))
secs_to_human $RUNTIME


