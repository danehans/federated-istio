#!/usr/bin/env bash
#
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export BOOKINFO="${BOOKINFO:-true}"
export HTTPBIN="${HTTPBIN:-false}"
export DNS="${DNS:-true}" # Only used when
export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}" # Only used when DNS=true
export NODE_PORT="${NODE_PORT:-false}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
CONTEXT="$(kubectl config current-context)"
JOIN_CLUSTERS="${*}"

if [ "${BOOKINFO}" = "true" ] && [ "${HTTPBIN}" = "true" ] ; then
  echo "### You cannot have BOOKINFO and HTTPBIN envs set to true."
  exit 1
fi

# Check that kubectl is installed.
if ! [ "$(which kubectl)" ] ; then
    echo "### You must have the kubectl client installed and set in PATH before running this script."
    exit 1
fi

# Check that kubectl config file is installed.
if ! [ "$(stat ${KUBECONFIG})" ] ; then
    echo "### You must store your tenant cluster credentials to ${KUBECONFIG} before running this script."
    exit 1
fi

# Check that kubefed2 is installed.
if ! [ "$(which kubefed2)" ] ; then
    echo "### You must have the kubefed2 client installed and set in PATH before running this script."
    exit 1
fi

# Uninstall bookinfo sample app
if [ "${BOOKINFO}" = "true" ] ; then
  ./scripts/cleanup-federated-bookinfo.sh
fi

# Uninstall bookinfo sample app
if [ "${HTTPBIN}" = "true" ] ; then
  ./scripts/cleanup-federated-httpbin.sh
fi

echo "### Removing default namespace label used for sidecar injection..."
kubectl label namespace default istio-injection- 2> /dev/null

echo "### Deleting the Federated Istio custom resources..."
kubectl delete -f "${ISTIO_VERSION}"/install/istio-types.yaml 2> /dev/null
sleep 5

echo "### Deleting federated Istio custom resource types..."
kubefed2 federate disable gateways.networking.istio.io  --delete-from-api
kubefed2 federate disable destinationrules.networking.istio.io --delete-from-api
kubefed2 federate disable kuberneteses.config.istio.io --delete-from-api
kubefed2 federate disable rules.config.istio.io --delete-from-api
kubefed2 federate disable kubernetesenvs.config.istio.io --delete-from-api
kubefed2 federate disable prometheuses.config.istio.io --delete-from-api
kubefed2 federate disable metrics.config.istio.io --delete-from-api
kubefed2 federate disable attributemanifests.config.istio.io --delete-from-api
kubefed2 federate disable stdios.config.istio.io --delete-from-api
kubefed2 federate disable logentries.config.istio.io --delete-from-api

echo "### Deleting Federated Istio..."
# Revert NodePort types back to default (LoadBalancer) if needed.
NODEPORT_CHECK="$(grep -ri 'type: NodePort' "${ISTIO_VERSION}"/install/istio.yaml) 2> /dev/null)"
if [ "${NODEPORT_CHECK}" ] ; then
  sed -i 's/NodePort/LoadBalancer/' "${ISTIO_VERSION}"/install/istio.yaml
fi
kubectl delete -f "${ISTIO_VERSION}"/install/istio.yaml 2> /dev/null
sleep 30

echo "### Updating the fed-v2 service accounts in target clusters due to issue #354..."
for c in ${JOIN_CLUSTERS}; do
  kubectl patch clusterrole/federation-controller-manager:"${CONTEXT}"-"${CONTEXT}" \
    -p='{"rules":[{"apiGroups":["*"],"resources":["*"],"verbs":["*"]}]}' --context "${CONTEXT}"
done

echo "### Removing federated Kubernetes resource types required for Istio..."
kubefed2 federate disable customresourcedefinitions.apiextensions.k8s.io --delete-from-api
kubefed2 federate disable clusterroles.rbac.authorization.k8s.io --delete-from-api
kubefed2 federate disable clusterrolebindings.rbac.authorization.k8s.io --delete-from-api
kubefed2 federate disable rolebindings.rbac.authorization.k8s.io --delete-from-api
kubefed2 federate disable federatedhorizontalpodautoscalers.autoscaling --delete-from-api
kubefed2 federate disable mutatingwebhookconfigurations.admissionregistration.k8s.io --delete-from-api

echo "### Federated Kubernetes resource types required for Istio have been removed."
sleep 5

echo "### Federated Istio Demo Cleanup Finished..."
echo "### Waiting 60 seconds while resources are fully removed from Kubernetes."
sleep 60