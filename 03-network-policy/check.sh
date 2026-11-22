#!/usr/bin/env bash
# Three quick checks, run after every step of this module:
#   1. Can the router reach the app?            (ingress)
#   2. Can the app resolve a name?              (egress to DNS)
#   3. Can the app reach two outside websites?  (egress to the internet)
set -uo pipefail
NS="${NS:-rack-demo}"

host=$(oc -n "$NS" get route rack-demo-edge -o jsonpath='{.spec.host}' 2>/dev/null)
if [[ -n "$host" ]]; then
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://$host/")
  echo "1. router -> app (edge route):   HTTP $code"
else
  echo "1. router -> app: no rack-demo-edge route (apply module 02 first)"
fi

pod_python() {
  oc -n "$NS" exec deploy/rack-demo -- python3 -c "$1" 2>&1 | tail -1
}

echo "2. app resolves example.com:     $(pod_python 'import socket; print(socket.gethostbyname("example.com"))')"

for url in https://example.com https://www.redhat.com; do
  result=$(pod_python "import urllib.request
try:
    print(urllib.request.urlopen('$url', timeout=5).status)
except Exception as e:
    print(type(e).__name__, str(e)[:60])")
  printf '3. app -> %-25s %s\n' "$url:" "$result"
done
