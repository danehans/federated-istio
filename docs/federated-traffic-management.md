## Federated Istio Traffic Management
Federation-v2 provides consistency of Istio policies, security, traffic management, etc.. across multiple Istio meshes.
Reference the official Istio [Traffic Management](https://archive.istio.io/v0.8/docs/tasks/traffic-management/)
documentation for additional details. The following provides an example of federating Istio route rules across
`cluster1` and `cluster2`.

Create the Istio destination rules for the bookinfo services to use only `v1`:
```bash
kubectl create -f istio/$ISTIO_VERSION/samples/bookinfo/routing/route-rule-all-v1.yaml
```

Verify route rule resource propagation to the clusters.
```bash
for i in 1 2; do kubectl get destinationrules --context cluster$i -o yaml; done
```

Confirm v1 is the active version of the reviews service by opening `http://$GATEWAY_URL/productpage` in your browser.
You should see the Bookinfo application productpage displayed. Notice that the productpage is displayed with no rating
stars since reviews:v1 does not access the ratings service.
