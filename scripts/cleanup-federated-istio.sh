#!/usr/bin/env bash
#
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export BOOKINFO="${BOOKINFO:-true}"
export BOOKINFO_DNS="${BOOKINFO_DNS:-true}"
export NODE_PORT="${NODE_PORT:-false}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
CONTEXT="$(kubectl config current-context)"
JOIN_CLUSTERS="${*}"

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
  if [ "${BOOKINFO_DNS}" = "true" ] ; then
    echo "### Deleting the federated domain bookinfo ServiceDNSRecord..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml 2> /dev/null
    sleep 5

    echo "### Deleteing the kube-dns configmap to support cross-cluster service discovery..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/federated-configmap.yaml 2> /dev/null
    sleep 5

    echo "### Deleting the external dns controller..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/external-dns-crd-deployment.yaml 2> /dev/null
    sleep 5
  fi

  echo "### Deleting the federated bookinfo gateway..."
  kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-gateway.yaml 2> /dev/null
  sleep 5

  echo "### Deleting the federated Istio custom resource types used by the bookinfo gateway..."
  kubefed2 federate disable VirtualService --delete-from-api

  echo "### Deleting the sample bookinfo application..."
  kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo.yaml 2> /dev/null
  sleep 5
fi

# Revert instances of external.daneyon.com if DNS_SUFFIX is set.
if [ "${DNS_SUFFIX}" != "external.daneyon.com" ] ; then
  for files in bookinfo-dns.yaml external-dns-crd-deployment.yaml federated-configmap.yaml; do
    sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" ./"${ISTIO_VERSION}"/samples/bookinfo/$files
  done
fi

echo "### Removing default namespace label used for sidecar injection..."
kubectl label namespace default istio-injection- 2> /dev/null

echo "### Deleting the Federated Istio custom resources..."
kubectl delete -f "${ISTIO_VERSION}"/install/istio-types.yaml 2> /dev/null
sleep 5

echo "### Deleting federated Istio custom resource types..."
kubefed2 federate disable Gateway --delete-from-api
kubefed2 federate disable DestinationRule --delete-from-api
kubefed2 federate disable kubernetes --delete-from-api
kubefed2 federate disable rule --delete-from-api
kubefed2 federate disable kubernetesenv --delete-from-api
kubefed2 federate disable prometheus --delete-from-api
kubefed2 federate disable metric --delete-from-api
kubefed2 federate disable attributemanifest --delete-from-api
kubefed2 federate disable stdio --delete-from-api
kubefed2 federate disable logentry --delete-from-api

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
kubefed2 federate disable CustomResourceDefinition --delete-from-api
kubefed2 federate disable ClusterRole --delete-from-api
kubefed2 federate disable ClusterRoleBinding --delete-from-api
kubefed2 federate disable RoleBinding --delete-from-api
kubefed2 federate disable HorizontalPodAutoscaler --delete-from-api
kubefed2 federate disable MutatingWebhookConfiguration --delete-from-api

echo "### Federated Kubernetes resource types required for Istio have been removed."
sleep 5

echo "### Federated Istio Demo Cleanup Finished..."
echo "### Waiting 60 seconds while resources are fully removed from Kubernetes."
sleep 60