# vox.ai Skills

vox.ai 개발자를 위한 Codex/Claude plugin + Agent Skills 레포입니다.

## 설치

### OpenAI Codex Plugin (권장)

터미널에서 한 줄로 vox.ai 마켓플레이스를 등록합니다 (2026-04+ Codex).

```bash
codex plugin marketplace add vox-public/vox-skills
```

그 뒤 plugin 목록에서 `vox-ai`를 설치합니다.

- **Codex App**: **Plugins** 화면에서 `vox-ai` → **Add to Codex**
- **Codex CLI**: `codex` 실행 후 `/plugins` → `vox-ai` → **Install plugin**

설치 중 브라우저에서 vox.ai OAuth 로그인 창이 열립니다. 설치 후에는 Codex를 재시작해야 skill과 MCP 서버가 현재 세션에 로드됩니다.

### Claude Code Plugin

Claude Code 세션 안에서 slash command로 진행합니다.

```
# 1. marketplace 등록
/plugin marketplace add vox-public/vox-skills

# 2. plugin 설치
/plugin install vox-ai@vox-ai

# 3. 현재 세션에 로드
/reload-plugins
```

한 번의 설치로 MCP 서버 + Skills가 모두 제공됩니다. 처음 vox MCP 도구를 호출할 때 브라우저에서 vox.ai OAuth 로그인 창이 열립니다.

### MCP 직접 등록 (대안)

```bash
# Codex MCP
codex mcp add vox --url https://mcp.tryvox.co/mcp
codex mcp login vox

# Claude Code MCP
claude mcp add --transport http vox https://mcp.tryvox.co/mcp

# Skills
npx skills add https://github.com/vox-public/vox-skills --skill using-vox-skills
```

설치 전에 레포에 포함된 스킬 목록을 확인하려면:

```bash
npx skills add https://github.com/vox-public/vox-skills --list
```

## Available Skills

### using-vox-skills (router)

vox.ai 관련 요청의 routing entrypoint. 요청 내용에 따라 아래 domain skill을 자동 선택합니다.

- `skills/using-vox-skills/SKILL.md`

### vox-onboarding

첫 사용자 온보딩. 에이전트 생성 → 아웃바운드 테스트 → 인바운드 설정까지 안내합니다.

- MCP 서버 연결 설정 (Claude/Cursor/ChatGPT/VS Code/Codex/OpenCode)
- `skills/vox-onboarding/SKILL.md`

### vox-agents

프롬프트 에이전트(single prompt) 설계와 공통 음성 UX 규칙을 담당합니다.

- 신규 프롬프트 작성 워크플로우 + 한국어 템플릿
- 실패 사례 원인 진단 → 리팩터링
- agent.data 스키마 (MCP create_agent/update_agent)
- Agent Type 판단 (prompt vs flow) + flow handoff
- `skills/vox-agents/SKILL.md`

### vox-flow

플로우 에이전트 설계를 담당합니다. vox-agents의 확장 스킬입니다.

- 10종 node type 설계/설정
- 스크립트 → Mermaid flowchart → flow node 변환
- 변수 시스템 (extraction → condition 체인)
- 설계물 체크리스트 기반 리뷰
- `skills/vox-flow/SKILL.md`

### vox-tools

vox.ai 에이전트의 빌트인/커스텀 도구 관리를 담당합니다.

- 빌트인 도구: end_call, transfer_call, transfer_agent, send_sms, send_dtmf
- 커스텀 도구 (API/MCP type) 생성/연결/해제
- `skills/vox-tools/SKILL.md`

### vox-web-app

vox.ai 웹 앱(`tryvox.co/dashboard`) 사용 가이드. 다른 스킬에서 UI 안내가 필요할 때도 참조됩니다.

- 구축(build): agents, voice, tools, knowledge
- 배포(deploy): numbers, single/batch outbound
- 모니터링(monitor): analytics, history, alerts
- 설정(settings): workspace, billing, member, api-key, webhook, sms, profile
- 딥링크 치트시트 (`?new=1`, `?clone=true`, `?create=api` 등)
- Chrome MCP extension으로 화면 보며 안내 지원
- `skills/vox-web-app/SKILL.md`

## MCP Servers

이 플러그인은 두 개의 MCP 서버를 연결합니다:

| Name | URL | 역할 |
|------|-----|------|
| `vox` | `https://mcp.tryvox.co/mcp` | 플랫폼 도구 (에이전트, 통화, 조직 등) |
| `vox-docs` | `https://fleek.mintlify.app/mcp` | 공식 문서 검색 (search_vox_ai_docs + query_docs_filesystem) |

## vox CLI와 함께 쓰는 방식

Codex/Claude Code 같은 코딩 에이전트는 파일 편집, shell 실행, git diff/commit에 강합니다. 따라서 vox.ai 리소스를 레포에서 관리해야 하는 작업은 MCP 직접 update보다 `vox` CLI를 우선합니다.

```text
docs MCP: 공식 문서 검색
vox MCP: 조직/스키마/리소스 조회와 one-off 실행
vox skills: 설계 판단과 workflow routing
vox CLI: agent/tool/knowledge를 파일로 편집하고 doctor/validate/diff/push하는 durable authoring
```

경계 규칙:

```text
조회거나 일회성이면 MCP.
레포에 남아야 하거나 리뷰/롤백/CI가 필요하면 vox CLI.
```

대표 루프:

```bash
vox agent pull <agent-id>
# dashboard export JSON에서 시작하면:
# vox agent import dashboard-export.json --agent <name>
# JSON Pointer 기반으로 현재 field와 권장 helper를 확인
vox agent explain /agent/data/prompt/prompt --agent <name> --json
# stable agent.data 설정은 agent set으로, specialized 설정은 JSON 직접 편집
vox agent set --agent <name> --data prompt.prompt=@prompts/support.md
# edit agents/<name>/agent.json, tools/**, knowledges/**
vox agent test init greeting_smoke --agent <name> --input "안녕하세요" --response-contains "안내"
vox agent test list --agent <name> --json
vox agent test show greeting_smoke --agent <name> --json
vox agent test validate greeting_smoke --agent <name> --json
vox doctor --json
vox agent doctor --agent <name> --json
vox agent validate --agent <name> --json
vox agent diff --agent <name> --json
vox agent push --agent <name>
# 프로덕션 승격까지 요청받은 경우에만:
vox agent version save --agent <name> --description "reviewed release"
vox agent promote v1 --agent <name> --yes
```

`agent test init/list/show/validate`는 chat/voice runtime을 실행하지 않습니다. 레포에 남길 테스트 의도와 acceptance assertion을 `agents/<name>/tests/*.json`으로 먼저 고정하고, PR 리뷰와 코딩 에이전트 탐색에서 같은 파일을 보게 하는 용도입니다.
