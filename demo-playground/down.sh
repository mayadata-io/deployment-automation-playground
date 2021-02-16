#!/bin/bash
set -ex -o pipefail

secs_to_human() {
    echo "$(( ${1} / 3600 ))h $(( (${1} / 60) % 60 ))m $(( ${1} % 60 ))s"
}

STARTTIME=$(date +%s)

DIR="$PWD"
source $DIR/vars
cd $DIR/prov/$PLATFORM
terraform destroy -auto-approve
cd $DIR
rm -rf workspace kubespray
ENDTIME=$(date +%s)
RUNTIME=$(($ENDTIME - $STARTTIME))
secs_to_human $RUNTIME
