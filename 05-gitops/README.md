# 05 GitOps operator: install with OLM, deploy with Argo CD

On OpenShift, platform add-ons are installed as **operators** through the **Operator Lifecycle Manager (OLM)**, not with Helm charts. OLM handles install, upgrades within a channel, and dependencies. This module installs Red Hat OpenShift GitOps (Argo CD) and uses it to deploy an app from this repository.

Push this repository to GitHub first; Argo CD needs to read it.

Resources: OpenShift GitOps adds several pods. Start CRC with more memory for this module: `crc stop && CRC_MEMORY=12288 ../00-cluster/setup-crc.sh`, and close other apps.

## Steps

### 1. Find the operator in the catalog

```bash
oc get packagemanifests -n openshift-marketplace | grep -i gitops
oc describe packagemanifest openshift-gitops-operator -n openshift-marketplace | grep -A5 Channels
```

### 2. Install it

```bash
cd 05-gitops
oc apply -f operator.yaml
oc get subscription,installplan,csv -n openshift-gitops-operator -w    # wait for the CSV to show Succeeded
oc get pods -n openshift-gitops                                       # the default Argo CD instance
```

What happened: the **Subscription** asked for the operator from the `redhat-operators` catalog; OLM created an **InstallPlan**, then a **ClusterServiceVersion (CSV)**, which runs the operator; the operator created a default Argo CD instance in `openshift-gitops`.

### 3. Prepare the target project

Argo CD may only manage namespaces that say so with a label:

```bash
oc new-project rack-web
oc label namespace rack-web argocd.argoproj.io/managed-by=openshift-gitops
```

### 4. Point Argo CD at your repo and sync

```bash
REPO=https://github.com/<your-user>/openshift-platform-lab.git
sed "s#REPO_URL#$REPO#" application.yaml | oc apply -f -
oc get application rack-web -n openshift-gitops -w     # Synced / Healthy
oc get pods,route -n rack-web
```

Open the Argo CD UI:

```bash
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='https://{.spec.host}{"\n"}'
oc extract secret/openshift-gitops-cluster -n openshift-gitops --keys=admin.password --to=-
```

Log in as `admin` with that password.

### 5. See GitOps working

1. **Change in Git:** set `replicas: 3` in `app/deployment.yaml`, commit and push. Within about three minutes Argo CD rolls it out.
2. **Drift:** `oc scale deploy/rack-web -n rack-web --replicas=1`. Argo CD sets it back to 3 (`selfHeal: true`).
3. **Delete from Git:** remove the Route from `service-route.yaml` and push. Argo CD deletes it (`prune: true`).

## Why this matters on a shipped platform

- The cluster pulls its desired state; nothing outside needs access in. That suits customer networks that block inbound connections.
- On a disconnected site, the Git repository and the operator catalog are mirrored locally (module 07).
- Rollback is a Git revert, and the audit trail is the commit history.

## Checks

- [ ] The CSV for openshift-gitops-operator shows `Succeeded`.
- [ ] The Application is `Synced` and `Healthy`, and the rack-web Route answers.
- [ ] A manual scale is reverted, and a Git change rolls out.

## Interview line

> "On OpenShift I install add-ons as operators through OLM: a Subscription to a channel, with manual approval of install plans on production so upgrades happen in a change window. For applications, OpenShift GitOps pulls from Git, which also works when the customer allows no inbound access."
