#!/usr/bin/env bash
#
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export DNS="${DNS:-true}"
export DNS_PREFIX="${DNS_PREFIX:-bookinfo}" # Not used when DNS=false

export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}" # Only used when DNS=true

echo "### Deleting the federated Istio custom resource types used by the bookinfo gateway..."
kubefed2 federate disable Gateway --delete-from-api 2> /dev/null
kubefed2 federate disable VirtualService --delete-from-api 2> /dev/null
echo "### Deleted the federated Istio custom resource types used by the bookinfo gateway."

if [ "${DNS}" = "true" ] ; then
    echo "### Deleting the federated domain and bookinfo ServiceDNSRecord..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml 2> /dev/null
    # wait 30-seconds for the Domain/ServiceDNSRecords to be removed before removing the ext-dns controller.
    sleep 30
    echo "### Deleted the federated domain and bookinfo ServiceDNSRecord."

    echo "### Deleting the kube-dns configmap to support cross-cluster service discovery..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml 2> /dev/null
    sleep 5
    echo "### Deleted the kube-dns configmap to support cross-cluster service discovery."

    echo "### Deleting the external dns controller..."
    kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml 2> /dev/null
    sleep 5
    echo "### Deleted the external dns controller."
fi

echo "### Deleting the federated bookinfo gateway..."
kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-gateway.yaml 2> /dev/null
sleep 5
echo "### Deleted the federated bookinfo gateway."

echo "### Deleting the sample bookinfo application..."
kubectl delete -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo.yaml 2> /dev/null
sleep 5
echo "### Deleted the sample bookinfo application."

if ! [ "$(grep -ri "external.daneyon.com" "${ISTIO_VERSION}"/samples/)" ] ; then
  echo "### Reverting instances of external.daneyon.com since DNS_SUFFIX is set to something else..."
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
  echo "### Reverted instances of DNS_SUFFIX back to external.daneyon.com."
fi

# Replace instances of bookinfo if DNS_PREFIX is set.
if [[ "${DNS_PREFIX}" != "bookinfo" ]] ; then
  echo "### Reverting instances of ${DNS_SUFFIX}..."
  sed -i "s/${DNS_PREFIX}/bookinfo/" "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml
  echo "### Reverted instances of ${DNS_PREFIX} back to bookinfo"
fi
