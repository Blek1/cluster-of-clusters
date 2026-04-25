# Script Setup Notes

## Overview
These are notes about the automation scripts used to set up a Kubernetes environment using `kind` and `Karmada` what an automated `Prometheus` and `Grafana` stack for data.


## Cluster Setup
Spins up local Kubernetes clusters inside Docker containers. There is currently one host cluster for the karmada control plan and one worker cluster with 2 nodes.

### Commands & Documentation
* **`kind create cluster`**
    * **Documentation:** [kind Quick Start - Creating a Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
    * **What it does:** Downloads a Kubernetes node image and boots it as a Docker container. 
    * **Implementation Details:** The `--name` flag assigns a specific context name. For the worker cluster, the `--config` flag allows the use of a custom file to define specifics.
* **`kubectl config get-contexts`**
    * **Documentation:** [kubectl Cheat Sheet - Contexts](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-context-and-configuration)
    * **What it does:** Lists all available Kubernetes contexts in the `~/.kube/config` file to verify the clusters were successfully built and registered.


## Karmada Setup
Deploys the karmada host plane onto the host cluster and joins worker cluster to it, creating a cluster of clusters.

### Commands & Documentation
* **`karmadactl init`**
    * **Documentation:** [karmadactl init CLI Reference](https://karmada.io/docs/reference/karmadactl/karmadactl-commands/karmadactl_init)
    * **What it does:** Installs the Karmada API server, Controller Manager, and Scheduler into the host cluster.
    * **Implementation Details:** By default, this command attempts to write configuration files to `/etc/karmada`, which requires `sudo` privileges. To avoid this, the `--karmada-data="$KARMADA_DIR"` and `--karmada-pki="$KARMADA_DIR/pki"` flags are used to redirect the generation of the `kubeconfig` and PKI certificates to a local user directory (`~/.karmada`).
* **`karmadactl join`**
    * **Documentation:** [Karmada Cluster Registration](https://karmada.io/docs/userguide/clustermanager/cluster-registration)
    * **What it does:** Registers a target cluster into the Karmada control plane.
    * **Implementation Details:** Explicitly passes `--karmada-kubeconfig` and `--cluster-kubeconfig` for the environment we set up.


## Observability Setup
Deploys the kubernetes prometheus stack to the worker cluster to provide metrics scraping.

### Commands & Documentation
* **`helm repo add` & `helm repo update`**
    * **Documentation:** [Helm Repository Management](https://helm.sh/docs/helm/helm_repo/)
    * **What it does:** Registers the official repository with the local helm client and fetches the latest chart manifests.
* **`helm upgrade --install`**
    * **Documentation:** [Helm Upgrade Reference](https://helm.sh/docs/helm/helm_upgrade/) | [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
    * **What it does:** Installs or upgrades the entire prometheus and grafana suite into the cluster.
    * **Implementation Details:** * `--namespace monitoring` isolates the observability stack, `--set grafana.image.tag=10.4.1` forces a more stable version of grafana,`--timeout` overrides helm's default 5-minute timeout
* **`kubectl port-forward`**
    * **Documentation:** [Use Port Forwarding to Access Applications](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
    * **What it does:** Tunnels traffic from the local machine to the Grafana service running inside the Kubernetes cluster.



## Dashboard Setup
Injects dashboard files into grafana to bypass manual imports.

### Commands and Documentation
* **`kubectl create configmap`**
    * **Documentation:** [ConfigMaps Concept](https://kubernetes.io/docs/concepts/configuration/configmap/)
    * **What it does:** Wraps raw JSON dashboard file inside a Kubernetes ConfigMap object.
    * **Implementation Details:** Uses `kubectl create` paired with a preceding `kubectl delete ... --ignore-not-found` instead of using `kubectl apply` to bypass Kubernetes limit of 256KB. 
* **`kubectl label configmap`**
    * **Documentation:** [Kubectl Label](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_label)
    * **What it does:** Attaches the `grafana_dashboard="1"` label to the newly created ConfigMap. 
    * **Implementation Details:** Polls the Kubernetes API for any ConfigMap with this label. When detected, it intercepts the ConfigMap and loads JSON dashboard into the Grafana instance.


