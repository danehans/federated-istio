## Cross Cluster Service Management
Cross cluster service management provides Istio policies, security, traffic management, etc.. capabilities between
multiple Istio meshes. Reference the official Istio
[Traffic Management](https://archive.istio.io/v0.8/docs/tasks/traffic-management/) documentation for additional details.
The following provides an example of federating Istio route rules across`cluster1` and `cluster2`. Before proceeding,
refer to the [project README](../README.md) to setup Federated Istio with the httpbin sample application
(i.e. `export HTTPBIN=true`).

### Deployment
Set the version of Federated Istio manifests to use:
```bash
export ISTIO_VERSION=v1.0.3
```

Federate the Istio custom api types used by this guide.
```bash
kubefed2 federate enable Gateway
kubefed2 federate enable VirtualService
kubefed2 federate enable ServiceEntry
```

Start the [sleep](https://github.com/istio/istio/tree/master/samples/sleep) sample application used as a test source for
external calls.
```bash
kubectl create -f $ISTIO_VERSION/samples/sleep/sleep.yaml
```

Set the environment variables of the sleep pods deployed to `cluster1` and `cluster2`:
```bash
export SLEEP_POD1=$(kubectl --context cluster1 get pod -l app=sleep -o jsonpath={.items..metadata.name})
export SLEEP_POD2=$(kubectl --context cluster2 get pod -l app=sleep -o jsonpath={.items..metadata.name})
```

Start the [httpbin](https://github.com/istio/istio/tree/master/samples/httpbin) sample application used as a test
destination.
```bash
kubectl create -f $ISTIO_VERSION/samples/httpbin/httpbin.yaml
```

Change the zone name in the manifests to match your DNS setup.
```bash
$ export DNS_SUFFIX="my.dns.zone.name"
$ sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-dns.yaml
$ sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
$ sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/external-dns/crd-deployment.yaml
$ sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" "${ISTIO_VERSION}"/samples/external-dns/kubedns-configmap.yaml
```

If you are deploying outside of Google Cloud zone `us-west` and regions `us-west1-a`/`us-west1-b`, then update the
zone/region information used to construct the Istio ingress/egress policies. For example, if you are using zones
`us-west2-a`/`us-west2-a` in region `us-west2`:
```bash
$ export REGION="us-west2"
$ export ZONE1="us-west2-a"
$ export ZONE2="us-west2-b"
$ sed -i "s/us-west1/${REGION}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
$ sed -i "s/us-west1-a/${ZONE1}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
$ sed -i "s/us-west1-b/${ZONE2}/" "${ISTIO_VERSION}"/samples/httpbin/serviceentries/httpbin-ext.yaml
$ sed -i "s/us-west1/${REGION}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
$ sed -i "s/us-west1-a/${ZONE1}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
$ sed -i "s/us-west1-b/${ZONE2}/" "${ISTIO_VERSION}"/samples/httpbin/httpbin-gateway.yaml
```

Externally expose the httpbin application through the Istio ingress gateway:
```bash
kubectl create -f $ISTIO_VERSION/samples/httpbin/httpbin-gateway.yaml
```

Deploy the [external-dns](https://github.com/kubernetes-incubator/external-dns) controller.
```bash
kubectl create -f ${ISTIO_VERSION}/samples/external-dns/crd-deployment.yaml
```

Deploy the kube-dns configmap to support cross-cluster service discovery.
```bash
kubectl create -f ${ISTIO_VERSION}/samples/external-dns/kubedns-configmap.yaml
```
Create the `Domain` used by your federation and the httpbin `ServiceDNSRecord`.
```bash
kubectl create -f ${ISTIO_VERSION}/samples/httpbin/httpbin-dns.yaml
```

Create a ServiceEntry to allow access to an external HTTP service:
```bash
kubectl create -f ${ISTIO_VERSION}/samples/httpbin/serviceentries/httpbin-ext.yaml
```

### Verification

Verify intra-mesh communication by curl'ing the httpbin endpoint from the sleep pod within each cluster.

```bash
kubectl --context cluster1 exec -it $SLEEP_POD1 -c sleep curl http://httpbin.default.svc.cluster.local:8000/html
kubectl --context cluster2 exec -it $SLEEP_POD2 -c sleep curl http://httpbin.default.svc.cluster.local:8000/html
```

The test client should be able to access any of the `hosts` in `irtualservice/httpbin `.
```bash
$ kubectl get virtualservice/httpbin -o yaml
apiVersion: v1
items:
- apiVersion: networking.istio.io/v1alpha3
  kind: VirtualService
  metadata:
    creationTimestamp: 2018-11-19T23:55:16Z
    generation: 1
    name: httpbin
    namespace: default
    resourceVersion: "1212077"
    selfLink: /apis/networking.istio.io/v1alpha3/namespaces/default/virtualservices/httpbin
    uid: 9024177e-ec56-11e8-8ee1-42010a8a013b
  spec:
    gateways:
    - httpbin-gateway
    hosts:
    - httpbin.my.dns.zone.name
    - istio-ingressgateway.istio-system.external.svc.my.dns.zone.name
    - istio-ingressgateway.istio-system.external.svc.us-west1.my.dns.zone.name
    - istio-ingressgateway.istio-system.external.svc.us-west1-a.us-west1.my.dns.zone.name
    - istio-ingressgateway.istio-system.external.svc.us-west1-b.us-west1.my.dns.zone.name
    http:
    - match:
      - uri:
          exact: /html
      - uri:
          exact: /status
      - uri:
          exact: /delay
      route:
      - destination:
          host: httpbin
          port:
            number: 8000
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
```

Verify that the source pod from each cluster can communicate with the httpbin deestination in the other cluster.
```bash
$ kubectl --context cluster1 exec -it $SLEEP_POD1 -c sleep \
curl http://istio-ingressgateway.istio-system.external.svc.us-west1-b.us-west1.my.dns.zone.name/html
$ kubectl --context cluster2 exec -it $SLEEP_POD2 -c sleep \
curl http://istio-ingressgateway.istio-system.external.svc.us-west1-a.us-west1.my.dns.zone.name/html
```
