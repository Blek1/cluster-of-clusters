ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# deplyoments = API objects, like dummy containers written into etcd (karmada key value storage)
export KARMADA_KUBECONFIG=$HOME/.karmada/karmada-apiserver.config
export KARMADA_IP=192.168.1.153   

cd "${ROOT_DIR}/perf-tests/clusterloader2"

go run cmd/clusterloader.go \
  --testconfig="${ROOT_DIR}/configs/clusterloader/config.yaml" \
  --provider=local \
  --kubeconfig=$KARMADA_KUBECONFIG \
  --v=2 \
  --k8s-clients-number=1 \
  --skip-cluster-verification=true \
  --masterip=$KARMADA_IP \
  --enable-exec-service=false



echo ""
echo "✅ ClusterLoader2 finished!"
echo ""
echo "Quick stats:"
echo "   Total deployments on Karmada:"
kubectl --kubeconfig=$KARMADA_KUBECONFIG get deployments -A --no-headers | wc -l
echo ""
echo "   ResourceBindings (Karmada propagation objects):"
kubectl --kubeconfig=$KARMADA_KUBECONFIG get resourcebindings -A --no-headers | wc -l
echo ""
echo "   JUnit report saved to:"
echo "   ${ROOT_DIR}/perf-tests/clusterloader2/junit.xml"