#!/bin/bash
# basic cluster of clusters
set -e
for ((i=1; i<=10; i ++)); do
	kind create cluster --name member$i
done;

export GENERATE_REPLICAS=5
curl https://raw.githubusercontent.com/wzshiming/fake-kubelet/master/deploy.yaml > fakekubelet.yml
# GENERATE_REPLICAS default value is 5
# sed -i "" "s/5/$GENERATE_REPLICAS/g" fakekubelet.yml 
kubectl apply -f fakekubelet.yml