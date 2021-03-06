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
kubefed2 federate enable CustomResourceDefinition 2> /dev/null
kubefed2 federate enable ClusterRole 2> /dev/null
kubefed2 federate enable ClusterRoleBinding 2> /dev/null
kubefed2 federate enable RoleBinding 2> /dev/null
kubefed2 federate enable HorizontalPodAutoscaler 2> /dev/null
kubefed2 federate enable MutatingWebhookConfiguration --comparison-field=Generation 2> /dev/null
sleep 5
echo "### Federated additional Kubernetes resource types required for Istio."

echo "### Creating the Istio namespace..."
kubectl create ns istio-system 2> /dev/null
echo "### Created the Istio namespace."

if [ "${NODE_PORT}" = "true" ] ; then
  echo "### Setting Service type: NodePort for Istio manifest..."
  sed -i 's/LoadBalancer/NodePort/' "${ISTIO_VERSION}"/install/istio.yaml
  echo "### Set Service type: NodePort for Istio manifest."
fi

echo "### Installing Federated Istio..."
kubectl create -f "${ISTIO_VERSION}"/install/istio.yaml 2> /dev/null
echo "### Installed Federated Istio."
echo "### Waiting 60-seconds for Federated Istio resource creation to complete before proceeding with the installation..."
sleep 60

echo "### Due to Issue #469, creating non-federated mutatingwebhookconfiguration in each cluster..."
kubectl create -f $ISTIO_VERSION/install/mutatingwebhookconfiguration.yaml --context cluster1
kubectl create -f $ISTIO_VERSION/install/mutatingwebhookconfiguration.yaml --context cluster2
echo "### Created non-federated mutatingwebhookconfiguration in each cluster."

echo "### Federating the Istio custom resource types..."
kubefed2 federate enable Gateway 2> /dev/null
kubefed2 federate enable DestinationRule 2> /dev/null
kubefed2 federate enable kubernetes 2> /dev/null
kubefed2 federate enable rule 2> /dev/null
kubefed2 federate enable kubernetesenv 2> /dev/null
kubefed2 federate enable prometheus 2> /dev/null
kubefed2 federate enable metric 2> /dev/null
kubefed2 federate enable attributemanifest 2> /dev/null
kubefed2 federate enable stdio 2> /dev/null
kubefed2 federate enable logentry 2> /dev/null
sleep 3
echo "### Federated the Istio custom resource types."

echo "### Creating the Federated Istio custom resources..."
kubectl create -f "${ISTIO_VERSION}"/install/istio-types.yaml 2> /dev/null
echo "### Created the Federated Istio custom resources."
echo "### Waiting 30-seconds for the Istio control-plane pods to start running..."
sleep 30

echo "### Labeling the default namespace used for sidecar injection..."
kubectl label namespace default istio-injection=enabled 2> /dev/null
echo "### Labeled the default namespace used for sidecar injection."

echo "### Federated Istio control-plane installation is complete."
# Install bookinfo sample app
if [ "${BOOKINFO}" = "true" ] ; then
  ./scripts/run-federated-bookinfo.sh
fi

# Install httpbin sample app
if [ "${HTTPBIN}" = "true" ] ; then
  ./scripts/run-federated-httpbin.sh
fi
