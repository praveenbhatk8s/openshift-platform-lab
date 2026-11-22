#!/usr/bin/env bash
# Start OpenShift Local (CRC) sized for this lab, and log in as cluster-admin.
#
#   CRC_MEMORY  MiB of RAM for the cluster VM (default 10752; use 12288 for module 05)
#   CRC_CPUS    vCPUs (default 4)
#   PULL_SECRET path to your pull secret (default ~/.openshift/pull-secret.json)
set -euo pipefail

CRC_MEMORY="${CRC_MEMORY:-10752}"
CRC_CPUS="${CRC_CPUS:-4}"
PULL_SECRET="${PULL_SECRET:-$HOME/.openshift/pull-secret.json}"

command -v crc >/dev/null || { echo "Install OpenShift Local (crc) first."; exit 1; }
[[ -f "$PULL_SECRET" ]] || { echo "Pull secret not found at $PULL_SECRET"; exit 1; }

crc config set preset openshift
crc config set memory "$CRC_MEMORY"
crc config set cpus "$CRC_CPUS"
crc config set consent-telemetry no

crc setup
crc start --pull-secret-file "$PULL_SECRET"

eval "$(crc oc-env)"
KUBEADMIN_PASSWORD=$(crc console --credentials -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["clusterConfig"]["adminCredentials"]["password"])')
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true

echo
echo "Logged in as $(oc whoami). Console: $(crc console --url)"
echo "In new terminals run: eval \$(crc oc-env)"
