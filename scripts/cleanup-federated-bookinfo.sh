#!/usr/bin/env bash
#
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export DNS="${DNS:-true}"
export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}" # Only used when DNS=true

if [ "${DNS}" = "true" ] ; then
    echo "### Deleting the federated domain bookinfo ServiceDNSRecord..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml 2> /dev/null
    # wait 30-seconds for the Domain/ServiceDNSRecords to be removed before removing the ext-dns controller.
    sleep 30

    echo "### Deleting the kube-dns configmap to support cross-cluster service discovery..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml 2> /dev/null
    sleep 5

    echo "### Deleting the external dns controller..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml 2> /dev/null
    sleep 5
fi

echo "### Deleting the federated bookinfo gateway..."
kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-gateway.yaml 2> /dev/null
sleep 5

echo "### Deleting the federated Istio custom resource types used by the bookinfo gateway..."
kubefed2 federate disable Gateway --delete-from-api 2> /dev/null
kubefed2 federate disable VirtualService --delete-from-api 2> /dev/null

echo "### Deleting the sample bookinfo application..."
kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo.yaml 2> /dev/null
sleep 5

# Revert instances of external.daneyon.com if DNS_SUFFIX is set to something else.
if ! [ "$(grep -ri "external.daneyon.com" "${ISTIO_VERSION}"/samples/)" ] ; then
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
fi
