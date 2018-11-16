## Federated DNS

Follow the steps in the Federated DNS
[Multi-Cluster Service DNS with ExternalDNS Guide](https://github.com/danehans/federation-v2/blob/svc_dns_docs/docs/servicedns-with-externaldns.md)
to deploy external-dns.

Create the `Domain` used by your federation and the bookinfo `ServiceDNSRecord`.
```bash
$ kubectl create -f istio/$ISTIO_VERSION/samples/bookinfo/bookinfo-dns.yaml
```

Verify the resource records have been propagated to your DNS provider. This example uses
[Google Cloud DNS](https://cloud.google.com/dns/).
```bash
$ gcloud dns record-sets list --zone "example"
NAME                                                                                               TYPE  TTL    DATA
example.com.                                                                                       NS    21600  ns-cloud-c1.googledomains.com.,ns-cloud-c2.googledomains.com.,ns-cloud-c3.googledomains.com.,ns-cloud-c4.googledomains.com.
example.com.                                                                                       SOA   21600  ns-cloud-c1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 300
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.example.com.  TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1-a.asia-east1.example.com.       A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.asia-east1.example.com.               TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.asia-east1.example.com.                    A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.example.com.                          TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.example.com.                               A     300    $CLUSTER2_ISTIO_INGRESSGATEWAY,$CLUSTER1_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1.example.com.                 TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1.example.com.                      A     300    $CLUSTER1_ISTIO_INGRESSGATEWAY
cnameistio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.example.com.      TXT   300    "heritage=external-dns,external-dns/owner=your_id"
istio-ingressgateway.istio-system.federation-system.svc.us-west1-b.us-west1.example.com.           A     300    $CLUSTER1_ISTIO_INGRESSGATEWAY
```

`istio-ingressgateway.istio-system.federation-system.svc.example.com.` represents the vanity domain name that is backed
by the productpage virtual service running in `cluster1` and `cluster2`. Verify name resolution of the vanity domain
name using `dig`.
```bash
$ dig +short @ns-cloud-c1.googledomains.com. istio-ingressgateway.istio-system.federation-system.svc.example.com.
$CLUSTER1_ISTIO_INGRESSGATEWAY
$CLUSTER2_ISTIO_INGRESSGATEWAY
```

It takes time for the resource records to be propagated to non-authoritative name servers. You should be able to
immediately test access using `curl` if you set your client's name servers to one of the above
(i.e. ns-cloud-c1.googledomains.com) and expect a `200` http response code.
```bash
$ export GATEWAY_URL=istio-ingressgateway.istio-system.federation-system.svc.example.com
$ curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
200
```
You can also test access to domain names of the individual productpage virtual services using the name of the other `A` records.
```bash
$ export GATEWAY_URL=istio-ingressgateway.istio-system.federation-system.svc.us-west1.example.com
$ curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
200
```

## References
- [Setting up ExternalDNS on Google Container Engine](https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/gke.md)
