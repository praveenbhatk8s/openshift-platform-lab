#!/usr/bin/env bash
# Render the install files into work/ and let the installer validate them.
#
#   ./render.sh            render and validate (creates work/cluster-manifests)
#   ./render.sh --image    also build the agent ISO (downloads about 1 GB; Linux with nmstatectl)
#
#   PULL_SECRET   default ~/.openshift/pull-secret.json
#   SSH_PUB_KEY   default ~/.ssh/id_ed25519.pub
#   INSTALLER     path to openshift-install (default: ./openshift-install, then PATH)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/work"
PULL_SECRET="${PULL_SECRET:-$HOME/.openshift/pull-secret.json}"
SSH_PUB_KEY="${SSH_PUB_KEY:-$HOME/.ssh/id_ed25519.pub}"

if [[ -n "${INSTALLER:-}" ]]; then :
elif [[ -x "$HERE/openshift-install" ]]; then INSTALLER="$HERE/openshift-install"
else INSTALLER="$(command -v openshift-install || true)"
fi
[[ -x "$INSTALLER" ]] || { echo "openshift-install not found; see README, step 1"; exit 1; }
[[ -f "$PULL_SECRET" ]] || { echo "pull secret not found: $PULL_SECRET"; exit 1; }
[[ -f "$SSH_PUB_KEY" ]] || { echo "ssh public key not found: $SSH_PUB_KEY"; exit 1; }

# The installer consumes (deletes) its input files, so always work on fresh copies.
rm -rf "$WORK"
mkdir -p "$WORK"

python3 -I - "$HERE/install-config.yaml.template" "$PULL_SECRET" "$SSH_PUB_KEY" "$WORK/install-config.yaml" <<'EOF'
import json, sys
template, pull_secret, ssh_key, out = sys.argv[1:5]
secret = json.dumps(json.load(open(pull_secret)), separators=(",", ":"))  # one line, validated JSON
key = open(ssh_key).read().strip()
text = open(template).read().replace("__PULL_SECRET__", secret).replace("__SSH_KEY__", key)
open(out, "w").write(text)
EOF
cp "$HERE/agent-config.yaml" "$WORK/agent-config.yaml"

echo "installer: $("$INSTALLER" version | head -1)"
echo "validating and generating cluster manifests ..."
"$INSTALLER" agent create cluster-manifests --dir "$WORK" --log-level warn
echo
echo "generated:"
find "$WORK" -type f | sed "s#$WORK/##" | sort

if [[ "${1:-}" == "--image" ]]; then
  echo
  echo "building the agent ISO (downloads the base image) ..."
  "$INSTALLER" agent create image --dir "$WORK" --log-level info
  ls -lh "$WORK"/*.iso
fi
