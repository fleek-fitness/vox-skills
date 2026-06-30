# Changelog

이 파일은 `domains/voxai/skills`의 maintainer-facing 변경 이력을 남긴다.

## Changelog Philosophy

- high-signal만 남긴다.
- skill catalog 변경, routing 규칙, MCP 연결 설정, plugin install 절차, 공개 문구(README/references) 변화 위주로 기록한다.
- 단순 formatting, noisy refactor, generated diff는 원칙적으로 적지 않는다.
- reader는 미래의 maintainer라고 가정한다.

## Format

- reverse chronological order를 유지한다.
- 먼저 `Unreleased`를 두고, release 시 날짜/버전 section으로 잘라낸다.
- category는 아래만 쓴다:
  - `Added`
  - `Changed`
  - `Fixed`
  - `Removed`
  - `Docs`

## Entry Rules

- 한 줄 요약이 아니라, 무엇이 바뀌었고 왜 중요한지 짧게 적는다.
- skill trigger/routing/ownership boundary가 바뀌면 반드시 남긴다.
- plugin install 절차, MCP 서버 URL, `.mcp.json` 스키마가 바뀌면 반드시 남긴다.
- README/references 같은 공개 문서 contract가 바뀌면 `Docs`에 남긴다.

## Template

```md
## Unreleased

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Removed
- ...

### Docs
- ...
```

## Unreleased

### Added
- bundle drift / version-lockstep CI를 추가했다 (`scripts/check-bundle-sync.sh` + `.github/workflows/bundle-sync.yml`). Codex 번들(`plugins/vox-ai/`)이 루트 `skills/`·`.mcp.json`과 어긋나거나 두 매니페스트(`marketplace.json`·`plugin.json`) 버전이 불일치하면 CI가 실패한다. sync용 symlink 제거(47da8b6) 이후 수동 동기화에만 의존하던 drift를 자동 차단한다.
- skill↔MCP 도구 conformance CI를 추가했다 (`scripts/check-skill-mcp-conformance.sh` + `scripts/vox-mcp-public-tools.json` 매니페스트, `.github/workflows/bundle-sync.yml`에 step 추가). 스킬이 공개 surface(`PUBLIC_TOOL_NAMES`)에 없는 vox 도구명을 호출하도록 안내하면 CI가 실패하고, 어떤 스킬도 참조하지 않는 공개 도구는 경고한다. `create_custom_tool` 같은 phantom 도구명 회귀를 자동 차단한다(이번 라운드에 실제로 잔존 phantom을 잡아냄).

### Changed
- `vox-flow` eval lesson 을 반영해 flow authoring guidance 를 보강했다. flow-only 작업에서는 agent `data` 를 생략하고, `begin` outgoing edge 에 `skip_user_response` 를 붙이지 않으며, extraction/static one-shot 정상 진행을 fallback 으로 표현하지 않도록 했다. 또한 "요약 확인" 요구는 endCall summary 가 아니라 확인/수정 conversation turn 으로 설계하도록 `flow-guide`, node markdown references, review checklist 를 정리했다.
- `vox-flow` public `flow` guidance 를 최신 schema surface 와 맞췄다. node `data` 예시와 작성 규칙을 snake_case(`prompt_type`, `api_configuration`, `tool_id` 등) 기준으로 정리하고, `schema 조회 → fill → validate → save` 작성 루프, deprecated node read/write 경계, note/condition/begin/endCall edge 제한, global node 허용 타입, transferAgent/transferCall/tool 식별자 규칙을 dry-run 전에 잡을 수 있도록 references와 checklist에 반영했다.
- `vox-flow`를 public `flow` authoring path 기준으로 갱신했다. 새 작성/수정은 `get_schema(flow-schema/flow-data)` → `validate_flow(flow, level="all")` → `create_agent/update_agent(flow=...)` 로 안내하고, `flow_data` / `validate_flow_data` / `autofix_flow_data` / `update_agent_partial` 는 legacy `flow_data` graph 전용으로 경계를 명확히 했다. 관련 references와 기본 fixture에서 `sourceHandle` / `transitions[]` 중심 예시를 제거하고 edge `condition` 중심 예시로 바꿨다.
- `vox-flow` 에 `validate_flow_data` dry-run 워크플로우를 통합했다. SKILL.md Workflow 를 4단계로 확장(4단계: dry-run 검증)하고 Core Operating Rules #9(전송 전 dry-run)·#10(nested config default 는 백엔드가 채움)을 추가했으며, Response Handling 섹션을 신설해 응답별 처리 룰과 룰 ID 빠른 참조를 정리했다. references 도 정합화 — `flow-review.md` 섹션 F(dry-run + 식별자 필수), `execution-node-markdown.md` / `node-types.md` / `node-creation.md` 의 dry-run 단계 통합. 사용자 입장에서 (1) 차단 오류가 400/422 로 노출되는 일을 줄이고, (2) 자동 보정 사실이 빠짐없이 전달되도록 한다.
- `vox-flow` references에 api 노드 실패 분기 설계 규칙을 추가했다. api 호출 실패 fallback edge가 곧바로 endCall로 흘러가면 사용자가 통화가 갑자기 끊긴 인상을 받기 때문에, 짧은 양해 안내 conversation 노드로 흡수한 뒤 마무리하도록 가이드한다. `execution-node-markdown.md`에 anti-pattern / 권장 JSON 예시를 두고, `node-examples.md`에 짝꿍 노드(API 실패 안내 conversation) 예시를 추가했으며, `flow-review.md`에는 통화 흐름 안전성 섹션 E를 신설해 E1 CRITICAL(api 실패 분기 + 안내 노드 흡수)와 E2 WARN(tool/sendSms 실패 흡수)을 두었다.
- `vox-flow`를 schema endpoint 우선 운영 방식으로 정리했다. 노드별 JSON field 목록을 로컬 reference에 고정하지 않고, `get_schema(namespace="flow-schema", schema_type="flow-data")`와 agent data schema를 호출한 뒤 `create_agent(type="flow", data=..., flow_data=...)` / `update_agent(flow_data=...)`를 수행하도록 안내한다.
- `vox-flow` node markdown 작성 가이드를 경량 라우터(`node-creation.md`)와 세부 reference(`conversation-markdown.md`, `execution-node-markdown.md`, `node-examples.md`)로 분리했다. 대시보드 입력용 markdown과 MCP/API JSON을 명확히 구분해 오래된 graph shape가 섞이는 문제를 줄인다.
- Codex plugin 설치 경로를 2026-04 신규 `codex plugin marketplace add vox-public/vox-skills` 단일 명령으로 전환했다. `README.md`, `vox-onboarding/references/quickstart-ko.md`, `vox-onboarding/references/mcp-vox-integration.md`의 기존 `git clone → cd → codex → /plugins` 흐름을 모두 대체하고 App(**Plugins → Add to Codex**)과 CLI(`/plugins → Install plugin`) 설치를 병기했다. docs `docs/ai/openai-codex` 개편과 정합한다.
- `vox-onboarding` Step 4(인바운드)를 in-tool로 정합화했다(이전 Unreleased의 "웹 앱 안내" 결정을 대체). 번호-에이전트 연결은 공개 도구 `update_telephone_number_agent`로 수행한다 — 번호 보유 시 `list_telephone_numbers` 행 id를 `organization_telephone_number_id`로 써서 `inbound_agent={agent_id, agent_version}`(current/production/v{n})로 매핑하고, 웹 앱은 번호가 없을 때 구매 용도로만 안내한다. `update_telephone_number`(전체 번호 관리)는 여전히 비공개지만 agent-mapping subset인 `update_telephone_number_agent`는 public이라는 점을 반영.
- `vox-onboarding` Related Resources의 MCP Tools 목록을 실제 public(`list_telephone_numbers`만 read-only)으로 정리하고 `list_organizations`를 명시했다.
- vox MCP의 **OAuth-only** contract를 온보딩 문서에도 반영했다. `SKILL.md` Step 1, `quickstart-ko.md`, `references/mcp-vox-integration.md`에서 `Authorization: Bearer ${VOX_API_KEY}` / `bearer_token_env_var` 등 **제거된 API token 방식** 안내를 모두 걷어내고 클라이언트별 OAuth 경로만 남겼다. 서버가 받지 않는 방식을 가이드해 유저를 막다른 길로 보내는 문제를 제거한다.
- `vox-flow` 스키마 디스커버리를 per-node-schema-discovery(vox-mcp PR#28) 기준으로 정리했다. 기본 fetch를 `get_schema("flow-schema","flow-data", detail="minimal")` 단일 호출(노드 $defs 포함)로 고정하고, `detail="minimal"`을 명시하지 않으면 더 큰 standard payload가 온다는 함정을 문서화했다. api/transferCall/transferAgent/sendSms/tool 노드만 `detail="standard"`로 escalate. `autofix_flow_data`(deterministic 보정 preview/apply)와 `update_agent_partial`(그래프 부분 수정 ops, dry-run)을 워크플로에 추가하고 full-replace(`update_agent`)와의 사용 기준을 정리했다.
- `using-vox-skills` 라우터에 `set_organization`(조직 전환)·`list_knowledges`(지식 베이스 조회, read-only) 라우팅을 추가했다 — 어떤 스킬도 참조하지 않던 공개 도구를 surface(생성/연결 도구는 비공개이므로 발명하지 않음).

### Fixed
- plugin feedback 회귀 방지 규칙을 추가했다. `vox-agents` / `vox-flow` 가 agent data 를 만들 때 한국어 STT 는 `["ko"]`, voice locale 은 `ko-KR` 로 분리하고 `speech.responsiveness` 는 명시 요청 없이 `1.0` 에서 낮추지 않도록 했다. 또한 node prompt 요청이 single prompt 전체 템플릿으로 새지 않도록 `using-vox-skills` 라우팅과 flow conversation node 지침을 강화했고, 기존 condition node fallback(`Else` 등)의 label/id/sourceHandle 을 임의 변경하지 않도록 flow guide/review 체크를 추가했다.
- Codex plugin package를 설치 cache 안에서 self-contained 하도록 고쳤다. Codex installer가 `plugins/vox-ai/.mcp.json` / `plugins/vox-ai/skills` symlink를 cache에 복사하지 않아 `vox` / `vox-docs` MCP 서버가 노출되지 않던 문제를 해결하고, 기존 `1.0.0` cache 재사용을 피하도록 plugin version을 `1.0.1`로 올렸다.
- `vox-agents`의 agent data / variable reference를 현재 MCP surface와 맞췄다. top-level `prompt`나 `agent_type` shortcut을 가정하지 않고, agent `data` schema와 flow 변수 전달 규칙을 기준으로 설명한다.
- `vox-agents` references의 변수 미주입 동작 기술을 실제 정책과 정합화했다. `voice-ai-playbook.md`(워크플로우/Variables 샘플/fallback 규칙), `voice-ai-prompt-template.md`(메타 가이드 + 템플릿 본문), `voice-ai-prompt-revision.md`(Pattern D), `voice-ai-prompt-diagnosis.md`(증상 6)에서 "비어있을 수 있음" 같은 표현을 "주입되지 않으면 `{{...}}`가 그대로 전달됨"으로 바꿨다. 이 문구들이 생성된 system prompt에 그대로 복사되어 런타임 LLM이 미주입 방어 로직을 엉뚱한 케이스(빈 값)에만 적용하던 문제를 제거한다. Mission 1 dry run 준비 중 사용자 제보로 발견.
- vox-docs MCP tool 이름을 실제 surface와 맞췄다. `using-vox-skills` SKILL.md(+Codex 번들 복사본)·`README.md`·`AGENTS.md`에서 `search`→`search_vox_ai_docs`, `get_page`→`query_docs_filesystem_vox_ai_docs`로 바꾸고, 2단계 안내도 실제 동작(`.mdx` 경로를 `head`/`cat`)에 맞게 다시 썼다. router가 존재하지 않는 tool 이름을 호출하도록 안내하던 문제를 제거한다.
- `.claude-plugin/marketplace.json` 버전을 `1.0.0`→`1.0.1`로 올려 Codex `plugin.json`(1.0.1)과 일치시켰다. Claude/Codex 두 ecosystem이 같은 plugin에 다른 버전을 표기해 업데이트/지원 시 혼선을 주던 문제를 없앤다.
- `AGENTS.md`의 vox MCP URL을 루트(`https://mcp.tryvox.co/`)에서 canonical `https://mcp.tryvox.co/mcp`로 보정했다(`.mcp.json`·README와 정합, CHANGELOG가 404로 지적했던 형태).
- `vox-onboarding` Step 2의 `create_agent` 인자를 실제 MCP 도구 시그니처와 맞췄다. vox-mcp `tools/agents.py`의 `create_agent`는 `name`/`type`/`data`/`flow_data`만 받고 `agent_type`·top-level `prompt`는 없으므로, 없는 인자를 지시하던 것을 `type`+`data.prompt`(+`get_schema(agent-schema, agent-data-create)` 확인)로 바꿨다. 이미 정합화된 `vox-agents`와 일치한다.
- `vox-tools`가 존재하지 않는 도구(`list_custom_tools`/`create_custom_tool`/`delete_custom_tool`/`list_built_in_tools`)를 호출하도록 안내하던 것을 실제 surface로 전면 교체했다. 커스텀(HTTP/API) 도구는 `list_tools`/`create_tool`/`get_tool`/`update_tool`/`delete_tool`로 관리하고, 빌트인 도구는 전용 엔드포인트 없이 `data.builtInTools[]`/`data.toolIds[]`에 담아 `create_agent`/`update_agent`로 장착/해제하며 payload 스키마는 `get_schema(namespace="tool-schema", category="built_in")`로 조회한다. 커스텀 도구는 HTTP/API 전용(MCP 타입 생성 없음)이라 frontmatter 설명의 "or MCP tools"도 정정. (`get_tool`/`update_tool`/`delete_tool`은 vox-mcp 측에서 새로 public 노출 — 별도 PR.)
- `vox-agents`의 하드코딩된 agent 기본값(llm.model `z-ai/glm-4.7`, voice `cartesia`/`sonic-3.5`/voice UUID, voice.speed/temperature 등)을 제거했다. api-server가 default의 SSOT이고 생략한 sub-schema를 서버가 채우므로, 스킬은 `data.llm`/`data.voice`를 OMIT하고 명시 override 시에만 `list_llm_models`/`list_voice_models`로 허용값을, `get_schema(... detail="minimal")`로 shape를 조회하도록 바꿨다. `default-agent-data.json`은 "복사용 기본값"이 아니라 illustrative shape로 재작성(상단 `_note`/`_defaults`/`_allowed_values`). `vox-flow`의 default-agent-data.json 참조 표현도 동일 방향으로 정합화.
- `quickstart-ko.md`의 공개 도구 표를 실제 24개 surface로 교정했다(phantom tool 제거 + `list_tools`/`create_tool`/`get_tool`/`update_tool`/`delete_tool`·`list_llm_models`/`list_voice_models`·`update_agent_partial`·`autofix_flow_data`·`list_knowledges` 반영). conformance CI가 잔존 phantom을 잡아 발견.

### Docs
- `README.md`의 Claude Code Plugin 섹션에 `/reload-plugins` 단계와 "첫 도구 호출 시 OAuth 로그인" 시점을 명시했다. 설치 직후 도구가 보이지 않는 상황을 줄이기 위함이다.
- `vox-web-app/references/deep-links.md`의 `list_organizations` 예시 조직 UUID를 실재 식별자에서 명백한 placeholder(`00000000-0000-0000-0000-000000000000`)로 교체했다(공개 repo 노출 제거, Codex 번들 복사본 포함).
- `references/mcp-vox-integration.md`, `references/quickstart-ko.md`, `README.md`의 MCP 서버 URL을 canonical `/mcp` 경로로 통일했다. `https://mcp.tryvox.co/`(root)는 404이고 실제 endpoint는 `/mcp`다.
- `references/quickstart-ko.md`를 "Plugin 없이 MCP 수동 연결"에 집중하도록 재정리하고, 공개 MCP 도구 목록을 Phase 1 public surface(`PUBLIC_TOOL_NAMES`)와 정합화했다. campaign/telephone 번호 CRUD/eval 도구가 공개되어 있다는 오해를 제거했다.
