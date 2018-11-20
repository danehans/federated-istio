#!/usr/bin/env bash
#
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export BOOKINFO="${BOOKINFO:-true}"
export HTTPBIN="${HTTPBIN:-false}"
export DNS="${DNS:-true}"
export DNS_PREFIX="${DNS_PREFIX:-bookinfo}" # Not used when DNS=false
export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}" # Not used when DNS=false
# export NODE_PORT=true for minikube and other k8s environments that expose services using type: NodePort
export NODE_PORT="${NODE_PORT:-false}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
export CONTEXT="$(kubectl config current-context)"
export JOIN_CLUSTERS="${*}"

if [ "${BOOKINFO}" = "true" ] && [ "${HTTPBIN}" = "true" ] ; then
  echo "### You cannot have BOOKINFO and HTTPBIN envs set to true."
  exit 1
fi

# Check that kubectl is installed.
if ! [ "$(which kubectl)" ] ; then
    echo "### You must have the kubectl client installed and set in PATH before running this script."
    exit 1
fi

# Check that kubectl config file.
if ! [ "$(stat ${KUBECONFIG})" ] ; then
    echo "### You must store your tenant cluster credentials to ${KUBECONFIG} before running this script."
    exit 1
fi

# Check that kubefed2 is installed.
if ! [ "$(which kubectl)" ] ; then
    echo "### You must have the kubefed2 client installed and set in PATH before running this script."
    exit 1
fi

echo "### Federating additional Kubernetes resource types required for Istio..."
kubefed2 federate enable CustomResourceDefinition
kubefed2 federate enable ClusterRole
kubefed2 federate enable ClusterRoleBinding
kubefed2 federate enable RoleBinding
kubefed2 federate enable HorizontalPodAutoscaler
kubefed2 federate enable MutatingWebhookConfiguration --comparison-field=Generation
sleep 5

echo "### Updating the fed-v2 service accounts in target clusters due to issue #354..."
for c in ${JOIN_CLUSTERS}; do
    kubectl patch clusterrole/federation-controller-manager:"${CONTEXT}"-"${CONTEXT}" \
      -p='{"rules":[{"apiGroups":["*"],"resources":["*"],"verbs":["*"]},{"nonResourceURLs":["/metrics"],"verbs":["get"]}]}' \
      --context "${CONTEXT}"
done

echo "### Creating the Istio namespace..."
kubectl create ns istio-system 2> /dev/null

echo "### Installing Federated Istio..."
if [ "${NODE_PORT}" = "true" ] ; then
  sed -i 's/LoadBalancer/NodePort/' "${ISTIO_VERSION}"/install/istio.yaml
fi

kubectl create -f "${ISTIO_VERSION}"/install/istio.yaml 2> /dev/null
echo "### Waiting 60-seconds for Federated Istio resource creation to complete before proceeding with the installation..."
sleep 60

echo "### Federating the Istio custom resource types..."
kubefed2 federate enable Gateway
kubefed2 federate enable DestinationRule
kubefed2 federate enable kubernetes
kubefed2 federate enable rule
kubefed2 federate enable kubernetesenv
kubefed2 federate enable prometheus
kubefed2 federate enable metric
kubefed2 federate enable attributemanifest
kubefed2 federate enable stdio
kubefed2 federate enable logentry
sleep 3

echo "### Creating the Federated Istio custom resources..."
kubectl create -f "${ISTIO_VERSION}"/install/istio-types.yaml 2> /dev/null

echo "### Waiting 30-seconds for the Istio control-plane pods to start running..."
sleep 30

echo "### Labeling the default namespace used for sidecar injection..."
kubectl label namespace default istio-injection=enabled 2> /dev/null

for c in ${JOIN_CLUSTERS}; do
  kubectl get namespace -L istio-injection --context "${CONTEXT}"
done
sleep 3

echo "### Federated Istio control-plane installation is complete."

# Install bookinfo sample app
if [ "${BOOKINFO}" = "true" ] ; then
  ./scripts/run-federated-bookinfo.sh
fi

# Install httpbin sample app
if [ "${HTTPBIN}" = "true" ] ; then
  ./scripts/run-federated-httpbin.sh
fi
