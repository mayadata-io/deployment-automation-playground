#!/bin/bash
set -e

DIR=$PWD

echo "- Starting VPN"
$DIR/workspace/start_vpn.sh
sleep 2

#if [ -d mayastor ]; then
#  cd mayastor
#  git pull
#else
#  git clone https://github.com/openebs/mayastor.git
#  cd mayastor
#fi

#cd scripts
#./generate-deploy-yamls.sh -c 2 -o $DIR/workspace/deploy release

cd $DIR/workspace
export KUBECONFIG=$PWD/admin.conf

for i in `crudini --get --list inventory.ini mayastor_storage`; do
  echo "- Label node $i"
  kubectl label nodes $i openebs.io/engine=mayastor --overwrite
done
sleep 10

#for i in `crudini --get --list inventory.ini kubemaster`; do
#  kubectl cordon $i
#done

echo "- Create namespace"
if [[ ! `kubectl get namespaces |grep mayastor|grep Active` ]]; then
  kubectl create namespace mayastor
fi
#echo "- Create CRDs"
#kubectl apply -f https://raw.githubusercontent.com/openebs/Mayastor/master/csi/moac/crds/mayastorpool.yaml

MANIFESTS="moac-rbac.yaml nats-deployment.yaml csi-daemonset.yaml moac-deployment.yaml mayastor-daemonset.yaml etcd/statefulset.yaml etcd/svc.yaml etcd/svc-headless.yaml"
for i in $MANIFESTS; do
  echo "- Apply manifest $i"
  kubectl apply -f $DIR/workspace/Jul26/$i
  sleep 1
done

echo "- Wait for all Mayastor pods to come up"
B=0
while [ $B -eq 0 ]; do
  B=1
  out="$(kubectl get pods -n mayastor --no-headers)"
  printf "."
  echo "$out"|while IFS= read -r i; do
    STATUS=$(echo "$i"|awk '{print $2}')
    L=$(echo $STATUS|awk -F'/' '{print $1}')
    R=$(echo $STATUS|awk -F'/' '{print $NF}')
    #echo "$STATUS $L $R"
    if [ "$L" != "$R" ]; then
      B=0
    fi
    #echo $B
  done
  sleep 2
done
echo 

echo "- Verify all CRDs are present"
B=0
while [ $B -eq 0 ]; do
  B=1
  for i in mayastornodes mayastorpools mayastorvolumes; do
    if [[ ! `kubectl get crd --no-headers | grep $i` ]]; then
      B=0
    fi
  done
  printf "."
  sleep 2
done
echo
echo "- Mayastor is online"
sleep 10

echo "- Verify MSNs are online"
while [ `kubectl -n mayastor get msn --no-headers 2> /dev/null|grep online|wc -l` != 3 ]; do
  sleep 2
  printf "."
done
echo

MANIFESTS="storage_pool.yaml sc.yaml pvc.yaml"
for i in $MANIFESTS; do
  echo "Apply manifest $i"
  kubectl apply -f $DIR/workspace/Jul26/$i
  sleep 2
done
sleep 10

echo "- Verify MSPs are online"
while [ `kubectl -n mayastor get msp --no-headers 2> /dev/null|grep online|wc -l` != 3 ]; do
  sleep 2
  printf "."
done
echo


#echo "- Deploy openebs-monitoring"
#helm repo add openebs-monitoring https://openebs.github.io/monitoring/
#helm install monitoring openebs-monitoring/openebs-monitoring --namespace mayastor
#NODE_PORT=32515
#NODE_NAME=$(kubectl get pods --namespace mayastor -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -o jsonpath="{.items[0].spec.nodeName}")
#NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath='{$.status.addresses[?(@.type=="InternalIP")].address}')

#echo "- Start prep jobs"
#kubectl apply -f $DIR/workspace/Jul26/prep.yaml
#sleep 5
#
#
#echo "- Wait for prep jobs to finish"
#while [ `kubectl get pods --no-headers|wc -l` != 0 ]; do
#  printf "."
#  sleep 2
#done
#printf "\n"
#
#echo "- Create demo deployments"
#kubectl apply -f $DIR/workspace/Jul26/depl.yaml
#
#echo "- Access monitoring at http://$NODE_IP:$NODE_PORT"

