#!/bin/bash

NODES=`kubectl get nodes|tail -n+2|awk '{ print $1 "_"  $2 }'`
printf "Detected nodes:\n$NODES\n"

while /bin/true; do
  NODES=`kubectl get nodes --no-headers|awk '{ print $1 "_"  $2 }'`
  printf "."
  for N in $NODES; do
    NODE=$(echo $N|awk 'BEGIN{FS=OFS="_"}{NF--; print}')
    STATE=$(echo $N|awk -F'_' '{print $NF}')
    if [ "$STATE" != 'Ready' ]; then
      printf "Node not ready: $NODE\n"
      VA="$(kubectl get volumeattachments --output=custom-columns='NAME:.metadata.name,NODE:.spec.nodeName' --no-headers|grep $NODE)"
      for A in "$VA"; do
        ANAME="$(echo "$A"|awk '{ print $1 }')"
        printf "deleting VA $ANAME\n"; kubectl delete volumeattachments $ANAME --force
      done
      kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data
      kubectl cordon $NODE
    fi
  done
  sleep 5 
done
