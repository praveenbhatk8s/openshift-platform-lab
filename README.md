# OpenShift Platform Lab

Hands-on practice for running OpenShift as a platform shipped to a customer site: a compact cluster in the customer's datacentre, often with limited or no internet, where the hardware is someone else's job and the platform is yours.

Each module is small, self-contained and ends with checks you can run. Work through them in order.

## Modules

| # | Module | What you practise | Runs on CRC | Runs on Developer Sandbox |
| --- | --- | --- | --- | --- |
| 00 | [Cluster](00-cluster/) | Start OpenShift Local, tour the cluster: nodes, ClusterOperators, ClusterVersion | Yes | Partly (no node or operator view) |
| 01 | [Workload and SCC](01-workload-scc/) | Why images fail on OpenShift, arbitrary UIDs, BuildConfig and ImageStream | Yes | Yes, except changing SCCs |
| 02 | [Routes and TLS](02-routes-tls/) | Edge, re-encrypt and passthrough Routes; service serving certificates | Yes | Yes |
| 03 | [Network policy and egress](03-network-policy/) | Default deny, allowing the router and DNS, EgressFirewall | Yes | NetworkPolicy only |
| 04 | [Identity and RBAC](04-identity-rbac/) | htpasswd users, groups, roles, `oc auth can-i` | Yes | No |
| 05 | [GitOps operator](05-gitops/) | Install an operator with OLM, deploy an app with OpenShift GitOps | Yes (needs about 12 GB for CRC) | No |
| 06 | [Install planning](06-install-planning/) | Agent-based install on bare metal: install-config, agent-config, ISO | Runs anywhere (no cluster needed) | n/a |
| 07 | [Disconnected](07-disconnected/) | Mirror images with oc-mirror for sites without internet | Runs anywhere (needs a pull secret) | n/a |
| 08 | [Day 2](08-day2/) | etcd backup, must-gather, machine config pools, updates | Partly | No |
| 09 | [Break-fix drills](09-drills/) | Six faults to diagnose under time pressure | Yes | Most drills |

## Prerequisites

- **OpenShift Local (CRC)** from [console.redhat.com/openshift/create/local](https://console.redhat.com/openshift/create/local) with a free Red Hat developer account. Needs 4 CPUs, about 11 GB of RAM and 35 GB of disk. On a 16 GB Mac, close other apps while it runs.
- **`oc` CLI** (CRC ships one: `eval $(crc oc-env)`).
- **`curl`, `openssl`, `htpasswd`** (all present on macOS).
- **Your pull secret** saved as `~/.openshift/pull-secret.json` (downloaded from the same page). Never commit it.

If you only have the [Developer Sandbox](https://developers.redhat.com/developer-sandbox), modules 01 to 03 still work in your pre-created project.

## How each module is laid out

- `README.md`: the goal, the steps, the checks, and what to say about it in an interview.
- YAML manifests you apply with `oc apply -f`.
- Small scripts for anything with more than three commands.

## The demo app

[`app/`](app/) is a tiny Python service with no dependencies. It reports the UID it runs as (so you can see OpenShift's arbitrary UIDs) and serves HTTPS on 8443 when a certificate is mounted (so you can test every Route type).

## Interview notes

[`INTERVIEW.md`](INTERVIEW.md) maps Kubernetes concepts to their OpenShift equivalents and lists the questions each module prepares you for.

## Clean up

```bash
oc delete project rack-demo rack-web rack-drill --ignore-not-found
crc stop        # keeps the cluster; crc delete removes it
```
