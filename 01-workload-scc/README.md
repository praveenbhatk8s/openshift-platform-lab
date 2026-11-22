# 01 Workload and SCC: why images fail on OpenShift

The most common problem when moving workloads to OpenShift: an image that runs fine on EKS or AKS crash-loops on OpenShift. This module reproduces it, explains it, and fixes it the right way.

## Background in four lines

- Every pod is admitted under a **security context constraint (SCC)**. By default that's `restricted-v2`.
- `restricted-v2` runs the container as a **random UID** from the project's range, with group 0, no privilege escalation, and all capabilities dropped.
- Images that expect root, a fixed UID, or port 80 fail: they can't write their own directories or bind the port.
- The fix is in the image (group-0 ownership, group-writable paths, a high port), not in loosening the SCC.

## Steps

### 1. Create the project and see its UID range

```bash
oc new-project rack-demo
oc get project rack-demo -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}{"\n"}'
```

That range, for example `1000660000/10000`, is where your pods' UIDs come from.

### 2. Watch a normal image fail

```bash
oc apply -f nginx-dockerhub.yaml
oc get pods -l app=nginx-dockerhub -w          # CrashLoopBackOff after a few seconds
oc logs deploy/nginx-dockerhub
```

Expect `mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)`.

Check which SCC admitted it and the UID it got:

```bash
POD=$(oc get pod -l app=nginx-dockerhub -o name | head -1)
oc get $POD -o jsonpath='{.metadata.annotations.openshift\.io/scc}{"\n"}'
oc get $POD -o jsonpath='{.spec.containers[0].securityContext.runAsUser}{"\n"}'
```

### 3. The wrong fix, to understand it (cluster-admin only)

```bash
oc create serviceaccount nginx-root
oc adm policy add-scc-to-user anyuid -z nginx-root
oc set serviceaccount deploy/nginx-dockerhub nginx-root
oc get pods -l app=nginx-dockerhub -w          # now Running, as root
```

It works, and it's the wrong answer for a customer platform: the container runs as root, a security review will flag it, and every image needs an exception. Undo it:

```bash
oc adm policy remove-scc-from-user anyuid -z nginx-root
oc delete deploy/nginx-dockerhub sa/nginx-root
```

### 4. The right fix: an image built for arbitrary UIDs

```bash
oc apply -f nginx-ubi.yaml
oc get pods -l app=nginx-ubi -w                # Running, under restricted-v2
```

### 5. Build the demo app inside the cluster

OpenShift can build images itself: a **BuildConfig** runs the build, and the result lands in an **ImageStream** in the internal registry.

```bash
oc new-build --name=rack-demo --binary --strategy=docker
oc start-build rack-demo --from-dir=../app --follow
oc get imagestream rack-demo
oc apply -f rack-demo.yaml
oc rollout status deploy/rack-demo
oc exec deploy/rack-demo -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/').read().decode())"
```

The output shows a UID from your project's range and group 0, which is exactly what the image was built for.

Change something in `../app/app.py`, run `oc start-build` again, and watch the Deployment roll out by itself. That's the `image.openshift.io/triggers` annotation.

## Checks

- [ ] You can explain the nginx crash in two sentences.
- [ ] `oc get pod -o yaml` for rack-demo shows `openshift.io/scc: restricted-v2`.
- [ ] The app reports a UID from the project range and group 0.
- [ ] A rebuild triggers a rollout without editing the Deployment.

## On the Developer Sandbox

Steps 1, 2, 4 and 5 work in your pre-created project (skip `oc new-project`). Step 3 needs cluster-admin.

## Interview line

> "When a vendor image crash-loops on OpenShift, I first check the SCC and the UID it got. Usually the image expects root or a fixed UID. I don't grant `anyuid`; I fix the image so its writable paths belong to group 0 and are group-writable, and it listens on a high port. Then it runs under `restricted-v2` like everything else, and the security review stays clean."
