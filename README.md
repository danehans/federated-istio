# Federated Istio

Federated Istio is a reference implementation of running [Istio](https://istio.io/) across multiple
[Kubernetes](https://kubernetes.io/) clusters using [Federation-v2](https://github.com/kubernetes-sigs/federation-v2).
Federation-v2 is an API and control-plane for actively managing multiple Kubernetes clusters and applications in those
clusters. This makes Federation-v2 a viable solution for managing Istio deployments that span multiple Kubernetes
clusters. Not only can Federation-v2 support lifecycle management of the Istio control-plane, but it can also unify
Istio capabilities such as [Traffic Management](https://istio.io/docs/tasks/traffic-management/),
[Security](https://istio.io/docs/tasks/security/), [Policy Enforcement](https://istio.io/docs/tasks/policy-enforcement/)
, and [Telemetry](https://istio.io/docs/tasks/telemetry/).

## Federation-v2 Deployment
Follow the federation-v2 [user guide](https://github.com/kubernetes-sigs/federation-v2/blob/master/docs/userguide.md)
for deploying federation-v2 control-plane.

### Federated Istio Automated Deployment

If you would like a simple, automated way of deploying Federated Istio to one or two clusters, then run the following
script. Review the contents of the script to customize the deployment. Before running the script, there are a few
caveats to consider:

- The script assumes the current kubectl context contains the federation-v2 control-plane. `cluster2` is the
context name of the second cluster to be added to the federation.
- By default, the script installs the bookinfo Istio sample application. Set `export BOOKINFO=false` to not include
bookinfo as part of the installation.
- By default, the bookinfo sample application deploys Federated DNS with
[Google Cloud DNS](https://cloud.google.com/dns/) integration to expose the productpage frontend. This default behavior
can be changed by setting `export DNS=false`.
- When `export DNS=true`, you must have a DNS zone setup with a public registry, have Google Cloud
DNS configured to use the zone, and set `export DNS_SUFFIX=your.registered.zone`.

The following command creates a 2
cluster federation, where `cluster2` is the name of the second member cluster and your current context
(presumably cluster1) is the host and first member cluster.

```bash
./scripts/run-federated-istio.sh cluster2
```

You can use the clean-up script to remove what was done by `run-federated-istio.sh`.
```bash
./scripts/cleanup-federated-istio.sh cluster2
```

### Federated Istio Manual Deployment

The manual deployment assumes 2 clusters with the context name of `cluster1` and `cluster2`. Federation-v2 includes
`core` federated Kubernetes types such as `FederatedDeployment`, `FederatedConfigMap`, etc.. You can use the following
command to view the full list of federated Kubernetes types:
```bash
kubectl get federatedtypeconfigs -n federation-system
```

Use the `kubefed2 federate` command to federate additional Kubernetes resource types required by Istio.
```bash
kubefed2 federate enable CustomResourceDefinition
kubefed2 federate enable ClusterRole
kubefed2 federate enable ClusterRoleBinding
kubefed2 federate enable RoleBinding
kubefed2 federate enable HorizontalPodAutoscaler
kubefed2 federate enable MutatingWebhookConfiguration --comparison-field=Generation
```
__Note:__ The sidecar-injector pod patches the client `caBundle` of the `MutatingWebhookConfiguration` resource,
so `comparisonField: Generation` must be used for federating `MutatingWebhookConfiguration`.

You must update the Federation-v2 service account `ClusterRole` for each target cluster due to
[issue #354](https://github.com/kubernetes-sigs/federation-v2/issues/354):
```bash
for i in 1 2; do kubectl patch clusterrole/federation-controller-manager:cluster$i-cluster1 \
  -p='{"rules":[{"apiGroups":["*"],"resources":["*"],"verbs":["*"]},{"nonResourceURLs":["/metrics"],"verbs":["get"]}]}' \
  --context cluster$i; done
```

Set the version of Federated Istio manifests to use:
```bash
export ISTIO_VERSION=v1.0.3
```

Create the namespace used for the Istio control-plane:
```bash
kubectl create ns istio-system
```

The `istio-ingressgateway` uses `type: LoadBalancer`. If you intend on deploying Federated Istio to clusters that use
another type to expose services, you must change this field. An override manifest can be used to accomplish this once
([issue #367](https://github.com/kubernetes-sigs/federation-v2/issues/367)) is resolved.
```bash
sed -i 's/LoadBalancer/NodePort/' $ISTIO_VERSION/install/istio.yaml
```

Use `kubectl` to install Federated Istio.
```bash
kubectl create -f $ISTIO_VERSION/install/istio.yaml
```

Federate the Istio custom resource types:
```bash
kubefed2 federate enable Gateway
kubefed2 federate enable DestinationRule
kubefed2 federate enable kubernetes
kubefed2 federate enable rule
kubefed2 federate enable kubernetesenv
kubefed2 federate enable prometheus
kubefed2 federate enable metric
kubefed2 federate enable attributemanifest
kubefed2 federate enable stdio
kubefed2 federate enable logentry
```
__Note:__ If you get error message `error: Unable to find api resource named...` Kubernetes is not finished creating all
the Istio CRD's. Wait a moment and try running the `kubefed2 federate` command again.

Create the Federated Istio custom resources:
```bash
kubectl create -f $ISTIO_VERSION/install/istio-types.yaml
```

## Istio Deployment Verification
Verify that all Istio control-plane pods are running in the clusters.
```bash
$ for i in 1 2; do kubectl get pods -n istio-system --context cluster$i; done
NAME                                      READY     STATUS      RESTARTS   AGE
istio-citadel-6f875b9fdb-kn8nr            1/1       Running     0          1m
istio-cleanup-old-ca-29w6x                0/1       Completed   0          1m
istio-egressgateway-8b98f49f6-kp2jq       1/1       Running     0          1m
istio-ingress-69c65cc9dd-dvhnj            1/1       Running     0          1m
istio-ingressgateway-657d7c54fb-c2mpq     1/1       Running     0          1m
istio-mixer-post-install-6kqwk            0/1       Completed   0          1m
istio-pilot-7cfb4cc676-zn995              2/2       Running     0          1m
istio-policy-7c4448ccf6-ncgzc             2/2       Running     0          1m
istio-sidecar-injector-fc9dd55f7-jt4xc    1/1       Running     1          1m
istio-statsd-prom-bridge-9c78dbbc-9xxss   1/1       Running     0          1m
istio-telemetry-785947f8c8-2sw6r          2/2       Running     0          1m
prometheus-9c994b8db-2r2tp                1/1       Running     0          1m
NAME                                      READY     STATUS      RESTARTS   AGE
istio-citadel-6f875b9fdb-7kskr            1/1       Running     0          1m
istio-cleanup-old-ca-fc6n2                0/1       Completed   0          1m
istio-egressgateway-8b98f49f6-x58p2       1/1       Running     0          1m
istio-ingress-69c65cc9dd-cmb57            1/1       Running     0          1m
istio-ingressgateway-657d7c54fb-pvt5b     1/1       Running     0          1m
istio-mixer-post-install-vz675            0/1       Completed   0          1m
istio-pilot-7cfb4cc676-rvkz6              2/2       Running     0          1m
istio-policy-7c4448ccf6-fkbjr             2/2       Running     0          1m
istio-sidecar-injector-fc9dd55f7-nncrx    1/1       Running     1          1m
istio-statsd-prom-bridge-9c78dbbc-bcjqs   1/1       Running     0          1m
istio-telemetry-785947f8c8-s8sqq          2/2       Running     0          1m
prometheus-9c994b8db-965q9                1/1       Running     0          1m
```

The Federated Istio meshes are now ready to run applications. You can now proceed to the Bookinfo Deployment
section or view other installation details by replacing `pods` with the correct Kubernetes resource name
(i.e. `configmaps`) or the federated equivalent (i.e. federatedconfigmaps).

## Bookinfo Deployment
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

## What Next

- Use the [Federated Traffic Management Guide](docs/federated-traffic-management.md) to test Istio bookinfo federated
traffic management capabilities.

- Use the [Multicluster Service DNS](docs/multicluster-dns.md) to test Federated DNS capabilities.
