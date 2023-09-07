#!/bin/bash
# $1 = master_node_ip
# $2 = worker_node_ip
# $3 = ssh_key_path

scp -i $3 root@$1:k8s/join.sh  root@$2:k8s/join.sh
ssh -i $3 root@$2 "bash k8s/join.sh"