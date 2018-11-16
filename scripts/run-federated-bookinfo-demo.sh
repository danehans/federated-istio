#!/usr/bin/env bash
#
# Follow the federation-v2 user guide to create k8s clusters and fedv2 control-plane.
# Then run this script from the project root directory.

export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
export DNS_SUFFIX="${DNS_SUFFIX:-external.daneyon.com}"
export DNS_PREFIX="${DNS_PREFIX:-bookinfo}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
CONTEXT="$(kubectl config current-context)"
JOIN_CLUSTERS="${*}"

# Check that kubectl is installed file.
if ! [ "$(which kubectl)" ] ; then
    echo "### You must have the kubectl client installed and set in PATH before running this script."
    exit 1
fi

# Check that kubectl config file.
if ! [ "$(stat ${KUBECONFIG})" ] ; then
    echo "### You must store your tenant cluster credentials to ${KUBECONFIG} before running this script."
    exit 1
fi

# Check that kubefed2 is installed file.
if ! [ "$(which kubefed2)" ] ; then
    echo "### You must have the kubefed2 client installed and set in PATH before running this script."
    exit 1
fi

echo "### Deploying the sample bookinfo application..."
kubectl create -f istio/"${ISTIO_VERSION}"/samples/bookinfo/bookinfo.yaml 2> /dev/null

echo "### Waiting 30-seconds for bookinfo pods to start running..."
sleep 30

for c in ${JOIN_CLUSTERS}; do
  kubectl get pod --context "${CONTEXT}"
done

echo "### Federating the Istio custom resource types used by the bookinfo gateway..."
kubefed2 federate enable VirtualService
sleep 3

echo "### Creating Federated bookinfo gateway..."
kubectl create -f istio/"${ISTIO_VERSION}"/samples/bookinfo/bookinfo-gateway.yaml 2> /dev/null
sleep 3

echo "### Creating the external dns controller..."
kubectl create -f istio/"${ISTIO_VERSION}/samples/bookinfo/crd-gke-deploy.yaml 2> /dev/null
sleep 5

echo "### Creating the kube-dns configmap to support cross-cluster service discovery..."
kubectl create -f istio/"${ISTIO_VERSION}/samples/bookinfo/federated-configmap.yaml 2> /dev/null
sleep 5

echo "### Creating Federated Domain and bookinfo ServiceDNSRecord resource..."
kubectl create -f istio/"${ISTIO_VERSION}"/samples/bookinfo/bookinfo-dns.yaml 2> /dev/null
sleep 3

echo "### Testing bookinfo productpage:"
echo "### curl -I http://$DNS_PREFIX.$DNS_SUFFIX/productpage"
echo "### Expecting \"HTTP/1.1 200 OK\" return code."
n=0
while [ $n -le 100 ]
do
    resp1=$(curl -w %{http_code} -s -o /dev/null http://$DNS_PREFIX.$DNS_SUFFIX/productpage)
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
echo "### curl -I http://$DNS_PREFIX.$DNS_SUFFIX/productpage"
exit 1
