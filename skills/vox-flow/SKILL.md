---
name: vox-flow
description: "Use when the user is designing a vox.ai flow agent — selecting node types, planning branching logic, wiring transitions, extracting variables between nodes, configuring global nodes, converting a call-center script into flow nodes, visualizing scripts as Mermaid flowcharts, or reviewing flow designs. Flow agents are the multi-node extension of prompt agents for complex scenarios. Trigger on 'flow 설계', '스크립트를 노드로 변환해줘', 'flow vs single prompt', '플로우차트 그려줘', '노드 설계', 'flow 리뷰해줘', 'condition node 설정', '플로우 검증', '노드 연결 어떻게 해', or any vox.ai flow agent question."
---

# vox-flow

vox.ai **플로우 에이전트**를 설계하는 domain skill. 여러 node를 연결해 대화 흐름을 제어한다.

Flow는 prompt agent의 확장이므로, **공통 음성 UX 규칙은 `vox-agents`의 playbook을 따른다.** 새 flow 설계 시 `vox-agents/references/voice-ai-playbook.md`를 먼저 읽어야 한다.

## Flow vs Single Prompt 판단 기준

→ `vox-agents`의 Agent Type 판단 기준 테이블 참조. Single prompt로 충분한 경우 `vox-agents` 스킬로 handoff한다.

## References

- **default-flow-data.json** — flow 기본 스키마 (begin→conversation→endCall). **flow 구조를 이해할 때 읽기.** See [references/default-flow-data.json](references/default-flow-data.json)
- **flow-guide.md** — flow 설계 통합 가이드 (edge 메커니즘, 변수 흐름, 설계 원칙). **flow를 처음 설계할 때 읽기.** See [references/flow-guide.md](references/flow-guide.md)
- **flow-sketch.md** — 스크립트 → Mermaid flowchart 시각화. **1단계: 스크립트를 처음 받았을 때 읽기.** See [references/flow-sketch.md](references/flow-sketch.md)
- **node-creation.md** — flowchart/스크립트 → 노드 markdown 변환 workflow. **2단계 시작 시 먼저 읽기.** See [references/node-creation.md](references/node-creation.md)
- **conversation-markdown.md** — conversation 노드 static/generated 작성법. **대화 노드 문구와 exit 조건을 쓸 때 읽기.** See [references/conversation-markdown.md](references/conversation-markdown.md)
- **execution-node-markdown.md** — extraction/condition/api/transfer/sendSms/tool/endCall 작성법. **대화 외 노드를 쓸 때 읽기.** See [references/execution-node-markdown.md](references/execution-node-markdown.md)
- **node-examples.md** — 긴 예시 모음. **출력 톤이나 구조 예시가 필요할 때만 읽기.** See [references/node-examples.md](references/node-examples.md)
- **node-types.md** — 노드 타입 선택 기준 + schema endpoint 사용 규칙. **특정 노드의 JSON 설정 옵션이 필요하면 먼저 schema endpoint 를 호출하기.** See [references/node-types.md](references/node-types.md)
- **flow-review.md** — 설계물 체크리스트 기반 검증. **3단계: 설계 완료 후 또는 "리뷰해줘" 요청 시 읽기.** See [references/flow-review.md](references/flow-review.md)

공통 reference (`vox-agents`에 위치):
- **variable-system.md** — 변수 naming, 추출 설정, 렌더링 위치. **extraction/condition 변수 흐름을 설계할 때 읽기.**
- **voice-ai-playbook.md** — 음성 UX 핵심 규칙. **새 flow 설계 시 가장 먼저 읽기.**
- **default-agent-data.json** + **agent-data-reference.md** — agent.data 기본값 + MCP 동작 규칙. **MCP로 에이전트를 생성할 때 읽기.**
- **ivr-navigation-best-practice.md** — IVR/DTMF 패턴. **ARS/IVR 통과 시나리오에서 읽기.**
- **voice-ai-prompt-template.md** — 프롬프트 템플릿. **generated conversation 노드의 `data.prompt` 를 채울 때 checklist 로 참고하되, 전체 prompt 를 복사하지 않는다.**
- **voice-ai-prompt-diagnosis.md** — 실패 사례 진단. **flow 에이전트가 이상하게 동작할 때 읽기.**
- **voice-ai-prompt-revision.md** — 진단 기반 리팩터링. **diagnosis 후 노드 프롬프트를 수정할 때 읽기.**

## Workflow

스크립트 → flow 변환 시 4단계로 진행:

1. **시각화 (flow-sketch)**: 스크립트 → Mermaid flowchart + 노드 요약 테이블
2. **상세 설계 (node creation)**: 확정된 차트의 각 노드 → flow node markdown. `node-creation.md`를 시작점으로 읽고 필요한 노드 계열 reference만 추가로 읽는다.
3. **리뷰 (flow review)**: 체크리스트 기반 검증, CRITICAL/WARN/INFO 분류
4. **dry-run 검증 (validate_flow_data)**: JSON 작성 직전에 [Schema Fetching](#schema-fetching) 으로 schema 를 가져와 JSON 을 만들고, MCP `validate_flow_data` 를 호출해 결과를 사용자에게 한두 줄로 요약한다. errors / warnings 처리는 [Response Handling](#response-handling) 을 따른다. errors 가 비었을 때에만 `create_agent` / `update_agent` 호출.

사용자가 시각화만 요청하면 1단계만. "노드로 변환해줘"면 1→2단계. "리뷰해줘"면 3단계. JSON 으로 보내려면 4단계까지.

## Schema Fetching

`flow_data` JSON 을 작성하기 직전에 schema 를 가져온다. **default 는 단일 호출이다.**

### Default — `flow-data` minimal 한 번

```text
get_schema(namespace="flow-schema", schema_type="flow-data", detail="minimal")
```

이 한 응답에 envelope (`nodes[]`, `edges[]`, `viewport`) 와 모든 node type 의 `data` shape (`BeginData`, `ConversationData`, `ApiData`, `ConditionData`, `ExtractionData`, `SendSmsData`, `ToolData`, `TransferCallData`, `TransferAgentData`, `EndCallData`, `NoteData`, `FunctionData`) 가 `$defs` 로 함께 포함되어 온다. `detail="minimal"` 은 description / title / examples 를 재귀적으로 strip 해 응답을 약 41% (≈ 12,660 → 7,460 tokens) 줄인다.

flow 에 `api` / `transferCall` / `transferAgent` / `sendSms` / `tool` 노드 중 **하나라도** 있으면, 다음 [standard 모드로 보강이 필요한 노드 type](#standard-모드로-보강이-필요한-노드-type) 단계를 추가로 거친다. `begin` / `conversation` / `condition` / `extraction` / `endCall` / `note` 만 사용하는 flow 라면 이 minimal 한 번으로 충분하다.

agent `data` 도 같이 보낼 경우 별도로 한 번 더 호출한다.

```text
get_schema(namespace="agent-schema", schema_type="agent-data-create", detail="minimal")
get_schema(namespace="agent-schema", schema_type="agent-data-update", detail="minimal")
```

### standard 모드로 보강이 필요한 노드 type

다음 node type 중 **하나라도 flow 에 등장하면** 그 type 에 한해 standard 모드로 한 번 더 fetch 해서 description 을 본다 (minimal 만으로는 의미 단서가 부족함):

```text
get_schema(namespace="flow-schema", schema_type="node-api", detail="standard")
get_schema(namespace="flow-schema", schema_type="node-transferCall", detail="standard")
get_schema(namespace="flow-schema", schema_type="node-transferAgent", detail="standard")
get_schema(namespace="flow-schema", schema_type="node-sendSms", detail="standard")
get_schema(namespace="flow-schema", schema_type="node-tool", detail="standard")
```

각 node 가 standard 보강을 필요로 하는 이유 (minimal 에서 잃는 정보):

- **`node-api`** — `apiConfiguration.body` 가 JSON 문자열인지 object 인지, `responseVariables.jsonPath` 의 JSONPath 문법 예시, `authType` × `authCredentials` 조합 의미
- **`node-transferCall`** — `transferConfiguration.transferTo` 가 phone number vs SIP URI 어느 쪽인지, `transferType` (cold/warm) 의 동작 차이, `sipHeaders` 사용법, `displayedCallerId` (agent/user) 의미
- **`node-transferAgent`** — `agent.agent_id` 가 같은 조직 agent UUID 라는 운영 제약, `preserveChatContext` 의 의미
- **`node-sendSms`** — `staticImageFileKeys` 가 어떤 S3 key 형식인지, `smsFromNumber` 가 등록된 발신번호여야 한다는 제약
- **`node-tool`** — `toolId` (custom tool UUID) 와 `agentToolId` (built-in tool 인덱스) 의 차이

위 type 이 flow 에 없다면 (`begin` / `conversation` / `condition` / `extraction` / `endCall` / `note` 만 사용), minimal flow-data 한 번이면 충분하다.

### 그 외 narrow case fallback

다음 좁은 경우에도 per-node 호출이 도움이 된다.

- flow 가 매우 큼 (15+ 노드, 다양한 type) + LLM context budget 이 빡빡해서 minimal envelope 도 부담스러울 때 → 사용한 type 별 minimal per-node 호출로 분할
- 같은 flow 를 반복 patch 하면서 envelope 은 캐시하고 한 노드 type 의 detail 만 다시 standard 모드로 보고 싶을 때
- `validate_flow_data` 가 같은 node type 에서 같은 룰로 반복 실패할 때 → 그 type 만 standard 모드로 받아 description 으로 디버깅

이 경우에만 `list_schemas(namespace="flow-schema", category="flow-node")` 로 카탈로그를 받아 어떤 node type 이 있는지 metadata only 로 확인할 수 있다 (응답은 `schema: null`).

### 절대 하지 말 것

- 위 보강 대상 외 type 에 standard 모드 사용 — minimal 로 시작.
- `get_schema(flow-data)` 와 `get_schema(node-{type})` 를 같은 type 으로 둘 다 minimal 호출 — flow-data 가 이미 그 $def 를 포함하므로 토큰 중복. (위 standard 보강은 detail 이 다르므로 중복 아님.)

## Node Type 요약

아래 표는 설계 대화를 위한 개념 요약이다. 실제 `flow_data` JSON 을 작성할 때는 이 표나 로컬 reference 를 schema source 로 쓰지 말고, [Schema Fetching](#schema-fetching) 에 따라 `get_schema('flow-data', detail='minimal')` 한 번을 호출해 현재 node type, field, enum, required 여부를 확인한다.

| Node | 용도 |
|------|------|
| `begin` | flow 시작점 |
| `conversation` | LLM 기반 대화 수행 |
| `tool` | vox.ai 등록 도구 실행 |
| `api` | HTTP API 호출 + 응답 변수 추출 |
| `sendSms` | SMS 발송 |
| `condition` | 변수 기반 조건 분기 (대화 없음) |
| `extraction` | 대화 컨텍스트에서 변수 추출 |
| `transferCall` | 통화 전환 (cold/warm) |
| `transferAgent` | 에이전트 전환 |
| `endCall` | 통화 종료 |
| `note` | 메모 (실행 없음) |

각 노드의 의미/사용 판단 → `node-types.md` 참조. Deprecated: `function` (→ `tool`). Unsupported: `knowledge` node (→ conversation node-level knowledge configuration). 정확한 schema 는 항상 MCP schema endpoint 결과를 따른다.

## 설계 패턴

**Linear**: `begin → 인사 → 본인확인 → 안내 → endCall`

**Branching**: `begin → 의도파악 → condition → 시나리오A/B/C → endCall`

**Data Collection**: `begin → extraction(이름) → extraction(번호) → api(조회) → condition → 안내 → endCall`

**Transfer Fallback**: `begin → 대화 → transferCall → (성공)종료 / (fallback)안내 → 재시도/endCall`

## Core Operating Rules

1. **공통 규칙 먼저** — flow에서도 실패 원인의 대부분은 음성 UX 위반(장문 발화, 부정확한 사실)이므로, `vox-agents`의 voice-ai-playbook 규칙(사실성 우선, 트레이드오프, 런타임 vs 개발 산출물 구분)이 flow에도 동일하게 적용된다.
2. node type, field, enum, required 여부를 추측하지 않는다 — `flow_data` 작성 직전에 `get_schema(namespace='flow-schema', schema_type='flow-data', detail='minimal')` 를 한 번 호출하고 그 결과를 기준으로 JSON 을 만든다. 이 한 응답에 envelope 과 모든 node type 의 `data` shape 가 함께 들어온다. per-node `get_schema(node-{type})` 는 narrow case 의 보조 호출이지 default 가 아니다. 자세한 패턴은 [Schema Fetching](#schema-fetching).
3. deprecated node(`function`)와 unsupported node(`knowledge`)는 신규 flow에 사용하지 않는다 — 지식 기반 응답이 필요하면 `conversation` node의 node-level knowledge 설정을 사용한다.
4. node 수는 최소화 — 불필요한 분할은 edge 관리를 복잡하게 하고 유지보수 비용이 증가한다.
5. 변수 이름은 snake_case, 의미가 명확한 이름 사용 — condition node와 변수 렌더러가 snake_case를 전제로 동작하며, 모호한 이름(val1, temp)은 노드 간 전달 시 혼동을 일으킨다.
6. 전환조건에 "다음 단계 이름"을 쓰지 않는다 — exit 조건만 정의해야 노드 순서가 바뀌어도 LLM이 올바르게 판단한다.
7. **conversation JSON 은 mode와 exit 조건을 빠뜨리지 않는다** — static 문구는 `promptType:"static"` + `staticSentence`, generated 대화는 `promptType:"dynamic"` + `prompt`/`firstMessage` 로 작성한다. 일반 `transitions[]` row 의 `condition` 은 빈 값/null/"None" 이 아니라 사용자가 그 노드를 벗어나도 되는 의미 있는 한국어 exit 조건이어야 한다. 조건 없는 row 는 자동 진행이 아니라 dead transition 이 된다.
8. **검증/비교는 정답 데이터 출처가 있어야 한다** — 본인확인, 예약조회, 계약검증처럼 사용자의 답을 기존 데이터와 비교해야 하는 flow 는 먼저 정답값 출처를 정한다. API node 의 responseVariables 또는 통화 시작 전 주입된 preset dynamic variables 가 없으면 "일치 확인"이라고 말하거나 condition 으로 검증하지 않는다. 그런 경우는 정보 수집 flow 로 낮추거나, 조회 API 를 추가한다.
9. **동일 인물/동일 대상 shortcut 을 명시한다** — "계약자와 학습자가 본인", "예약자와 방문자가 동일"처럼 앞에서 받은 답이 뒤 질문의 답을 결정하면 다시 묻지 않는다. extraction 에서 동일성 변수(`is_same_person` 등)를 만들고 condition 으로 재사용 path 와 추가질문 path 를 나눈다.
10. **산출물 경로는 두 가지** — (a) 대시보드 flow editor 에 사람이 직접 입력하는 노드 markdown, (b) v3 REST API (`PATCH /v3/agents/{id}` with `flow_data`) 또는 동등한 vox.ai MCP `create_agent` / `update_agent` 의 `flow_data` 파라미터로 보내는 JSON. JSON surface 는 schema endpoint 가 authoritative 하며, 수정은 항상 **전체 교체** 방식 — 기존 노드 일부만 patch 하지 않고 nodes/edges 전체를 다시 보낸다.
11. **Schema endpoint 우선** — `references/node-types.md` 는 node 선택과 실수 방지 playbook 이다. 실제 필드 목록을 복사하지 말고, 작업 중 받은 `get_schema(flow-data, minimal)` 결과를 기준으로 `flow_data` 를 작성한다. 전송 후 `get_agent` 로 round-trip 확인해 unknown field drop 을 잡는다.
12. **flow_data 전송 전 dry-run 먼저** — `create_agent` / `update_agent` 의 `flow_data` 를 보내기 전, MCP `validate_flow_data(flow_data=...)` 를 먼저 호출해 dry-run 한다. 응답의 `errors` 가 비었을 때만 진짜 호출하고, `warnings` 는 사용자에게 한두 줄로 요약 전달한다. 이걸 생략하면 (a) 차단 오류가 사용자에게 400/422 로 그대로 노출되고, (b) 자동 보정이 일어났음을 사용자가 알 길이 없다. dry-run 을 건너뛴 경우라도 `create_agent` / `update_agent` 응답 본문의 `result.message` 에 자동 보정 안내 텍스트가 실려오므로, 그 내용을 사용자에게 그대로 전달한다 (차단 오류 사전 차단만 안 될 뿐).
13. **nested config default 는 백엔드가 채운다** — `api_configuration` 의 인증/헤더/바디 옵션, `extraction_configuration`, `transfer_configuration`, `knowledge`, `message` 같은 nested 객체의 모든 필드를 LLM 이 외워 채울 필요 없다. `url`, `agent_id`, `tool_id` 처럼 누락 시 진짜 차단 오류가 나는 식별자만 명시하고, 나머지는 사용자가 의도적으로 지정한 키만 보낸다. 외운 default 를 강제로 채워 넣으면 schema 진화에 뒤처지고 dry-run warnings 만 늘어난다.
14. **외부 fixture 값은 만들지 않는다** — `transferCall` 은 실제 전화번호/SIP target 이 있을 때만 쓰고, `transferAgent` 는 실제 대상 agent UUID 가 있을 때만 쓴다. `tool` 은 `list_tools` 결과의 실제 id 를 사용한다. `sendSms` 의 발신번호/첨부 파일 key 처럼 운영 리소스가 필요한 값은 시나리오나 API가 제공하지 않으면 비워 두거나 해당 노드를 쓰지 않는다. placeholder 번호, 임의 UUID, 가짜 sender 를 넣지 않는다.
15. **agent data latency/STT 기본값은 보존한다** — flow agent 생성/수정에서 `data` 를 같이 보낼 때도 `vox-agents/references/default-agent-data.json` 과 schema 를 기준으로 한다. 한국어 STT 는 `stt.languages:["ko"]`, voice locale 은 `voice.language:"ko-KR"` 로 분리한다. `speech.responsiveness` 는 사용자 요구나 기존 agent 설정이 없으면 `1.0` 을 유지하고, 자연스러움을 추측해 낮추지 않는다.

## Response Handling

`validate_flow_data` / `create_agent` / `update_agent` 의 검증 결과를 어떻게 다루는지 정리.

### `validate_flow_data` 응답

- `valid: true` + `warnings: []` → 안전. 그대로 `create_agent` / `update_agent` 호출.
- `valid: true` + `warnings: [...]` → 자동 보정이 적용되었거나 권장 사항이 있음. 사용자에게 한두 줄로 요약 후 진행 (예: "api 노드 X 에 실패 fallback 자동 추가됨"). 응답의 `fixed_flow_data` 가 있으면 그것을 그대로 보낸다.
- `valid: false` → `errors[]` 의 각 항목 (`rule`, `node_id`, `message`, `suggestion`) 을 읽고 1회 수정 후 재검증. 같은 rule 이 다시 나오면 사용자에게 보고하고 멈춘다.

### `create_agent` / `update_agent` 422 / 400 응답

응답 envelope 가 `{"error": {"code": "VALIDATION_ERROR", "details": {"source": "flow_validator", "errors": [...]}}}` 형태이면 `details.errors[]` 를 위 dry-run 과 동일한 룰별 처리로 다룬다. 그 외 (스키마 자체 검증 실패) 는 그래프 구조 위반이므로 nodes / edges 자체를 점검한다.

### `create_agent` / `update_agent` 200 응답의 `result.message`

응답 본문의 `result.message` 텍스트에 자동 보정 안내가 실려온다 (별도 변형 없이 그대로 전달됨). dry-run 을 생략하고 바로 보낸 경우에도 자동 보정 사실을 이 필드로 확인할 수 있다. 자동 보정이 일어났다는 사실을 사용자에게 한 줄로 알린다 — 모르고 지나가면 다음 작업 때 보정 결과를 사람이 다시 의도와 맞춰야 한다.

### 룰 ID 빠른 참조

차단 오류 (errors, 사전에 막아야 할 것):
- `transfer_agent_missing_agent` — transferAgent 노드의 `agent.agent_id` 누락
- `tool_missing_tool_id` — tool 노드의 `tool_id` 누락
- `no_terminal_reachable` — begin 으로부터 endCall / transferCall / transferAgent 도달 경로 없음
- `operator_value_type_mismatch` — logic operator 의 numeric value 가 비-numeric

경고 (warnings, 자동 보정 후 알림):
- `api_missing_failure_edge` — api 노드 fallback edge 자동 추가됨 (단, target 이 endCall 직행이라면 사용자 의도대로 안내 conversation 으로 다시 라우팅 권장)
- `condition_unknown_variable` — logic 변수 미정의 (오타 의심)
- `unreachable_node` — 도달 불가 노드
- `variable_naming_non_snake_case` — 변수명 권장 형식 위반

조용한 자동 보정 (silent, 알림 없음):
- `trim_variable_names` — 변수명 trailing 공백/개행 trim
- `inject_nested_defaults` — nested config 누락 필드 default 보충
- `add_missing_outgoing_edges` — 비-terminal 노드 누락 outgoing edge 자동 추가
- `add_skip_response_fallback` — `is_skip_user_response: true` 노드 fallback safety net 자동 추가
- `add_condition_fallback` — condition 노드 fallback edge 자동 추가

## Ownership Boundary

| Owns | Does Not Own |
|------|--------------|
| flow design / node conversion / review | prompt authoring / diagnosis / revision (→ vox-agents) |
| node types / transitions / patterns | tool management (→ vox-tools) |
| variable system (flow scope) | web app UI guide (→ vox-web-app) |
| flow sketch / Mermaid visualization | pricing / billing |
| global node configuration | phone number management |

## Related Resources

### MCP Tools (vox.ai)
- `create_agent` — flow 에이전트 생성 (`type: "flow"`)
- `update_agent` — 에이전트 설정 수정
- `get_agent` — 기존 에이전트 설정 확인 (flow_data 포함)
- `list_agents` — 에이전트 목록
- `get_schema(namespace='flow-schema', schema_type='flow-data', detail='minimal')` — **default 호출.** envelope + 모든 node type 의 `data` shape 가 한 응답에 들어온다. `flow_data` 구성 전 1회 호출.
- `list_schemas(namespace='flow-schema', category='flow-node')` — narrow case 보조. 사용 가능한 node type 카탈로그 (`node-conversation`, `node-api`, ...). schema body 는 빠진 metadata only.
- `get_schema(namespace='flow-schema', schema_type='node-{type}')` — narrow case 보조. 특정 node 의 `data` shape 만. 일반적으로는 위 `flow-data` 한 번으로 충분하므로 호출하지 않는다.
- `validate_flow_data(flow_data=...)` — flow_data dry-run. 응답: `{valid, fixed_flow_data, warnings, errors}`. `create_agent` / `update_agent` 직전에 호출해 차단 오류를 사전 차단하고 자동 보정 결과를 사용자에게 전달한다.

### Docs (vox.ai docs / vox-docs)
- `https://docs.tryvox.co/docs/build/flow/overview` — 플로우 에이전트 개요
- `https://docs.tryvox.co/docs/build/flow/nodes/overview` — 노드 타입 개요
- `https://docs.tryvox.co/docs/build/flow/nodes/begin-node` — 시작 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/conversation-node` — 대화 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/api-node` — API 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/condition-node` — 조건 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/extraction-node` — 추출 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/tool-node` — 도구 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/transfer-node` — 통화 전환 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/transfer-agent-node` — 에이전트 전환 노드
- `https://docs.tryvox.co/docs/build/flow/nodes/end-node` — 종료 노드
- `https://docs.tryvox.co/docs/build/flow/transitions` — 전환 조건
- `https://docs.tryvox.co/docs/build/flow/advanced/global-node` — 글로벌 노드

### App URLs
- `https://www.tryvox.co/flow/{agentId}` — 플로우 에이전트 에디터. **agent_id 를 그대로 쓴다 — 별도 flow_id 가 아니다.**
- `https://www.tryvox.co/dashboard/{organizationId}/agents` — 에이전트 목록
