#!/usr/bin/env bash
# A guided look at what makes an OpenShift cluster different from plain Kubernetes.
# Read each section's output before moving on; the README explains what to look for.
set -uo pipefail

section() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

section "Who am I, and which cluster"
oc whoami
oc whoami --show-server
oc version

section "Cluster version and update channel (the Cluster Version Operator owns upgrades)"
oc get clusterversion
oc get clusterversion version -o jsonpath='{.spec.channel}{"\n"}'

section "ClusterOperators: every platform component reports Available / Progressing / Degraded"
oc get clusteroperators

section "Nodes and their roles (CRC: one node is both control plane and worker)"
oc get nodes -o wide

section "Machine config pools (how node OS configuration is rolled out)"
oc get machineconfigpools 2>/dev/null || echo "not available on this cluster"

section "Network type (OVN-Kubernetes is the default)"
oc get network.config cluster -o jsonpath='{.status.networkType}{"\n"}'

section "Ingress: the router and the apps domain that Routes use"
oc get ingresscontroller -n openshift-ingress-operator
oc get ingresses.config cluster -o jsonpath='{.spec.domain}{"\n"}'
oc get pods -n openshift-ingress

section "DNS: cluster DNS runs in openshift-dns and listens on 5353"
oc get pods -n openshift-dns -o wide
oc get svc -n openshift-dns

section "Security context constraints (OpenShift's pod admission)"
oc get scc

section "Internal image registry"
oc get configs.imageregistry.operator.openshift.io cluster -o jsonpath='{.spec.managementState}{"\n"}'
oc get route -n openshift-image-registry 2>/dev/null || echo "registry route not exposed (normal)"

section "Operators installed through OLM"
oc get csv -A 2>/dev/null | head -20
