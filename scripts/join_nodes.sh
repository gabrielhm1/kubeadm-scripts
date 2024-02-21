#!/bin/bash
# $1 = Master Node IP
# $2 = Worker Node IP
# $3 = SSH Key Path

scp -o StrictHostKeyChecking=no -i $3 root@$1:k8s/join.sh  root@$2:k8s/join.sh
ssh -o StrictHostKeyChecking=no -i $3 root@$2 "bash k8s/join.sh"