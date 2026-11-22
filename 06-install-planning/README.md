# 06 Install planning: OpenShift on bare metal with the agent-based installer

How would you install OpenShift on a rack of servers at a customer site? This module walks through the agent-based installer for a compact three-node cluster: the decisions, the two configuration files, and the commands. You validate everything locally; you don't need the hardware.

## The decisions, in order

| Decision | Choice here | Why |
| --- | --- | --- |
| Topology | Compact: 3 nodes, each control plane and worker | HA in the smallest footprint. Add workers later if the site grows. |
| Installer | Agent-based | Bare metal, works without internet, no extra bootstrap machine. Boot every server from one ISO. |
| Network plugin | OVN-Kubernetes | The default; needed for EgressFirewall and EgressIP. |
| Load balancing | Built-in API and ingress VIPs | keepalived on the nodes holds two virtual IPs; no external load balancer in the rack. |
| Addressing | Static IPs per host (NMState) | Customer networks often have no DHCP for servers. |
| Disconnected | Optional, via a local mirror registry | Module 07. |

## Before the install: the site checklist

- **DNS** (in the customer's DNS, or a DNS server shipped in the rack):

  | Record | Points to |
  | --- | --- |
  | `api.rack01.customer.example` | API VIP 10.20.0.5 |
  | `api-int.rack01.customer.example` | API VIP 10.20.0.5 |
  | `*.apps.rack01.customer.example` | Ingress VIP 10.20.0.6 |
  | `master-0/1/2.rack01.customer.example` | 10.20.0.11 to .13 (forward and reverse) |

- **IP plan:** the machine network, two VIPs, and internal cluster and service ranges that don't overlap anything the customer uses.
- **NTP** reachable from every node. Clock drift breaks certificates and etcd.
- **Disks:** fast SSD or NVMe for the control plane. etcd is very sensitive to disk latency; slow disks show up as API timeouts and leader elections.
- **BMC access** (iDRAC, iLO) to boot the ISO as virtual media.
- **Firewall:** outbound to Red Hat's registries, or a mirror registry for disconnected sites.
- **Hardware minimums:** check Red Hat's documentation for your OpenShift version.

## Steps

### 1. Get the installer

Match the version you want to install. Two ways:

```bash
# A: download the client for your OS from the public mirror (pick the version folder)
#    https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
#    files: openshift-install-mac-arm64.tar.gz, openshift-install-linux.tar.gz, ...
tar xzf openshift-install-*.tar.gz openshift-install

# B: extract it from a release image (needs your pull secret)
oc adm release extract --registry-config ~/.openshift/pull-secret.json \
  --command=openshift-install --to=. quay.io/openshift-release-dev/ocp-release:<version>-x86_64
```

### 2. Read the two files

- [`install-config.yaml.template`](install-config.yaml.template): the cluster (name, domain, networks, VIPs, credentials).
- [`agent-config.yaml`](agent-config.yaml): the machines (hostname, role, MAC, disk, static IP, DNS, gateway) and the rendezvous host that coordinates the install.

Change one thing and predict its effect before you run step 3, for example an IP outside the machine network.

### 3. Render and validate

```bash
cd 06-install-planning
./render.sh
```

The installer checks the configuration and writes the cluster manifests into `work/`. Errors here are the same ones you'd hit on site, so it's cheap practice: try a VIP outside `machineNetwork`, a duplicate MAC address, or `replicas: 2` for the control plane, and read the messages.

### 4. Optional: build the ISO

```bash
./render.sh --image
```

This downloads the base image (about 1 GB) and needs `nmstatectl` for the static network configuration, which is easiest on Linux. On a Mac, run it in a Linux container:

```bash
podman run --rm -it -v "$PWD/..:/lab" -v ~/.openshift:/root/.openshift:ro -v ~/.ssh:/root/.ssh:ro \
  registry.access.redhat.com/ubi9/ubi bash
dnf install -y nmstate python3 && cd /lab/06-install-planning && ./render.sh --image
```

(Use the Linux build of `openshift-install` inside the container.)

### 5. On real hardware, the rest of the install

1. Boot all three servers from `agent.x86_64.iso` through the BMC.
2. Watch: `openshift-install agent wait-for bootstrap-complete --dir work`
3. Then: `openshift-install agent wait-for install-complete --dir work`
4. Log in with `work/auth/kubeconfig`, check `oc get nodes` and `oc get co`.
5. Day 1 tasks: identity provider and remove kubeadmin (module 04), customer certificates on the router and API, storage (OpenShift Data Foundation or the customer's CSI driver), etcd backups (module 08).

## Other install methods, for comparison

| Method | When |
| --- | --- |
| IPI (installer-provisioned) | AWS, Azure, vSphere: the installer creates the machines and load balancers itself |
| UPI (user-provisioned) | You prepare every machine and load balancer; strict datacentre processes |
| Assisted Installer | Like agent-based but driven from console.redhat.com; needs internet |
| Single-node (SNO) | One server, no HA; edge sites |
| ROSA / ARO | Managed OpenShift on AWS / Azure |

## Checks

- [ ] `./render.sh` completes and `work/cluster-manifests/` exists.
- [ ] You've broken the config three ways and understood each error.
- [ ] You can list the DNS records and IPs needed before arriving on site.

## Interview line

> "For a rack at a customer site I'd install a compact three-node cluster with the agent-based installer: one ISO, booted on each server through the BMC, with static IPs and the API and ingress VIPs defined in the config, so there's no external load balancer. Before shipping, I'd confirm DNS for api, api-int and *.apps, NTP, and fast disks for etcd, and for disconnected sites I'd ship a mirror registry with the release and operator images."
