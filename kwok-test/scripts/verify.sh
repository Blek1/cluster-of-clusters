kind get clusters
# should show: host-01, member-01, member-02, member-03


kubectl config use-context kind-host-01
kubectl get pods -n karmada-system
# should show all rtunning:
# karmada-apiserver
# karmada-controller-manager
# karmada-scheduler
# karmada-webhook
# etcd

kubectl --kubeconfig=$HOME/.karmada/karmada-apiserver.config get clusters
# should show member-01, member-02, member-03 all Ready

for i in 1 2 3; do
  echo "==> member-0${i}"
  kubectl config use-context kind-member-0${i}
  kubectl get pods -n kube-system | grep kwok
done
# should show kwok-controller Running in each

for i in 1 2 3; do
  echo "==> member-0${i}"
  kubectl config use-context kind-member-0${i}
  kubectl get nodes
done
# should show control-plane node + 100 fake-node-0 through fake-node-99 all Ready


kubectl --kubeconfig=$HOME/.karmada/karmada-apiserver.config get clusters
# should show member-01, member-02, member-03 all Ready

