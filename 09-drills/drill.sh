#!/usr/bin/env bash
# Break things on purpose, then fix them without looking at this script.
#
#   ./drill.sh start <1-6>   create a working app in project rack-drill, then break it
#   ./drill.sh check         is the app reachable through its route?
#   ./drill.sh reset         delete the project
set -euo pipefail

NS=rack-drill

base() {
  oc get project "$NS" >/dev/null 2>&1 || oc new-project "$NS" >/dev/null
  oc apply -n "$NS" -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels: {app: web}
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
        - name: web
          image: registry.access.redhat.com/ubi9/nginx-124:latest
          command: ["nginx", "-g", "daemon off;"]
          ports: [{containerPort: 8080}]
          readinessProbe:
            httpGet: {path: /, port: 8080}
          resources:
            requests: {cpu: 10m, memory: 32Mi}
            limits: {memory: 128Mi}
---
apiVersion: v1
kind: Service
metadata: {name: web}
spec:
  selector: {app: web}
  ports: [{name: http, port: 8080, targetPort: 8080}]
---
apiVersion: route.openshift.io/v1
kind: Route
metadata: {name: web}
spec:
  to: {kind: Service, name: web}
  port: {targetPort: http}
  tls: {termination: edge, insecureEdgeTerminationPolicy: Redirect}
EOF
  oc rollout status deploy/web -n "$NS" --timeout=180s >/dev/null
}

check() {
  local host code
  host=$(oc get route web -n "$NS" -o jsonpath='{.spec.host}' 2>/dev/null) || { echo "no route"; return; }
  code=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 5 "https://$host/" || true)
  echo "https://$host/ -> HTTP ${code:-timeout}"
  [[ "$code" == 200 ]] && echo "OK: the app answers" || echo "BROKEN: find out why"
}

case "${1:-}" in
  start)
    n="${2:?usage: $0 start <1-6>}"
    echo "setting up a working app in $NS ..."
    base
    case "$n" in
      1) oc set image deploy/web web=docker.io/library/nginx:1.27 -n "$NS" >/dev/null
         oc patch deploy/web -n "$NS" --type json -p '[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]' >/dev/null ;;
      2) oc patch svc/web -n "$NS" -p '{"spec":{"selector":{"app":"wbe"}}}' >/dev/null ;;
      3) oc apply -n "$NS" -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: lockdown}
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
         ;;
      4) oc patch deploy/web -n "$NS" --type json \
           -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/ready"}]' >/dev/null ;;
      5) oc set resources deploy/web -n "$NS" --limits=memory=4Mi --requests=memory=4Mi >/dev/null ;;
      6) oc patch svc/web -n "$NS" --type json \
           -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8081}]' >/dev/null ;;
      *) echo "drill $n doesn't exist (1-6)"; exit 1 ;;
    esac
    echo "drill $n started. Symptom:"
    sleep 20
    check
    ;;
  check) check ;;
  reset) oc delete project "$NS" --ignore-not-found ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
