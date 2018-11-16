## Multicluster Service DNS

Multicluster Service DNS (MSDNS) provides the ability to programmatically manage DNS resource records of Service
objects. MSDNS is not meant to replace in-cluster DNS providers such as CoreDNS. Instead, MSDNS integrates with
ExternalDNS through CRD Source to manage DNS resource records of Service objects in supported DNS providers. Before
proceeding, refer to the MSDNS caveats listed in the [project README](../README.md)

Set the Istio version for the deployment (v1.0.3 is currently only supported version):
```bash
export ISTIO_VERSION="${ISTIO_VERSION:-v1.0.3}"
```

The manifests use the `external.daneyon.com` DNS zone by default. Set your registered zone name:
```bash
$ export DNS_SUFFIX=my.registered.domain
```
Change the zone name in the necessary deployment files.
```bash
for files in bookinfo-dns.yaml external-dns-crd-deployment.yaml federated-configmap.yaml; do
    sed -i "s/external.daneyon.com/${DNS_SUFFIX}/" ./"${ISTIO_VERSION}"/samples/bookinfo/$files
done
```

Deploy the [external-dns](https://github.com/kubernetes-incubator/external-dns) controller.
```bash
kubectl create -f istio/"${ISTIO_VERSION}"/samples/bookinfo/external-dns-crd-deployment.yaml
```

Deploy the kube-dns configmap to support cross-cluster service discovery.
```bash
kubectl create -f istio/"${ISTIO_VERSION}"/samples/bookinfo/federated-configmap.yaml
```
Create the `Domain` used by your federation and the bookinfo `ServiceDNSRecord`.
```bash
$ kubectl create -f $ISTIO_VERSION/samples/bookinfo/bookinfo-dns.yaml
```

Verify the resource records have been propagated to [Google Cloud DNS](https://cloud.google.com/dns/).
```bash
$ gcloud dns record-sets list --zone "my-registered-domain"
NAME                                                                                               TYPE  TTL    DATA
my.registered.domain.                                                                                       NS    21600  ns-cloud-c1.googledomains.com.,ns-cloud-c2.googledomains.com.,ns-cloud-c3.googledomains.com.,ns-cloud-c4.googledomains.com.
my.registered.domain.                                                                                       SOA   21600  ns-cloud-c1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300
bookinfo.my.registered.domain.                                                                              A     300    $CLUSTER1_ISTIO_INGRESSGATEWAY,$CLUSTER2_ISTIO_INGRESSGATEWAY
bookinfo.my.registered.domain.                                                                              TXT   300    "heritage=external-dns,external-dns/owner=your_id"
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.my.registered.domain.  TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.my.registered.domain.       A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1.my.registered.domain.               TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1.my.registered.domain.                    A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.my.registered.domain.                          TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.my.registered.domain.                               A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY,$CLUSTER2_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1.my.registered.domain.                 TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1.my.registered.domain.                      A     300    $CLUSTER1_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.my.registered.domain.      TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.my.registered.domain.           A     300    $CLUSTER1_ISTIO_INGRESSGATEWAY
```

`bookinfo.my.registered.domain.` represents the vanity domain name that is backed by the productpage virtual service
running in `cluster1` and `cluster2`. Verify name resolution of the vanity domain
name using `dig`.
```bash
$ dig +short @ns-cloud-c1.googledomains.com. bookinfo.my.registered.domain.
$CLUSTER1_ISTIO_INGRESSGATEWAY
$CLUSTER2_ISTIO_INGRESSGATEWAY
```

It takes time for the resource records to be propagated to non-authoritative name servers. You should be able to
immediately test access using `curl` if you set your client's name servers to one of the above
(i.e. ns-cloud-c1.googledomains.com) and expect a `200` http response code.
```bash
$ curl -o /dev/null -s -w "%{http_code}\n" http://bookinfo.my.registered.domain/productpage
200
```
You can also test access to domain names of the individual productpage virtual services using the name of the other `A` records.
```bash
$ export GATEWAY_URL=istio-ingressgateway.istio-system.federation-system.svc.us-west1.my.registered.domain
$ curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
200
```

## References
- [Setting up ExternalDNS on Google Container Engine](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/gke.md)
