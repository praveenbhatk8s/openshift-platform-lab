# 09 Troubleshooting drills

Each drill builds a working app (Deployment, Service, edge Route) in project `rack-drill`, then breaks one thing. Your job: find it with `oc` alone, say the root cause out loud in one sentence, and fix it. Don't read `drill.sh` first.

```bash
cd 09-drills
./drill.sh start 1     # symptom shown at the end
# ... investigate and fix ...
./drill.sh check       # OK when fixed
./drill.sh reset       # clean up before the next drill
```

Time yourself. Under five minutes per drill is a good target.

## The toolkit

```bash
oc get pods,svc,endpoints,route -n rack-drill
oc describe pod <pod> -n rack-drill            # Events at the bottom
oc logs <pod> -n rack-drill [--previous]
oc get events -n rack-drill --sort-by=.lastTimestamp
oc get networkpolicy -n rack-drill
oc rsh <pod> curl -s localhost:8080            # from inside the pod
oc debug deploy/web -n rack-drill              # a copy of the pod with a shell
```

A useful habit: walk the path a request takes. Route → Service → Endpoints → Pod ready? → container listening on the right port → network policy in between.

## Drills

| # | Symptom you'll see |
| --- | --- |
| 1 | Pods won't start after an image change |
| 2 | Route returns 503, pods look fine |
| 3 | Route returns 503 or times out, pods and endpoints look fine |
| 4 | Pods Running but 0/1 ready |
| 5 | Pods restarting |
| 6 | Route returns 503, endpoints exist |

## Solutions

Try first.

<details><summary>1. Image from Docker Hub</summary>

`oc logs` shows permission errors (`mkdir() ... failed (13: Permission denied)` or binding to port 80). The upstream nginx image expects root and port 80; OpenShift's restricted SCC runs it as a random non-root UID. Fix: use an image built for arbitrary UIDs (`ubi9/nginx-124`), not `anyuid`. Module 01.

```bash
oc set image deploy/web web=registry.access.redhat.com/ubi9/nginx-124:latest -n rack-drill
oc patch deploy/web -n rack-drill --type json -p '[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["nginx","-g","daemon off;"]}]'
```
</details>

<details><summary>2. Service selector typo</summary>

`oc get endpoints web` is empty. The Service selects `app: wbe`, no pod has that label.

```bash
oc patch svc/web -n rack-drill -p '{"spec":{"selector":{"app":"web"}}}'
```
</details>

<details><summary>3. NetworkPolicy blocks the router</summary>

`oc get networkpolicy` shows `lockdown`, which denies all ingress, including from the router pods in `openshift-ingress`. `oc rsh` + curl to localhost works, which tells you the app is fine. Fix: allow the router (module 03).

```bash
# the module 03 policy selects app=rack-demo, so point it at this app
sed 's/app: rack-demo/app: web/' ../03-network-policy/allow-from-router.yaml | oc apply -n rack-drill -f -
```
</details>

<details><summary>4. Readiness probe on a path that doesn't exist</summary>

`oc describe pod` shows `Readiness probe failed: HTTP probe failed with statuscode: 404`. Not ready means not in endpoints, so no traffic.

```bash
oc patch deploy/web -n rack-drill --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```
</details>

<details><summary>5. Memory limit too low</summary>

`oc describe pod` shows `Last State: Terminated, Reason: OOMKilled` (or the container fails to start). 4Mi is too little for nginx.

```bash
oc set resources deploy/web -n rack-drill --requests=memory=32Mi --limits=memory=128Mi
```
</details>

<details><summary>6. Service targetPort wrong</summary>

Endpoints exist but list port 8081; nothing listens there. `oc get endpoints web -o yaml` or `oc describe svc web` shows it.

```bash
oc patch svc/web -n rack-drill --type json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
```
</details>

## Make your own

Ideas: a ResourceQuota that blocks new pods, a default-deny egress policy without DNS (module 03), a Secret the pod mounts but that doesn't exist, a PVC with a StorageClass that doesn't exist, a Route with a hostname already taken by another project.
