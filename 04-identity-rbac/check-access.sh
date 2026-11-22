#!/usr/bin/env bash
# Prove each group has exactly the access intended, using impersonation (no logins needed).
set -uo pipefail
NS="${NS:-rack-demo}"
fail=0

check() { # check <expected yes|no> <user> <group> <verb> <resource>
  local want="$1" user="$2" group="$3"; shift 3
  local got
  got=$(oc auth can-i "$@" -n "$NS" --as="$user" --as-group="$group" --as-group=system:authenticated 2>/dev/null)
  local mark="ok"; [[ "$got" != "$want" ]] && { mark="WRONG"; fail=1; }
  printf '%-6s %-7s %-10s %-28s want=%-3s got=%-3s\n' "$mark" "$user" "($group)" "$*" "$want" "$got"
}

check yes alice ops      get pods/log
check yes alice ops      patch deployments
check no  alice ops      get secrets
check no  alice ops      delete deployments
check yes bob   delivery create deployments
check yes bob   delivery get secrets
check yes carol auditors list pods
check no  carol auditors get secrets
check no  carol auditors patch deployments

echo
[[ $fail -eq 0 ]] && echo "All access checks as intended." || echo "Some checks differ from the intent."
exit $fail
