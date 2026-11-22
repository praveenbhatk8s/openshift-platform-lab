#!/usr/bin/env bash
# Add lab users to the cluster's existing htpasswd identity provider without removing
# kubeadmin or the CRC "developer" user, then put them in groups.
#
#   alice  - operations team: can view and restart, cannot read secrets
#   bob    - delivery team: can edit the project
#   carol  - auditor: read only
#
# Password for all three: LAB_PASSWORD (default "Lab-Pass-2026"). Lab use only.
set -euo pipefail

LAB_PASSWORD="${LAB_PASSWORD:-Lab-Pass-2026}"
command -v htpasswd >/dev/null || { echo "htpasswd not found (macOS has it; on Linux install httpd-tools)"; exit 1; }

# Find the secret behind the existing HTPasswd identity provider (on CRC it already exists).
SECRET=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.type=="HTPasswd")].htpasswd.fileData.name}')
if [[ -z "$SECRET" ]]; then
  echo "No HTPasswd identity provider found. See README, section 'On a cluster without htpasswd'."
  exit 1
fi
echo "Existing htpasswd secret: openshift-config/$SECRET"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
oc extract "secret/$SECRET" -n openshift-config --keys=htpasswd --to="$WORK" --confirm >/dev/null

for user in alice bob carol; do
  htpasswd -B -b "$WORK/htpasswd" "$user" "$LAB_PASSWORD" 2>/dev/null
done
oc set data "secret/$SECRET" -n openshift-config --from-file=htpasswd="$WORK/htpasswd"
echo "Users added. The authentication operator rolls out the change; logins work in about a minute."

# Groups: access is granted to groups, never to individuals.
for pair in "ops:alice" "delivery:bob" "auditors:carol"; do
  group="${pair%%:*}"; member="${pair##*:}"
  oc adm groups new "$group" 2>/dev/null || true
  oc adm groups add-users "$group" "$member"
done
oc get groups
