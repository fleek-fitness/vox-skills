#!/usr/bin/env bash
# Verify the Codex bundle (plugins/vox-ai/) stays in sync with the canonical
# top-level skills/ + .mcp.json, and that the two plugin manifests agree on version.
#
# Background: the symlink that used to keep plugins/vox-ai/skills and
# plugins/vox-ai/.mcp.json in sync was removed (commit 47da8b6) so the Codex
# installer copies real files into its cache. Nothing replaced that guard, so
# the bundle could silently drift. This script is that guard.
#
# Run locally before committing:  bash scripts/check-bundle-sync.sh
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "→ skills/ == plugins/vox-ai/skills/"
if ! diff -rq skills plugins/vox-ai/skills; then
  echo "  ✗ Codex skills bundle drift (see diff above)"
  fail=1
else
  echo "  ok"
fi

echo "→ .mcp.json == plugins/vox-ai/.mcp.json"
if ! diff -q .mcp.json plugins/vox-ai/.mcp.json >/dev/null; then
  echo "  ✗ .mcp.json drift between repo root and Codex bundle"
  diff .mcp.json plugins/vox-ai/.mcp.json || true
  fail=1
else
  echo "  ok"
fi

echo "→ version lockstep (.claude-plugin/marketplace.json vs .codex-plugin/plugin.json)"
claude_v=$(jq -r '.metadata.version' .claude-plugin/marketplace.json)
codex_v=$(jq -r '.version' plugins/vox-ai/.codex-plugin/plugin.json)
if [ "$claude_v" != "$codex_v" ]; then
  echo "  ✗ version skew: marketplace.json=$claude_v vs plugin.json=$codex_v"
  fail=1
else
  echo "  ok ($claude_v)"
fi

echo "→ Claude marketplace skills cover skills/"
expected_skills="$(mktemp)"
claude_skills="$(mktemp)"
find skills -mindepth 1 -maxdepth 1 -type d -print \
  | sed 's#^#./#' \
  | sort >"$expected_skills"
jq -r '.plugins[] | select(.name == "vox-ai") | .skills[]' .claude-plugin/marketplace.json \
  | sort >"$claude_skills"
if ! diff -u "$expected_skills" "$claude_skills"; then
  echo "  ✗ Claude marketplace skill list drift"
  fail=1
else
  echo "  ok"
fi
rm -f "$expected_skills" "$claude_skills"

if [ "$fail" -ne 0 ]; then
  cat >&2 <<'EOF'

Bundle sync check FAILED. To reconcile:
  rsync -a --delete skills/ plugins/vox-ai/skills/
  cp .mcp.json plugins/vox-ai/.mcp.json
  # ensure .claude-plugin/marketplace.json plugins[0].skills lists every ./skills/<name>
  # and set both manifests to the same version
EOF
  exit 1
fi

echo "All bundle sync checks passed."
