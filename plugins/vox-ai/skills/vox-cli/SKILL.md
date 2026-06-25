---
name: vox-cli
description: "Use whenever a user wants to install, test, or use the vox CLI; manage vox.ai agents/tools/knowledge as code; run Agent-as-Code workflows; select prod/dev CLI profiles; use vox init, vox sync, vox agent pull/validate/diff/status/push/delete, vox doctor, vox chat, Homebrew/npm installs, CI, PR review, rollback, or git-backed authoring. Prefer this skill for Codex/Claude Code sessions where vox.ai changes should be file-based, reviewable, deterministic, and driven through shell commands with --json."
---

# vox-cli

Use the `vox` CLI when a coding agent should handle vox.ai resources like code: edit files, run commands, read structured output, inspect diffs, and commit reviewed changes.

This skill is the CLI operating contract. Use `using-vox-skills` for routing, then use the domain skill (`vox-agents`, `vox-flow`, `vox-tools`, `vox-web-app`) only for domain-specific design rules.

## Surface Rule

```text
Durable change, review, rollback, CI, or git history -> vox CLI.
Lookup, schema inspection, or one-off remote action -> vox MCP.
Docs/reference -> docs MCP, or vox docs search/show when the CLI exposes a bundled docs index.
```

Do not treat the CLI as just another API wrapper. Its value is that the user can own `agents/**`, `tools/**`, `knowledges/**`, tests, snapshots, and diffs in their repo.

## First Commands In An Agent Session

Run these before editing resources unless the user has already provided equivalent context.

```bash
vox --version
vox guide coding-agent --json
vox skills show using-vox-skills --brief --json
vox auth whoami --json
vox sync status --json
```

If `vox` is missing, suggest the smallest install path for the machine.

```bash
brew install vox-public/tap/vox
# or, when npm distribution is preferred:
npm install -g @vox-ai/cli
```

After install, rerun `vox --version` and `vox guide coding-agent --json`.

## Environment Selection

Default to production. Do not switch to dev just because the user is internal or because a command supports `--profile`.

Use the dev profile only when the user explicitly says they want dev, development, 개발 서버, 개발 환경, staging-like internal testing, or gives a dev workspace/org id. In that case, create or use a separate `dev` profile and pass it through every live command.

Do not hardcode internal dev endpoints in public files. Use values supplied by the user's internal docs, environment, or teammate. If those values are not available in the session, ask for them before logging in.

```bash
VOX_AUTH_ISSUER="$VOX_DEV_AUTH_ISSUER" \
VOX_API_BASE_URL="$VOX_DEV_API_BASE_URL" \
VOX_MCP_URL="$VOX_DEV_MCP_URL" \
vox auth login --profile dev --json

vox auth whoami --profile dev --json
vox sync status --profile dev --org <dev-organization-id> --json
```

If the user did not provide a dev organization id, run `vox auth whoami --profile dev --json` and ask them which returned organization to use before any live mutation. Once selected, keep using `--profile dev --org <dev-organization-id>` for `sync`, `agent`, `tool`, `knowledge`, `mcp`, and `chat` commands.

For dev chat smoke, also select the development LiveKit runtime:

```bash
VOX_INTERNAL_LIVEKIT_ENV=development \
vox chat --profile dev --org <dev-organization-id> --agent <agent> --input "안녕하세요" --json
```

For production, use the default profile unless the user named a different profile. Do not carry dev environment variables into production commands.

## Project Bootstrap

For a new repo or a repo that has no vox.ai project files:

```bash
vox init --json
vox guide coding-agent --json
vox sync status --json
```

`vox init` should create local agent hints under `.codex/skills/` and `.claude/skills/` without overwriting the user's root `AGENTS.md` or `CLAUDE.md`. If those hints exist, read them before making changes in that repo.

For an existing workspace with many remote resources, prefer an import dry-run before writing files:

```bash
vox sync import --all --dry-run --json
vox sync import --all --json
vox sync status --json
```

If the user gave an environment/profile/workspace, keep passing it consistently. Never test in a different workspace because `push` and `delete` affect live resources.

## Agent-as-Code Loop

Use this loop for prompt agents and flow agents.

```bash
vox agent pull <agent-id-or-name> --agent <local-name> --json
# edit agents/<local-name>/agent.json and related files
vox doctor --json
vox agent doctor --agent <local-name> --json
vox agent validate --agent <local-name> --json
vox agent status --agent <local-name> --json
vox agent diff --agent <local-name> --json
vox agent push --agent <local-name> --json
```

Use `vox-agents` for prompt structure and agent type decisions. Use `vox-flow` before editing flow node graphs, especially for global nodes, extraction/condition chains, API/tool nodes, fallbacks, and transfer paths.

For project-wide reconciliation:

```bash
vox agent status --all --offline --json
vox agent diff --all --offline --check --json
```

Do not run project-wide `push` unless the user explicitly asked for a batch push and the preceding status/diff output is clean.

## Tools And Knowledge

Manage tools and knowledge with the same file-first loop.

```bash
vox tool pull <tool-id-or-name> --tool <local-name> --json
vox tool validate <local-name> --json
vox tool diff <local-name> --json
vox tool push <local-name> --json

vox knowledge pull <knowledge-id-or-name> --knowledge <local-name> --allow-incomplete --json
vox knowledge validate <local-name> --json
vox knowledge status <local-name> --json
vox knowledge push <local-name> --json
```

Use `vox-tools` for custom tool design and built-in tool semantics. For knowledge, prefer CLI validation for durable files and MCP only for read-only list/lookup.

## Flow Authoring Hints

Before building or revising a flow:

```bash
vox guide flow --task "<short task description>" --json
vox agent explain /agent/flow_data --agent <local-name> --json
```

When a user can quit, opt out, ask for a human, or end the conversation at any point, prefer a global end/transfer pattern instead of repeating the same local transition on every node.

For API/tool nodes, make the external contract explicit in files: request shape, response variables, fallback branch, and secret references. Do not put raw secrets in JSON; use the CLI's secret/env reference conventions and let `vox doctor` catch unsafe literals.

## Runtime Smoke

After a validated diff or a push, use chat for a cheap live smoke when the user asks to test behavior.

```bash
vox chat --agent <local-name-or-agent-id> --input "안녕하세요" --json
```

Treat chat as runtime evidence, not as a replacement for `validate` and `diff`. Voice/listen/trigger style tests should be used only when that surface is available and the user explicitly wants live telephony behavior.

## Safety Rules

- Add `--json` for agent-driven commands whenever the command supports it.
- Do not `push`, `delete`, `promote`, or run broad imports without explicit user intent.
- Always inspect `status` and `diff` before `push`.
- Stop on `diverged`, `binding_stale`, `remote_missing`, `invalid_local`, `remote_error`, or `missing_snapshot` unless the user has chosen the resolution.
- Keep `.vox/` and local snapshots out of user-facing generated content unless the CLI docs say otherwise.
- If a command fails, read `error.code`, `message`, and `meta.command`; use the suggested command or docs hint before retrying.

## Good Agent Response Shape

When reporting back to the user, keep it operational:

```text
I pulled <resource>, changed <file>, validate passed, diff shows <summary>.
Push is not run yet / push completed in workspace <id>.
Next safe command: <command>.
```

If validation fails, report the blocking code and the file/path to edit. Avoid hand-wavy summaries when the CLI already returned a deterministic path or command.
