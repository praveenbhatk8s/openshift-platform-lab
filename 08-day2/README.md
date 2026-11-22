# 08 Day 2: backups, diagnostics, node config, upgrades

The install is the easy part. This module covers what keeps a cluster healthy afterwards. Most of it runs on CRC; where CRC differs from a real cluster, it says so.

## 1. Health at a glance

```bash
oc get clusterversion
oc get co                                  # every ClusterOperator: Available=True, Degraded=False
oc get nodes -o wide
oc adm top nodes
oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
oc get events -A --sort-by=.lastTimestamp | tail -20
```

If a ClusterOperator is degraded: `oc describe co <name>` shows the message, and the operator's namespace (`openshift-<name>`) has the pods and logs.

## 2. etcd backup

```bash
NODE=$(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[0].metadata.name}')
oc debug node/$NODE -- chroot /host /usr/local/bin/cluster-backup.sh /home/core/backup
oc debug node/$NODE -- chroot /host ls -lh /home/core/backup
```

You get two files: an etcd snapshot (`snapshot_<date>.db`) and the static pod resources (`static_kuberesources_<date>.tar.gz`). Both are needed to restore.

On a real cluster:
- Copy them off the node (a node failure would take the backup with it). Automate it: a CronJob, or the cluster's built-in etcd backup feature if your version has it.
- Restore is a documented, disruptive procedure (`cluster-restore.sh` on one recovery control-plane node). Practise it on a throwaway cluster before you need it.
- etcd backups cover cluster state, not application data. For namespaces and persistent volumes use **OADP** (the OpenShift API for Data Protection, based on Velero) with an object store.

## 3. must-gather

What Red Hat support asks for first, and useful for you too:

```bash
oc adm must-gather --dest-dir=./must-gather            # several hundred MB; takes a few minutes
ls must-gather/*/
oc adm inspect ns/rack-demo --dest-dir=./must-gather-rack-demo   # smaller: one namespace
```

`must-gather*/` is in `.gitignore`; it can contain sensitive data.

## 4. Node configuration with MachineConfig

On OpenShift you don't SSH in and edit files on nodes. The Machine Config Operator (MCO) applies `MachineConfig` objects to pools of nodes and reboots them one by one.

```bash
oc get mcp                                  # pools: master, worker
oc get mc | tail                            # rendered configs
oc debug node/$NODE -- chroot /host cat /etc/chrony.conf
```

Example: point nodes at the site's NTP server ([`machineconfig-chrony.yaml`](machineconfig-chrony.yaml)). Read it, but on CRC applying it reboots the only node and can leave CRC in a bad state, so only apply on a cluster you can afford to break:

```bash
oc apply -f machineconfig-chrony.yaml
oc get mcp master -w                        # UPDATING=True, then UPDATED=True
```

To build the base64 for your own server line: `printf 'server 10.20.0.1 iburst\n' | base64`.

## 5. Certificates

Soonest-expiring TLS secrets in the cluster:

```bash
cd 08-day2
oc get secret -A --field-selector type=kubernetes.io/tls -o json | python3 cert-expiry.py | head -15
```

Platform certificates rotate themselves. Certificates you supply (router default, API) don't: replacing them is a Day 2 task:

```bash
oc create secret tls custom-ingress --cert=wildcard.crt --key=wildcard.key -n openshift-ingress
oc patch ingresscontroller default -n openshift-ingress-operator --type merge \
  -p '{"spec":{"defaultCertificate":{"name":"custom-ingress"}}}'
```

## 6. Upgrades

```bash
oc adm upgrade                               # current channel, available updates
oc get clusterversion -o jsonpath='{.items[0].spec.channel}{"\n"}'
```

How upgrades go on a real cluster:
1. Read the release notes and check the update path (Red Hat's update graph tool).
2. Disconnected: mirror the target version first (module 07).
3. `oc adm upgrade --to=<version>`, then watch `oc get clusterversion` and `oc get co` and `oc get mcp`.
4. Control plane updates first, then MCO reboots nodes pool by pool. Pod disruption budgets and enough spare capacity decide whether workloads stay up.
5. Operators installed with OLM upgrade separately, by their own channel and approval.

CRC can't be upgraded in place; you install a newer CRC release.

## Checks

- [ ] You've taken an etcd backup on CRC and listed the two files.
- [ ] You've run must-gather and found a ClusterOperator's logs in it.
- [ ] You can explain why you'd use a MachineConfig instead of SSH.

## Interview line

> "Day 2 for me is: etcd backups copied off the nodes and a restore practised, OADP for application data, must-gather when something breaks, node changes only through MachineConfig, and upgrades planned along the update graph, mirrored first on disconnected sites, with the MCO rolling nodes one at a time."
