#!/bin/bash
set -ex -o pipefail

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}

STARTTIME=$(date +%s)

DIR="$PWD"
source $DIR/vars
cd $DIR/prov/$PLATFORM
terraform destroy -auto-approve -var-file=$DIR/workspace/prov.tfvars
cd $DIR
#rm -rf workspace kubespray k3s-ansible
ENDTIME=$(date +%s)
RUNTIME=$(($ENDTIME - $STARTTIME))
secs_to_human $RUNTIME
