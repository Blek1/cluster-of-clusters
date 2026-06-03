#!/bin/bash
set -e


export KARMADA_APISERVERCONFIG=~/.kube/config
export KARMADA_APISERVERIP=127.0.0.1
cd clusterloader2/
go run cmd/clusterloader.go --testconfig=config.yaml --provider=local --kubeconfig=$KARMADA_APISERVERCONFIG --v=2 --k8s-clients-number=1 --skip-cluster-verification=true --masterip=$KARMADA_APISERVERIP --enable-exec-service=false