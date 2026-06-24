---
name: using-vox-skills
description: "Use FIRST — before any other vox skill — when a user asks anything related to vox.ai: voice agent creation, prompt writing, flow design, tool setup, pricing, MCP connection, web app usage, testing, deployment, or general platform questions. Always route through this skill instead of calling vox domain skills directly. Trigger on '프롬프트 작성해줘', '요금이 얼마예요', 'MCP 연결', 'flow 설계', '도구 추가', '웹 앱 안내', '에이전트 만들어줘', '전화 걸어줘', '음성 AI', '통화 기록', '대량발신', or any vox.ai-related request."
---

# using-vox-skills

vox.ai 관련 요청의 routing entrypoint. domain 로직을 직접 실행하지 않고, 요청에 맞는 domain skill을 선택한다.

## Skill Catalog

| Skill | Trigger | Owns | Does Not Own |
|-------|---------|------|--------------|
| `vox-onboarding` | 시작/온보딩, 에이전트 만들기, 전화 걸기/받기, MCP 연결 설정, 일반 안내 | onboarding, quickstart, 에이전트 생성 가이드, 전화 실행, MCP 서버 연결 설정 | prompt 세부 작성, flow 설계, 도구 관리 |
| `vox-agents` | prompt 작성/리팩터링/진단, agent.data, 에이전트 유형 판단 | prompt authoring, diagnosis, revision, agent.data, voice AI playbook, agent type 판단 | flow 설계, tool management, web app UI |
| `vox-flow` | flow 설계/노드 변환/리뷰, 노드별 프롬프트, condition_node 설정, 스크립트 시각화, 변수 시스템 | flow design, node conversion, node-scoped prompt, variable system, flow sketch, flow review | single-prompt authoring, tool management |
| `vox-tools` | 빌트인/커스텀 도구 관리 | built-in tools, custom tools, tool workflow | prompt authoring, flow design |
| `vox-web-app` | 웹 앱 UI 사용법, 딥링크, UI 전용 흐름(보이스 클론, CSV 업로드, 녹취 재생, 결제, 멤버 초대) | web app UI usage, navigation, deep links, UI-only flows, voice clone, CSV upload, call playback, billing, member management | prompt authoring, flow design, tool management |

## Docs MCP 활용

`vox-docs` MCP 서버(`https://fleek.mintlify.app/mcp`)는 vox.ai 공식 문서 ~85페이지를 실시간 검색한다. 스킬이 커버하지 않는 영역(요금/빌링, SDK, 보안, 배포 상세, 모니터링, API reference 등)은 docs MCP로 직접 답변한다.

**사용 방법:**
1. `vox-docs` MCP의 `search_vox_ai_docs` tool로 검색 (query 예: "pricing", "SDK javascript", "webhook", "SIP telephony")
2. 전문이 필요하면 `query_docs_filesystem_vox_ai_docs` tool로 조회 — search가 돌려준 path에 `.mdx`를 붙여 `head`/`cat` (예: `cat /start/pricing.mdx`)
3. 페이지 내용 기반으로 답변

**URL 형식 (중요):** 사용자에게 docs 페이지 링크를 전달할 때는 반드시 `/docs/` prefix를 포함한다. 형식: `https://docs.tryvox.co/docs/{path}` (예: `https://docs.tryvox.co/docs/start/pricing`, `https://docs.tryvox.co/docs/build/overview`). `/docs/` 없이 `https://docs.tryvox.co/{path}` 로 전달하면 404다.

docs MCP는 router가 직접 처리하는 검색 케이스다 — 단순 검색 후 전달이므로 domain skill 수준의 로직이 불필요하기 때문이다.

## CLI / MCP 역할 분담

코딩 에이전트(Codex/Claude Code)는 파일 편집, shell 실행, git diff/commit에 강하다. 사용자가 vox.ai agent/tool/knowledge를 레포에서 관리하거나 변경 내역을 리뷰·재현·롤백해야 하는 상황이면 MCP 직접 mutation보다 `vox` CLI의 Agent-as-Code 루프를 우선한다.

```text
조회 / 스키마 / 일회성 실행 -> MCP
레포에 남길 변경 / 리뷰 / 롤백 / CI -> vox CLI
```

CLI-first 변경 루프:

```bash
vox agent pull <agent-id>
# dashboard export JSON에서 시작하면:
# vox agent import dashboard-export.json --agent <name>
# JSON Pointer 기반으로 현재 field와 권장 helper를 확인
vox agent explain /agent/data/prompt/prompt --agent <name> --json
# stable agent.data 설정은 agent set으로, specialized 설정은 JSON 직접 편집
vox agent set --agent <name> --data prompt.prompt=@prompts/support.md
# edit agents/<name>/agent.json and related tools/** / knowledges/**
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

`agent test init/list/show/validate`는 runtime 테스트 실행이 아니라 local test spec authoring/review이다. 테스트 의도와 acceptance assertion이 레포에 남아야 할 때 사용하고, `list/show --json`으로 코딩 에이전트가 경로/turn/assertion 수/validation 상태를 확인하게 한다. 실제 chat/voice 실행은 future `vox test` 또는 제품 API surface가 준비된 뒤로 둔다.

Resource 변경은 같은 원칙을 따른다.

```bash
vox tool pull <tool-id> --tool <local-name>
vox tool validate <local-name>
vox tool diff <local-name>
vox tool push <local-name>

vox knowledge pull <knowledge-id> --knowledge <local-name> --allow-incomplete
vox knowledge validate <local-name>
vox knowledge status <local-name>
vox knowledge push <local-name>
```

`vox doctor` / `vox agent doctor` / `agent push` / `tool push`가 raw secret, placeholder/TODO authoring field, 비어 있는 tool/knowledge ref, 그리고 `fire_and_forget` custom tool의 결과 기반 flow transition을 막으면 그 출력을 수정 지시로 사용한다. `fire_and_forget` 도구 결과로 분기해야 하는 flow는 도구를 `wait`로 바꾸고, 결과를 쓰지 않는 발송/호출 전용 flow만 `fire_and_forget`을 유지한다.

MCP direct `create_agent` / `update_agent` / `create_tool` / `update_tool`은 빠른 one-off, 온보딩, 탐색, 또는 사용자가 명시적으로 원격 즉시 반영을 원할 때 사용한다. 사용자가 "레포", "코드처럼", "diff 보여줘", "PR/리뷰", "롤백 가능하게", "커밋", "CI"를 언급하면 CLI 루프로 라우팅한다.

## 스킬 없이 router가 직접 다루는 MCP 도구

전용 domain skill이 없지만 단일 MCP 호출로 끝나는 두 경우는 router가 직접 처리한다.

- **조직 전환** — 멀티 조직 계정에서 활성 조직을 바꿔야 하면 `list_organizations`로 소속 조직을 확인하고 `set_organization(organization_id)`로 세션 활성 조직을 전환한다. 다른 작업을 "다른 조직에서" 진행하라는 요청이면 먼저 전환한 뒤 해당 domain skill로 라우팅한다. `list_organizations` row의 `is_main`/`parent_organization_id`를 확인해 상위/하위 워크스페이스를 구분한다.
- **하위 워크스페이스 안전 가드** — `is_main=false`인 하위 워크스페이스는 상위 워크스페이스의 결제/구독을 상속한다. 결제 수단·플랜·청구 내역 안내는 상위 워크스페이스 기준으로 설명하고 `vox-web-app`의 settings reference를 확인한다. 반면 멤버, API 키, 웹훅, 에이전트/번호/도구 같은 운영 리소스는 선택된 워크스페이스 단위로 다룬다.
- **지식 베이스 조회** — `list_knowledges`로 조직의 지식 베이스 목록을 조회한다. 조회 전용이다. 지식 베이스를 레포에서 관리해야 하면 `vox knowledge ...` CLI 루프로 이동하고, 웹 UI 조작 안내가 필요하면 `vox-web-app`을 참조한다.

## Routing Rules

1. **1% rule** — 요청이 1%라도 특정 domain skill에 해당되면 해당 skill을 invoke한다. domain skill 내부에 사실 검증과 가드레일이 있어, router가 직접 답하면 이를 우회하게 된다.
2. **One primary skill** — 한 요청에는 하나의 primary skill만 선택한다. 두 스킬을 동시에 invoke하면 operating rule이 충돌하고 output 형식이 섞인다.
3. **UI 보충 참조** — 다른 스킬 실행 중 웹 앱 UI 경로 안내가 필요하면 `vox-web-app`을 secondary로 참조한다. UI 경로와 딥링크는 자주 변경되므로 web-app의 references가 정확한 경로를 가지고 있다.

## Routing Disambiguation

경계가 모호한 케이스의 판단 기준:

| 요청 패턴 | 라우팅 | 이유 |
|-----------|--------|------|
| 프롬프트 안에서 도구 호출 방법 언급 | `vox-agents` | 프롬프트 컨텍스트 안의 도구 언급은 prompt authoring |
| 도구 자체의 생성/삭제/파라미터 변경 | `vox-tools` | 도구 CRUD는 tools 영역 |
| 대시보드에서 TTS/속도/설정 변경 | `vox-web-app` | UI 조작 가이드는 웹 앱 영역 |
| "에이전트 만들어줘" (첫 사용자/MCP 미연결) | `vox-onboarding` | 온보딩 플로우에 에이전트 생성 포함 |
| "에이전트 만들어줘" (기존 사용자) | `vox-agents` | 온보딩 이후의 에이전트 생성은 authoring |
| "flow 설계해줘", "스크립트를 노드로 변환" | `vox-flow` | flow 전용 설계 작업 |
| "node prompt 작성", "노드별 프롬프트", "condition_node 수정" | `vox-flow` | flow node 의 `data.prompt` / transition / fallback 보존은 flow 영역 |
| "flow vs single prompt 뭐가 나아?" | `vox-agents` | 유형 판단은 agents가 소유, flow 결정 시 handoff |
| 요금/빌링/플랜/크레딧 질문 | docs MCP | 실시간 pricing 페이지 검색 |
| SDK 사용법, API reference | docs MCP | 문서 검색으로 충분 |
| "캠페인 만들어줘", "대량발신 설정" | `vox-web-app` | 대량발신/캠페인 관리는 웹 앱 영역 |
| "번호 구매 페이지 알려줘", "녹취 어디서 들어?" | `vox-web-app` | 페이지 경로/딥링크 안내 |
| "조직 전환", "다른 organization 으로 작업", "멀티 조직 계정", "하위 워크스페이스" | router 직접 (org 도구) | 세션 활성 조직 전환은 domain 로직이 아닌 단일 MCP 호출. `is_main`/`parent_organization_id`로 main/sub 맥락을 확인 |
| "지식 베이스 뭐 있어?", "knowledge base 목록" | router 직접 (`list_knowledges`) | 조회만이면 MCP가 적합 |
| "레포에 agent 변경 남겨줘", "diff 보고 push", "코드처럼 관리" | 해당 domain skill + vox CLI | durable authoring은 CLI가 소유 |
| 어떤 스킬에도 매핑 안 되는 vox.ai 질문 | docs MCP → `vox-onboarding` | docs 검색 먼저, 없으면 onboarding이 가장 넓은 안내 범위 |

## 복합 요청

"프롬프트 작성 + 도구 연결"처럼 여러 영역에 걸친 요청은:
1. 핵심 작업을 primary skill로 선택 (요청의 주된 의도)
2. primary 완료 후 "도구 연결도 진행할까요?"로 secondary handoff
3. 동시 invoke하지 않는다 — 한 스킬의 output이 다음 스킬의 input이 되는 경우가 많다

## 이 스킬이 하지 않는 것

domain skill의 내용을 복제하거나 요약하지 않는다 — router가 domain 내용을 요약하면 domain skill 업데이트 시 불일치가 발생한다. 각 domain skill이 소유하는 영역은 위 Skill Catalog 참조.
