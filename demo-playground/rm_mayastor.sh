#!/bin/bash
set -ev

DIR=$PWD

MANIFESTS="etcd/svc.yaml etcd/svc-headless.yaml etcd/statefulset.yaml mayastor-daemonset.yaml moac-deployment.yaml csi-daemonset.yaml nats-deployment.yaml mayastorpool.yaml moac-rbac.yaml"
for i in $MANIFESTS; do
  echo "- Delete $i" 
  kubectl delete -f $DIR/workspace/master/$i
  sleep 1
done

