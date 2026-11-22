#!/usr/bin/env bash
# For each Route: call it, and show which certificate the client actually sees.
# Edge and re-encrypt show the router's certificate; passthrough shows the pod's own.
set -uo pipefail
NS="${NS:-rack-demo}"

for route in rack-demo-edge rack-demo-reencrypt rack-demo-passthrough; do
  host=$(oc -n "$NS" get route "$route" -o jsonpath='{.spec.host}' 2>/dev/null)
  if [[ -z "$host" ]]; then
    echo "== $route: not found"; continue
  fi
  echo "== $route  (https://$host)"

  code=$(curl -sk -o /tmp/route-body.$$ -w '%{http_code}' "https://$host/")
  echo "   HTTP status: $code"
  [[ "$code" == "200" ]] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("   pod:", d["pod"], " uid:", d["uid"], " pod served TLS:", d["tls"])' /tmp/route-body.$$

  issuer=$(echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null \
           | openssl x509 -noout -issuer 2>/dev/null)
  echo "   certificate the client sees: ${issuer:-none}"

  redirect=$(curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}' "http://$host/")
  echo "   plain http: $redirect"
  echo
done
rm -f /tmp/route-body.$$
