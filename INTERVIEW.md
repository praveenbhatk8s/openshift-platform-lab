# Talking about OpenShift: from Kubernetes experience to OpenShift answers

Notes for explaining OpenShift in an interview when most of your production experience is upstream Kubernetes or an older distribution such as IBM Cloud Private. Only claim what you've actually done; the modules in this repo are how you get there.

## What maps to what

| You already know | On OpenShift | Module |
| --- | --- | --- |
| kubeadm / ICP installer, Ansible inventory | Agent-based installer (bare metal), IPI (cloud) | 06 |
| keepalived VIP in front of the masters | `apiVIPs` / `ingressVIPs`, keepalived managed by the platform | 06 |
| Ingress + NGINX ingress controller | Route + HAProxy router (Ingress objects also work) | 02 |
| PodSecurityPolicy / Pod Security Admission | Security Context Constraints (restricted-v2 by default) | 01 |
| Helm charts for platform add-ons | Operators through OLM (Subscription, InstallPlan, CSV) | 05 |
| Private registry + image pull secrets | Internal registry, ImageStreams, BuildConfig | 01 |
| Calico network policies | OVN-Kubernetes: NetworkPolicy, EgressFirewall, EgressIP | 03 |
| LDAP via a separate auth component | OAuth server with identity providers, groups | 04 |
| SSH to nodes, config management | MachineConfig, Machine Config Operator, RHCOS | 08 |
| etcd snapshot CronJob | `cluster-backup.sh`; OADP (Velero) for app data | 08 |
| Air-gapped image copies by script | oc-mirror, IDMS, mirrored CatalogSource | 07 |
| Cluster upgrade runbooks | ClusterVersion, update channels, MCO rolling reboots | 08 |

## Questions to be ready for

**Why does an image that runs on Kubernetes fail on OpenShift?**
OpenShift runs containers as a random non-root UID from the project's range, with group 0. Images that assume root, write to root-owned paths or bind ports below 1024 fail. Fix the image (group 0 permissions, port 8080, UBI base), don't grant `anyuid`.

**How would you install OpenShift on a rack at a customer site?**
Compact three-node cluster with the agent-based installer, static IPs and VIPs in the config, DNS for api, api-int and *.apps prepared in advance, NTP, fast disks for etcd. Disconnected: a mirror registry shipped with the rack.

**How do you expose an app with TLS?**
A Route: edge (TLS ends at the router), re-encrypt (router to pod is TLS again, with a service CA certificate), or passthrough (the pod terminates TLS; the router only sees SNI).

**How do you isolate tenants or apps?**
Projects, RBAC on groups from the identity provider, a default-deny NetworkPolicy plus explicit allows (router, DNS, the other services needed), EgressFirewall for outbound, quotas and limit ranges.

**How do you keep a cluster up to date on a disconnected site?**
Mirror the next version and operator updates with oc-mirror, bring them in, push to the site registry, then `oc adm upgrade`. Control plane first, then the MCO reboots nodes one at a time.

**Something is broken. Where do you start?**
`oc get co` for the platform, then follow the request path for an app: Route, Service, Endpoints, pod readiness, the container port, network policy. `oc adm must-gather` for anything going to Red Hat support.

## Being honest about experience

Say what you ran in production, what you've practised in a lab, and what you've only read about. "I ran upstream Kubernetes in production; I've practised OpenShift's install, networking and Day 2 tasks in a lab, and the concepts map closely" is stronger than overclaiming.
