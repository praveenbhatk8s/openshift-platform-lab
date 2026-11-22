# 03 Network policy and egress control

On a platform sitting in a customer's datacentre, the customer's security team will ask two questions: what can reach your apps, and what can your apps reach? This module answers both, step by step, and shows the two OpenShift-specific details that catch people out.

Needs modules 01 and 02 (`rack-demo` and its Routes). Run `./check.sh` after every step and compare with the table.

## Steps and expected results

| Step | Command | 1. router to app | 2. DNS | 3. example.com | 3. redhat.com |
| --- | --- | --- | --- | --- | --- |
| 0. Start | `./check.sh` | 200 | resolves | 200 | 200 |
| 1. Deny all ingress | `oc apply -f default-deny-ingress.yaml` | **503** | resolves | 200 | 200 |
| 2. Allow the router | `oc apply -f allow-from-router.yaml` | 200 | resolves | 200 | 200 |
| 3. Deny all egress | `oc apply -f default-deny-egress.yaml` | 200 | **fails** | fails | fails |
| 4. Allow DNS on 5353 | `oc apply -f allow-dns.yaml` | 200 | resolves | **times out** | times out |
| 5. Swap to an egress firewall | `oc delete -f default-deny-egress.yaml -f allow-dns.yaml` then `oc apply -f egressfirewall.yaml` | 200 | resolves | 200 | **blocked** |

Step 1's 503 is the router's "Application is not available" page: the router can't reach any pod, so it has no healthy backend.

## The two OpenShift details

1. **Allow the router by its namespace label, not by IP.** On OVN-Kubernetes the router's namespace has the label `policy-group.network.openshift.io/ingress: ""`. Forget this policy and every Route returns 503 while the pods look healthy.
2. **DNS listens on 5353.** The DNS Service answers on 53, but the pods behind it listen on 5353, and network policy is evaluated against the pod port. An egress rule for port 53 only breaks name resolution. Drill 3 in module 09 does this.

## NetworkPolicy vs EgressFirewall

| | NetworkPolicy | EgressFirewall |
| --- | --- | --- |
| Standard | Kubernetes | OVN-Kubernetes (OpenShift) |
| Controls | Traffic between pods, and by IP block | Traffic leaving the cluster only |
| Targets | Pods and namespaces by label, IP ranges | DNS names and CIDRs |
| Per project | Many policies, combined | Exactly one, named `default` |
| Typical use | Isolate tenants and tiers | "This project may only reach the customer's API and their NTP server" |

For a fixed source address that the customer's firewall can allow, OpenShift adds **EgressIP**: traffic from a project leaves through a known IP. That needs an extra address on the node network, so it isn't part of this lab on CRC.

## Clean up for the next module

```bash
oc delete -f egressfirewall.yaml -f allow-from-router.yaml -f default-deny-ingress.yaml --ignore-not-found
```

## Checks

- [ ] Your results match the table at every step.
- [ ] You can explain why step 1 gave 503 and not a timeout at the client.
- [ ] You can explain why 5353, not 53.

## Interview line

> "Every customer project starts with default-deny in both directions. Then I allow the router in by its namespace label, allow DNS on 5353, which is the detail people miss on OpenShift, and control what leaves the cluster with an EgressFirewall by DNS name. That gives the customer's security team a short, readable list of allowed flows."
