# 02 Routes and TLS: edge, re-encrypt, passthrough

A Route is how traffic from outside reaches an app on OpenShift. The router (HAProxy pods in `openshift-ingress`) holds a wildcard hostname, `*.apps.<cluster>.<domain>`, and the Route decides where TLS ends. A favourite interview question: "Which Route type would you use, and why?"

## The three modes

| Mode | Where TLS ends | Pod needs a certificate? | Client sees | Use when |
| --- | --- | --- | --- | --- |
| Edge | At the router | No | Router's certificate | Most web apps. Simple. Plain HTTP inside the cluster. |
| Re-encrypt | At the router, then a new TLS session to the pod | Yes, trusted by the router | Router's certificate | Encryption required inside the cluster too, for example regulated customers |
| Passthrough | At the pod | Yes | The pod's own certificate | The app must own TLS: mutual TLS with devices, client certificates, non-HTTP over TLS |

## Steps

Needs module 01's `rack-demo` running.

### 1. Give the app its own certificate from the service CA

OpenShift runs a **service CA**. Annotate a Service, and it creates a secret with a certificate for `<service>.<namespace>.svc`, and rotates it automatically.

```bash
cd 02-routes-tls
./service-tls.sh
```

You should see the issuer `openshift-service-serving-signer` and the app logging `https listening on 8443`.

### 2. Create the three Routes and test them

```bash
oc apply -f routes.yaml
oc get routes
./test-routes.sh
```

Expected:

| Route | Status | Pod served TLS? | Certificate the client sees |
| --- | --- | --- | --- |
| edge | 200 | false (pod got plain HTTP) | the router's default (ingress operator) certificate |
| reencrypt | 200 | true | the router's default certificate |
| passthrough | 200 | true | `openshift-service-serving-signer`: the pod's certificate |

All three redirect plain HTTP to HTTPS (`insecureEdgeTerminationPolicy: Redirect`).

### 3. Look at what the router did

```bash
oc get pods -n openshift-ingress
ROUTER=$(oc get pods -n openshift-ingress -o name | head -1)
oc exec -n openshift-ingress $ROUTER -- grep -A3 'rack-demo' /var/lib/haproxy/conf/haproxy.config | head -30
```

You'll see a backend per Route, and passthrough handled in the TCP section by SNI.

## Things worth knowing

- **Custom certificates.** A customer usually wants their own CA. Either replace the router's default certificate (once, for every Route), or put `tls.certificate`, `tls.key` and `tls.caCertificate` on a single Route.
- **Re-encrypt to a pod not signed by the service CA** needs `tls.destinationCACertificate` on the Route.
- **Ingress objects work too.** OpenShift converts a Kubernetes Ingress into Routes. Routes give you the TLS modes above.
- **Wrong target port** is a classic: a re-encrypt Route pointed at the plain HTTP port returns 503. Drill 5 in module 09 does exactly this.

## Checks

- [ ] All three Routes return 200.
- [ ] You can explain why passthrough shows a different certificate from the other two.
- [ ] You can say which mode you'd pick for a web UI, for an API needing encryption inside the cluster, and for devices using mutual TLS.

## Interview line

> "For a customer's web UI I'd use an edge Route with the customer's certificate on the router. If their security policy requires encryption inside the cluster, re-encrypt, with the service CA issuing the pod certificates so nothing has to be managed by hand. For devices doing mutual TLS, passthrough, because the app has to see the client certificate itself."
