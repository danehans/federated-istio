## Bookinfo Deployment

The following provides an example of running the sample [bookinfo](https://archive.istio.io/v0.8/docs/guides/bookinfo)
application on Federated Istio. Before proceeding, refer to the [project README](../README.md) to setup Federated Istio.
__Note__: By default, the Federated Istio automated deployment script deploys the bookinfo sample application
(export HTTPBIN=true).

### Federated Bookinfo Automated Deployment

If you would like a simple, automated way of deploying the sample bookinfo application to an existing Federated Istio
deployment then run the following script. Review the contents of the script to customize the deployment. Before running
the script, refer to the caveats in the [project README](../README.md).

```bash
./scripts/run-federated-bookinfo.sh
```

### Federated Bookinfo Manual Deployment

Set the version of Federated Istio manifests to use:
```bash
export ISTIO_VERSION=v1.0.3
```

Label the default namespace with `istio-injection=enabled`.
```bash
kubectl label namespace default istio-injection=enabled
```

Verify the label is applied to namespace `default` in both clusters.
```bash
$ for i in 1 2; do kubectl get namespace -L istio-injection --context cluster$i; done
NAME                       STATUS    AGE       ISTIO-INJECTION
default                    Active    1h        enabled
<SNIP>
```

Install the [bookinfo](https://istio.io/docs/examples/bookinfo/) sample application.
```bash
kubectl create -f $ISTIO_VERSION/samples/bookinfo/bookinfo.yaml
```

Verify the bookinfo pods have been propagated to both clusters.
```bash
$ for i in 1 2; do kubectl get pod --context cluster$i; done
NAME                             READY     STATUS    RESTARTS   AGE
details-v1-fd75f896d-vjmh2       2/2       Running   0          30s
productpage-v1-57f4d6b98-qb96g   2/2       Running   0          28s
ratings-v1-6ff8679f7b-nfhkh      2/2       Running   0          29s
reviews-v1-5b66f78dc9-vsj9q      2/2       Running   0          29s
reviews-v2-5d6d58488c-vw4vh      2/2       Running   0          29s
reviews-v3-5469468cff-9tp8r      2/2       Running   0          29s
NAME                             READY     STATUS    RESTARTS   AGE
details-v1-fd75f896d-ttkgw       2/2       Running   0          30s
productpage-v1-57f4d6b98-j4bxv   2/2       Running   0          28s
ratings-v1-6ff8679f7b-mgnzk      2/2       Running   0          30s
reviews-v1-5b66f78dc9-nts9j      2/2       Running   0          29s
reviews-v2-5d6d58488c-mk27n      2/2       Running   0          29s
reviews-v3-5469468cff-bdvjn      2/2       Running   0          29s
```

Federate the Istio `VirtualService` custom type used by `bookinfo-gateway.yaml`:
```bash
kubefed2 federate enable VirtualService
```

Create the Istio ingress gateway for the bookinfo application:
```bash
kubectl create -f $ISTIO_VERSION/samples/bookinfo/bookinfo-gateway.yaml
```

You can verify the status of the Istio `Gateway` and `VirtualService resources with:
```bash
$ for i in 1 2; do kubectl get gateways --context cluster$i; done
NAME               AGE
bookinfo-gateway   17s

$ for i in 1 2; do kubectl get virtualservices --context cluster$i; done
NAME       AGE
bookinfo   26s
```

Follow the official Istio
[bookinfo documentation](https://archive.istio.io/v0.8/docs/guides/bookinfo/#determining-the-ingress-ip-and-port) for
determining the Ingress IP address and port for testing.
