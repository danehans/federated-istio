#!/usr/bin/env bash
#
# Currently supports 2 clusters being deployed in 1 gcloud region
# This script is meant to be called by ./scripts/run-federated-istio.sh
export REGION="${REGION:-us-west1}"
export CLUSTER1_ZONE="${CLUSTER1_ZONE:-us-west1-a}"
export CLUSTER2_ZONE="${CLUSTER2_ZONE:-us-west1-b}"

echo "### Federating additional Kubernetes resource types required for httpbin..."
kubefed2 federate enable VirtualService
kubefed2 federate enable ServiceEntry
sleep 5

echo "### Deploying the sample sleep application (client)..."
kubectl create -f "${ISTIO_VERSION}"/samples/sleep/sleep.yaml 2> /dev/null
sleep 5

echo "### Deploying the sample httpbin application (server)..."
kubectl create -f "${ISTIO_VERSION}"/samples/httpbin/httpbin.yaml 2> /dev/null
echo "### Waiting 15-seconds for httpbin pods to start running..."
sleep 15

# Replace instances of external.daneyon.com if DNS_SUFFIX is set.
if [ "${DNS_SUFFIX}" != "external.daneyon.com" ] ; then
  echo "### Replacing \"external.daneyon.com\" with \"${DNS_SUFFIX}\""
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-dns.yaml
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
  sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
fi

# Change gcloud region if REGION is set.
if [ "${REGION}" != "us-west1" ] ; then
  sed -i "s/us-west1/${REGION}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/us-west1/${REGION}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

# Change gcloud zone if CLUSTER1_ZONE is set.
if [ "${CLUSTER1_ZONE}" != "us-west1-a" ] ; then
  sed -i "s/us-west1-a/${CLUSTER1_ZONE}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/us-west1-a/${CLUSTER1_ZONE}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

# Change gcloud zone if CLUSTER2_ZONE is set.
if [ "${CLUSTER2_ZONE}" != "us-west1-b" ] ; then
  sed -i "s/us-west1-b/${CLUSTER2_ZONE}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
  sed -i "s/us-west1-b/${CLUSTER2_ZONE}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
fi

echo "### Federating the Istio custom resource types used by the httpbin gateway..."
kubefed2 federate enable VirtualService
sleep 3

echo "### Exposing httpbin through the Istio ingress gateway..."
kubectl create -f "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml 2> /dev/null
sleep 5

echo "### Deploying the external-dns controller..."
kubectl create -f "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml 2> /dev/null
sleep 5

echo "### Deploying the kube-dns configmap to support cross-cluster service discovery..."
kubectl create -f "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml 2> /dev/null

echo "### Creating the Domain and ServiceDNSRecord resources..."
kubectl create -f "${ISTIO_VERSION}"}/samples/httpbin/httpbin-dns.yaml 2> /dev/null

echo "### Creating a ServiceEntry to allow external access to the httpbin server..."
kubectl create -f "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml 2> /dev/null

echo "### httpbin and sleep sample application setup complete!"
echo " Verifying intra-mesh communication in cluster1..."
export SLEEP_POD1=$(kubectl --context cluster1 get pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl --context cluster1 exec -it $SLEEP_POD1 -c sleep curl http://httpbin.default.svc.cluster.local:8000/html
echo " Verifying intra-mesh communication in cluster2..."
export SLEEP_POD2=$(kubectl --context cluster2 get pod -l app=sleep -o jsonpath={.items..metadata.name})
kubectl --context cluster2 exec -it $SLEEP_POD2 -c sleep curl http://httpbin.default.svc.cluster.local:8000/html

# Verification
DNS_PREFIX="httpbin"
n=0
while [ $n -le 100 ]
do
  resp1=$(curl -w %{http_code} -s -o /dev/null http://"${DNS_PREFIX}"."${DNS_SUFFIX}"/html)
  if [ "$resp1" = "200" ] ; then
    echo "#### httpbin gateway test succeeded with \"HTTP/1.1 $resp1 OK\" return code."
    echo " Verifying Istio cross-mesh service policies from cluster1 to cluster2..."
    kubectl --context cluster1 exec -it $SLEEP_POD1 -c sleep curl http://istio-ingressgateway.istio-system.external.svc."${CLUSTER2_ZONE}"."${REGION}"."${DNS_SUFFIX}"/html
    echo "### Verifying Istio cross-mesh service policies from cluster2 to cluster1..."
    kubectl --context cluster2 exec -it $SLEEP_POD2 -c sleep curl http://istio-ingressgateway.istio-system.external.svc."${CLUSTER1_ZONE}"."${REGION}"."${DNS_SUFFIX}"/html
    echo "Istio Cross-cluster service policy verification completed successfully!"
    exit 0
  fi
  echo "testing ..."
  sleep 5
  n=`expr $n + 1`
done
echo "### Federated httpbin ingress gateway test timed-out."
echo "### Expected a \"200\" http return code, received a \"$resp\" return code."
echo "### Manually test with the following:"
echo "### curl -I http://${DNS_PREFIX}.${DNS_SUFFIX}/html"
exit 1
