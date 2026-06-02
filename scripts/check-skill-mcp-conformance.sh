#!/usr/bin/env bash
# Verify every vox MCP tool referenced under skills/ actually exists in the vox MCP
# public surface, and surface manifest tools that no skill mentions.
#
# Background: skills/ docs hand-write MCP tool names in prose/examples. When the MCP
# tool surface changes (Track 2 renamed create_custom_tool → create_tool, etc.) a
# stale doc can point users at a phantom tool that no longer exists. This script is
# that guard: manifest = scripts/vox-mcp-public-tools.json (a vendored snapshot of
# vox-mcp PUBLIC_TOOL_NAMES; see scripts/vox-mcp-public-tools.README.md to refresh).
#
# Run locally before committing:  bash scripts/check-skill-mcp-conformance.sh
set -euo pipefail
cd "$(dirname "$0")/.."

manifest="scripts/vox-mcp-public-tools.json"

# Known non-tool snake_case tokens that match the prefix regex but are NOT MCP tools.
# Keep minimal and justified. NOTE: phantom MCP tools (e.g. create_custom_tool,
# delete_custom_tool, list_custom_tools, list_built_in_tools) MUST NOT be ignored —
# the whole point is to fail on those. Only genuinely-non-tool tokens belong here.
IGNORE=(
  # (none yet — add tokens only with a one-line reason)
)

# Allow an external ignore-list file (one token per line, # comments allowed).
ignore_file="scripts/conformance-ignore.txt"
if [ -f "$ignore_file" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && IGNORE+=("$line")
  done < "$ignore_file"
fi

is_ignored() {
  local tok="$1"
  for ig in "${IGNORE[@]:-}"; do [ "$tok" = "$ig" ] && return 0; done
  return 1
}

fail=0

# Manifest tool names (one per line).
manifest_tools="$(jq -r '.[]' "$manifest" | sort -u)"

# Candidate tool references in skills/: a token matching the MCP tool prefix regex
# that appears either inside backticks (`tool`) or immediately followed by "(".
# We extract over .md/.json under skills/, then keep only prefix-shaped tokens.
re='^(list|get|create|update|delete|set|validate|autofix)_[a-z_]+$'

candidates="$(
  grep -rhoE --include='*.md' --include='*.json' \
    -e '`[a-z_]+`' \
    -e '[a-z_]+\(' \
    skills/ 2>/dev/null \
  | tr -d '`(' \
  | grep -E "$re" \
  | sort -u || true
)"

echo "→ phantom vox tools (referenced by skills/ but not in $manifest)"
phantom=""
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  is_ignored "$tok" && continue
  if ! grep -qxF "$tok" <<<"$manifest_tools"; then
    phantom+="  ✗ $tok"$'\n'
  fi
done <<<"$candidates"

if [ -n "$phantom" ]; then
  printf '%s' "$phantom"
  fail=1
else
  echo "  ok"
fi

echo "→ unreferenced manifest tools (warn only)"
unref=""
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  if ! grep -qxF "$tok" <<<"$candidates"; then
    unref+="  ⚠ $tok"$'\n'
  fi
done <<<"$manifest_tools"

if [ -n "$unref" ]; then
  printf '%s' "$unref"
  echo "  (no skill references these — fine if intentional, e.g. internal/rarely-doc'd)"
else
  echo "  ok"
fi

if [ "$fail" -ne 0 ]; then
  cat >&2 <<EOF

Skill↔MCP conformance check FAILED. To reconcile:
  - Fix the skill doc to use a real tool from $manifest
    (e.g. create_custom_tool → create_tool, list_custom_tools → list_tools).
  - Or, if the tool was genuinely added to vox MCP, refresh the manifest:
    see scripts/vox-mcp-public-tools.README.md
  - Or, if the token is a false positive (non-MCP snake_case), add it to
    $ignore_file with a one-line reason.
EOF
  exit 1
fi

echo "All skill↔MCP conformance checks passed."
