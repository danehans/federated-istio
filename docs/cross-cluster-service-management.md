## Cross Cluster Service Management
Cross cluster service management provides Istio policies, security, traffic management, etc.. capabilities between
multiple Istio meshes. Reference the official Istio
[Traffic Management](https://archive.istio.io/v0.8/docs/tasks/traffic-management/) documentation for additional details.
The following provides an example of federating Istio route rules across`cluster1` and `cluster2`. Before proceeding,
refer to the [project README](../README.md) to setup Federated IStio.

Set the version of Federated Istio manifests to use:
```bash
export ISTIO_VERSION=v1.0.3
```

Create the Istio destination rules for the bookinfo services to use only `v1`:
```bash
kubectl create -f $ISTIO_VERSION/samples/bookinfo/routing/route-rule-all-v1.yaml
```

Verify route rule resource propagation to the clusters.
```bash
for i in 1 2; do kubectl get destinationrules --context cluster$i -o yaml; done
```

If you are using Multicluster Service DNS (MSDNS), you should be able to curl the productpage by vanity url. Foe example:
```bash

curl -I http://bookinfo.prod.daneyon.com/productpage
```
Confirm v1 is the active version of the reviews service by opening `http://$GATEWAY_URL/productpage` in your browser.
You should see the Bookinfo application productpage displayed. Notice that the productpage is displayed with no rating
stars since reviews:v1 does not access the ratings service.

You can now remove the v1 destination rules:
```bash
kubectl delete -f $ISTIO_VERSION/samples/bookinfo/routing/route-rule-all-v1.yaml
```
