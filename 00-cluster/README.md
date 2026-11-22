# 00 Cluster: start OpenShift Local and look around

OpenShift is Kubernetes plus a set of operators that manage the platform itself. This module gets a cluster running on your laptop and shows you where those operators live.

## Steps

```bash
cd 00-cluster
./setup-crc.sh            # takes 10 to 20 minutes the first time
./tour.sh | tee tour.txt  # read it section by section
```

On a 16 GB Mac, quit browsers and other heavy apps first. If CRC fails to start for memory, keep the default 10752 MiB and use fewer extras.

## What to look for in the tour

| Section | What it tells you |
| --- | --- |
| ClusterVersion | The installed version and update channel. Upgrades are a single declarative change here; the Cluster Version Operator does the rest. |
| ClusterOperators | About 30 operators run the platform: ingress, DNS, authentication, image registry, machine config. Healthy means `Available=True`, `Degraded=False`. This is the first thing to check after an install or upgrade. |
| Nodes | CRC has one node with both roles. A shipped rack would be a compact cluster: three nodes, each control plane and worker. |
| Machine config pools | How OS-level settings reach nodes: the Machine Config Operator writes them and reboots nodes one by one. |
| Network type | OVN-Kubernetes. It implements NetworkPolicy, EgressFirewall and EgressIP. |
| Ingress | The router pods (HAProxy) in `openshift-ingress`, and the apps domain (`apps-crc.testing`) every Route hostname is built from. |
| DNS | CoreDNS in `openshift-dns`, listening on port 5353 behind a Service on 53. This matters for egress network policies in module 03. |
| SCC | Security context constraints. Pods get `restricted-v2` unless something grants more. Module 01 is about this. |

## Checks

- [ ] `oc get co` shows every operator `Available=True`, `Degraded=False`.
- [ ] You can open the console URL and log in as `kubeadmin`.
- [ ] You can say in one sentence what a ClusterOperator is.

## Interview line

> "The first thing I check on any OpenShift cluster is `oc get clusteroperators`. Every platform component reports its own health there, so after an install or upgrade it tells you in one screen whether the platform is sound."
