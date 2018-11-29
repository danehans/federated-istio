#!/usr/bin/env bash
#
# Currently supports 2 clusters being deployed in 1 gcloud region
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export REGION="${REGION:-us-west1}"
export CLUSTER1_ZONE="${CLUSTER1_ZONE:-us-west1-a}"
export CLUSTER2_ZONE="${CLUSTER2_ZONE:-us-west1-b}"
export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}" # Only used when DNS=true

echo "### Deleting a ServiceEntry to allow external access to the httpbin server..."
kubectl delete -f "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml 2> /dev/null

echo "### Deleting the kube-dns configmap to support cross-cluster service discovery..."
kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml 2> /dev/null

echo "### Deleting the Domain and ServiceDNSRecord resources..."
kubectl delete -f "${ISTIO_VERSION}"/samples/httpbin/httpbin-dns.yaml 2> /dev/null
echo "### Waiting 30-seconds for DNS records to be deleted before removing the external-dns controller..."
sleep 30

echo "### Deleting the external-dns controller..."
kubectl delete -f "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml 2> /dev/null
sleep 5

echo "### Removing the httpbin through the Istio ingress gateway..."
kubectl delete -f "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml 2> /dev/null
sleep 5

echo "### Deleting the sample httpbin application (server)..."
kubectl delete -f "${ISTIO_VERSION}"/samples/httpbin/httpbin.yaml 2> /dev/null

echo "### Deleting the sample sleep application (client)..."
kubectl delete -f "${ISTIO_VERSION}"/samples/sleep/sleep.yaml 2> /dev/null
sleep 5

echo "### Removing additional federated Kubernetes resource types required for httpbin..."
kubefed2 federate disable Gateway --delete-from-api 2> /dev/null
kubefed2 federate disable VirtualService --delete-from-api 2> /dev/null
kubefed2 federate disable ServiceEntry --delete-from-api 2> /dev/null
sleep 5

# Replace instances of external.daneyon.com if DNS_SUFFIX is set.
if ! [ "$(grep -ri "external.daneyon.com" "${ISTIO_VERSION}"/samples/)" ] ; then
  echo "### Reverting \"${DNS_SUFFIX}\" to \"external.daneyon.com\""
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-dns.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
  sed -i "s/${DNS_SUFFIX}/external.daneyon.com/" "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
fi

# Change gcloud region if REGION is set.
if ! [ "$(grep -ri ".us-west1." "${ISTIO_VERSION}"/samples/)" ] ; then
  sed -i "s/.${REGION}./.us-west1./" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/.${REGION}./.us-west1./" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

# Change gcloud zone if CLUSTER1_ZONE is set.
if ! [ "$(grep -ri ".us-west1-a." "${ISTIO_VERSION}"/samples/)" ] ; then
  sed -i "s/.${CLUSTER1_ZONE}./.us-west1-a./" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/.${CLUSTER1_ZONE}./.us-west1-a./" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

# Change gcloud zone if CLUSTER2_ZONE is set.
if ! [ "$(grep -ri ".us-west1-b." "${ISTIO_VERSION}"/samples/)" ] ; then
  sed -i "s/.${CLUSTER2_ZONE}./.us-west1-b./" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/.${CLUSTER2_ZONE}./.us-west1-b./" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

echo "### httpbin and sleep sample application cleanup complete!"