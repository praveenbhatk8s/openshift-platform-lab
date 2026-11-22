#!/usr/bin/env bash
# Ask OpenShift's service CA for a certificate for the rack-demo Service, then restart the app
# so it starts serving HTTPS on 8443 with it.
set -euo pipefail
NS="${NS:-rack-demo}"

oc -n "$NS" annotate service rack-demo \
  service.beta.openshift.io/serving-cert-secret-name=rack-demo-tls --overwrite

echo "waiting for the service CA to create secret/rack-demo-tls ..."
for _ in $(seq 1 30); do
  oc -n "$NS" get secret rack-demo-tls >/dev/null 2>&1 && break
  sleep 2
done
oc -n "$NS" get secret rack-demo-tls

echo
echo "certificate subject, issuer and names:"
oc -n "$NS" get secret rack-demo-tls -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -subject -issuer -text | grep -E 'subject=|issuer=|DNS:' | sed 's/^ *//'

# The app only enables HTTPS at start-up, so restart it to pick up the certificate.
oc -n "$NS" rollout restart deploy/rack-demo
oc -n "$NS" rollout status deploy/rack-demo
oc -n "$NS" logs deploy/rack-demo | grep -E 'https|no certificate' | tail -2
