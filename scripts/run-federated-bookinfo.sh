#!/usr/bin/env bash
#
# This script is meant to be called by ./scripts/run-federated-istio.sh

echo "### Deploying the sample bookinfo application..."
kubectl create -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo.yaml 2> /dev/null

echo "### Waiting 30-seconds for bookinfo pods to start running..."
sleep 30

echo "### Federating the Istio custom resource types used by the bookinfo gateway..."
kubefed2 federate enable VirtualService
sleep 3

echo "### Creating Federated bookinfo gateway..."
kubectl create -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-gateway.yaml 2> /dev/null
sleep 3

# Replace instances of external.daneyon.com if DNS_SUFFIX is set.
if [ "${DNS_SUFFIX}" != "external.daneyon.com" ] ; then
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" ./"${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" ./"${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" ./"${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
fi

if [ "${DNS}" = "true" ] ; then
  echo "### Creating the external dns controller..."
  kubectl create -f "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml 2> /dev/null
  sleep 5

  echo "### Creating the kube-dns configmap to support cross-cluster service discovery..."
  kubectl create -f "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml 2> /dev/null
  sleep 5

  echo "### Creating Federated Domain and bookinfo ServiceDNSRecord resource..."
  kubectl create -f "${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml 2> /dev/null
  sleep 3

  echo "### Testing bookinfo productpage:"
  echo "### curl -I http://${DNS_PREFIX}.${DNS_SUFFIX}/productpage"
  echo "### Expecting \"HTTP/1.1 200 OK\" return code."
  n=0
  while [ $n -le 100 ]
  do
    resp1=$(curl -w %{http_code} -s -o /dev/null http://"${DNS_PREFIX}"."${DNS_SUFFIX}"/productpage)
    if [ "$resp1" = "200" ] ; then
      echo "#### Bookinfo gateway test for cluster1 succeeded with \"HTTP/1.1 $resp1 OK\" return code."
      exit 0
    fi
    echo "testing ..."
    sleep 5
    n=`expr $n + 1`
  done
  echo "### Federated Bookinfo Gateway tests timed-out."
  echo "### Expected a \"200\" http return code, received a \"$resp\" return code."
  echo "### Manually test with the following:"
  echo "### curl -I http://${DNS_PREFIX}.${DNS_SUFFIX}/productpage"
  exit 1
fi

echo "### Bookinfo sample application deployment complete."
echo "### Since DNS=false you must manually test the productpage frontend."
