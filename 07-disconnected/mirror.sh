#!/usr/bin/env bash
# Mirror images for a disconnected site with oc-mirror v2.
#
#   ./mirror.sh dry-run              list what would be mirrored (no download)
#   ./mirror.sh to-disk              connected side: download into ./mirror (a tarball to carry in)
#   ./mirror.sh to-registry <host>   disconnected side: push ./mirror into the site registry
#
#   PULL_SECRET  default ~/.openshift/pull-secret.json (oc-mirror reads registry auth from it)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HERE/imageset-config.yaml"
WORKDIR="$HERE/working-dir"
PULL_SECRET="${PULL_SECRET:-$HOME/.openshift/pull-secret.json}"

command -v oc-mirror >/dev/null || { echo "oc-mirror not found; see README"; exit 1; }
[[ -f "$PULL_SECRET" ]] || { echo "pull secret not found: $PULL_SECRET"; exit 1; }
export REGISTRY_AUTH_FILE="$PULL_SECRET"

case "${1:-}" in
  dry-run)
    oc-mirror --v2 -c "$CONFIG" --workspace "file://$WORKDIR" "file://$HERE/mirror" --dry-run
    echo "image list: $WORKDIR/working-dir/dry-run/mapping.txt"
    ;;
  to-disk)
    oc-mirror --v2 -c "$CONFIG" "file://$HERE/mirror"
    du -sh "$HERE/mirror"
    ;;
  to-registry)
    host="${2:?usage: $0 to-registry registry.example:8443}"
    oc-mirror --v2 -c "$CONFIG" --from "file://$HERE/mirror" "docker://$host"
    echo "apply the generated resources on the cluster:"
    ls "$HERE"/mirror/working-dir/cluster-resources/ 2>/dev/null || true
    ;;
  *)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
