## Bookinfo Live Upgrade

It's time to upgrade the bookinfo application in `cluster2`. Update the Istio ingress gateway
`FederatedServicePlacement` resource of the bookinfo `FederatedService` resource only exists in `cluster1`.
```bash
$ kubectl patch -n istio-system federatedserviceplacement/istio-ingressgateway \
--type=merge -p '{"spec":{"clusterNames":["cluster1"]}}'
```

The zone should no longer container `A` records for the $CLUSTER2_ISTIO_INGRESSGATEWAY. __Note__: It may take a few
minutes for the external-dns controller to update the zone records.
```bash
$ gcloud dns record-sets list --zone "example"
NAME                                                                                               TYPE  TTL    DATA
example.com.                                                                                       NS    21600  ns-cloud-c1.googledomains.com.,ns-cloud-c2.googledomains.com.,ns-cloud-c3.googledomains.com.,ns-cloud-c4.googledomains.com.
example.com.                                                                                       SOA   21600  ns-cloud-c1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.example.com.  TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.example.com.       A     300    130.211.253.102
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1.example.com.               TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1.example.com.                    A     300    130.211.253.102
cnameistio-ingressgateway.istio-system.federation-system.svc.example.com.                          TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.example.com.                               A     300    130.211.253.102,35.233.207.14
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1.example.com.                 TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1.example.com.                      A     300    35.233.207.14
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.example.com.      TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.example.com.           A     300    35.233.207.14
```

You should still be able to access the `istio-ingressgateway.istio-system.federation-system.svc.example.com.` vanity
domain even though the productpage virtual in `cluster2` has been taken deleted.
```bash
$ export GATEWAY_URL=istio-ingressgateway.istio-system.federation-system.svc.example.com
$ curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
200
```

Upgrade the bookinfo application and patch `FederatedServicePlacement` so the productpage virtual service is created in
cluster2.
```bash
$ kubectl patch -n istio-system federatedserviceplacement/istio-ingressgateway \
--type=merge -p '{"spec":{"clusterNames":["cluster1","cluster2"]}}'
```

Repeat the verification steps from above. Then repeat the same process for the bookinfo virtual service in `cluster1`.

### Istio Control-Plane Live Upgrade

1. Update bookinfo placement resources to use only `cluster1` using `kubectl patch` command.
2. Update istio placement resources to use only `cluster1` using `kubectl patch` command. CRDs should be in both
clusters.
3. Federate the newer versions of Istio API types. `kubectl api-resources` is a good command:

```bash
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=attributemanifest
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=rule
```

Due to a pluralization [issue](https://github.com/kubernetes-sigs/federation-v2/pull/340#issuecomment-434524669).
Skip this resource for now
```bash
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=stdios
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=logentry
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=metric
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=prometheus
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=kubernetesenv
$ kubefed2 federate --namespaced=true --group=config.istio.io --version=v1alpha2 --kind=kubernetes
```

Create the Federated Istio resources:
```bash
$ kubectl create -f istio/v1.0.3/install/istio-types.yaml
```
__Note:__ `istio-types-issue.yaml` > `istio-types.yaml` after fixing pluralization
[issue](https://github.com/kubernetes-sigs/federation-v2/pull/340#issuecomment-434524669)

4. Deploy Istio v1.0.3 CRD's to `cluster2`:
```bash
$ kubectl create --validate=false -f istio/v1.0.3/install/crds_upgrade_from_v0.8.yaml
```
__Note:__ Disregard any `Error from server (AlreadyExists)` messages.
__Note:__ `crds_upgrade_from_v0.8.yaml` only contains new CRDs since v0.8 CRDs exist.

## Cleanup

Uninstall the bookinfo ingress gateway:
```bash
$ kubectl delete -f istio/$ISTIO_VERSION/samples/bookinfo/bookinfo-gateway.yaml

```
Uninstall the bookinfo sample application:
```bash
$ kubectl delete -f istio/$ISTIO_VERSION/samples/bookinfo/bookinfo.yaml

```
Uninstall Federated Istio:
```bash
$ kubectl delete -R -f istio/$ISTIO_VERSION/install/
```

Uninstall the mutatingwebhookconfiguration for `cluster1` and cluster2`.
```bash
$ for i in 1 2; do kubectl delete -f istio/$ISTIO_VERSION/src/mutating-webhook-configuration.yaml \
  --context cluster$i; done
```

Uninstall the federation-v2 control-plane by changing to the federation-v2 project root directory and run:
```bash
cd $GOPATH/src/github.com/kubernetes-sigs/federation-v2
./scripts/delete-federation.sh
```
