#!/bin/bash
# required packages:
# - ansible 2.9.17
# - pip3
# - kubectl
# - helm
# - helm-diff (helm plugin install https://github.com/databus23/helm-diff)

### PROVISIONING
function provisioning
{
  echo Provisioning VMs on $PLATFORM
  cd $DIR/prov/$PLATFORM

  if [[ ! "$STAGES" == *" k8s "* ]]; then  # If k8s is not in the STAGES list
    K8S_INSTALLER="None"
  fi

  #Create the provisioning tfvars file, if more vars are introduced, this will need to be expanded
  cat <<EOF >$DIR/workspace/prov.tfvars
k8s_installer = "$K8S_INSTALLER"
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
  echo "Installing Kubespray $KSPRAY_RELEASE"
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
  ansible-playbook -i inventory/$SETUP_NAME/inventory.ini --become --become-user=root -T 30 -f 1 cluster.yml

  # Pull out kubeconfig
  cd $DIR/workspace
  sleep 5
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SSH_USER@$BASTION "sudo cat /etc/kubernetes/admin.conf" > admin.conf
  KUBE_API=$(python -c "import yaml; \
            f=open('$DIR/workspace/admin.conf','r'); \
            y=yaml.safe_load(f); \
            print(y['clusters'][0]['cluster']['server'])"|awk -F':' '{ print $2 }')
  if [[ "$KUBE_API" == "//127.0.0.1" ]]; then
    MASTER="$(ansible-inventory -i $DIR/workspace/inventory.ini --host 'kube-master[0]' --toml|grep ansible_host|awk '{ print $NF }')"
    MASTER=`echo $MASTER|tr -d '"'`
    sed -i "s/127.0.0.1/$MASTER/g" $DIR/workspace/admin.conf
  fi
  export KUBECONFIG="$DIR/workspace/admin.conf"
}

function k3s {
  echo "Installing K3S"
  cd $DIR
  if [ -d k3s-ansible ]; then
    cd k3s-ansible
  else
    git clone https://github.com/k3s-io/k3s-ansible.git
    cd k3s-ansible
  fi
  git checkout master
  pip3 install ansible==2.9.17

  cat <<EOF > $DIR/workspace/k3s_vars.yml
k3s_version: $K3S_VERSION
ansible_user: $SSH_USER
systemd_dir: /etc/systemd/system
master_ip: "{{ hostvars[groups['master'][0]]['ansible_host'] | default(groups['master'][0]) }}"
extra_server_args: ""
extra_agent_args: "--node-name={{ inventory_hostname }}"
EOF

  ansible-playbook -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/k3s_vars.yml" site.yml

  # Pull out kubeconfig
  cd $DIR/workspace
  sleep 5
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $SSH_USER@$BASTION "sudo cat ~/.kube/config" > admin.conf
  export KUBECONFIG="$DIR/workspace/admin.conf"
}

function start_vpn { #Start sshuttle VPN
  # List of subnets to tunnel
  VPN_SUBNETS="10.0.1.0/24 10.244.0.0/16 10.42.0.0/16 10.43.0.0/16 10.233.0.0/16"

  cd $DIR/deployments
  BASTION=$(grep -e '^bastion' $DIR/workspace/inventory.ini|awk -F'ansible_host=' '{ print $NF }'|awk '{ print $1 }')
  echo "Setting up sshuttle VPN connection through $BASTION"
  #ansible -m wait_for_connection -i $DIR/workspace/inventory.ini bastion
  ansible -m wait_for -a "timeout=300 port=22 host=$BASTION search_regex=OpenSSH" -i $DIR/workspace/inventory.ini -e ansible_connection=local bastion
  ansible-playbook -i $DIR/workspace/inventory.ini $DIR/deployments/bastion.yml
  cat <<EOF > $DIR/workspace/start_vpn.sh
#!/bin/bash
set -e
pkill sshuttle || echo "sshuttle starting"
nohup sshuttle -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -r $SSH_USER@$BASTION $VPN_SUBNETS &
EOF
  #TODO: 10.0.0.0/8 could be smarter, but since we want to cover both 10.0.1.0/24 and the SDN, this will do for now
  chmod +x $DIR/workspace/start_vpn.sh
  $DIR/workspace/start_vpn.sh
  # Wait for all nodes to come up and become available
  ansible -m wait_for -a "timeout=300 port=22 host=$BASTION search_regex=OpenSSH" -i $DIR/workspace/inventory.ini -e ansible_connection=local all
  sleep 5
  ansible -m wait_for -a "delay=5 timeout=300 port=22 search_regex=OpenSSH" -i $DIR/workspace/inventory.ini -e ansible_connection=local all

  # ansible -m wait_for_connection -a "timeout=300 delay=1" -i $DIR/workspace/inventory.ini all
  # ansible -m ping -i $DIR/workspace/inventory.ini -T 120 all
  cd $DIR
}

### PREPARE NODES
function prep_nodes {
  echo "Running node_prep"
  cd $DIR/deployments
  cp -f $DIR/workspace/ssh.cfg .

  #Create the vars file, if more variables are introduced, this will need to be extended
  cat <<EOF >$DIR/workspace/ansible_vars.yml
nr_hugepages: $NR_HUGEPAGES
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
enable_iscsi: $ENABLE_ISCSI
EOF

  #Install prerequisite roles and collections
  ansible-galaxy collection install --force-with-deps -p ./collections community.kubernetes
  ansible-galaxy collection install --force-with-deps -p ./collections community.general
  ansible-galaxy role install --force-with-deps -p ./roles linux-system-roles.kernel_settings

  ansible-playbook -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/ansible_vars.yml" node-config.yml
}

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}

#MAIN

STARTTIME=$(date +%s)
DIR=${PWD}
if [ ! -d workspace ]; then mkdir workspace; fi
if [ -n "$1" ]; then 
  if [ -f "$1" ]; then source "$1"; else echo "$1 not found, exiting"; exit 1; fi
else 
  source "$DIR/vars" 
fi
if [[ "$DEBUG_OUTPUT" == "true" ]]; then
  set -ex -o pipefail
else
  set -e -o pipefail
fi

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

for s in $STAGES; do
  if [[ "$s" == "prep_nodes" ]]; then
    prep_nodes
  fi
done

echo "Finished stages $STAGES"

for p in $PLAYBOOKS; do
  cd $DIR/deployments
  ansible-playbook -vv -i $DIR/workspace/inventory.ini -e "@$DIR/workspace/ansible_vars.yml" $p
done

ENDTIME=$(date +%s)
RUNTIME=$(($ENDTIME - $STARTTIME))
secs_to_human $RUNTIME


