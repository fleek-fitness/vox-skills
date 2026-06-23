# Node Types: schema endpoint playbook

이 파일은 node type 을 고르는 기준과 흔한 실수를 정리한다. 실제 `flow_data` 의 node type, field, enum, required 여부는 이 파일에 박아두지 않는다. 작업 직전에 MCP schema endpoint 를 호출해 현재 API 계약을 확인한다.

## Authoritative schema

MCP 로 flow JSON 을 만들거나 수정하기 전에 항상 호출한다. **default 는 `flow-data` 한 번이다** — 이 한 응답에 envelope 과 모든 node type 의 `data` shape 가 함께 포함된다.

### Default (1회)

```text
get_schema(namespace="flow-schema", schema_type="flow-data", detail="minimal")
```

응답에 들어오는 것:

- envelope: `nodes[]`, `edges[]`, `viewport`, `FlowEdge`, transition row shape, edge handle 규칙
- 모든 node `$defs`: `BeginData`, `ConversationData`, `ApiData`, `ConditionData`, `ExtractionData`, `SendSmsData`, `ToolData`, `TransferCallData`, `TransferAgentData`, `EndCallData`, `NoteData`, `FunctionData` (deprecated)

`detail="minimal"` 은 description / title / examples 를 재귀적으로 제거해 응답을 약 41% 줄인다 (≈ 12,660 → 7,460 tokens). 권장 default.

agent `data` 도 같이 보낼 때:

```text
get_schema(namespace="agent-schema", schema_type="agent-data-create", detail="minimal")
get_schema(namespace="agent-schema", schema_type="agent-data-update", detail="minimal")
```

schema 결과를 받은 뒤에만 CLI source를 수정하거나 `create_agent(type="flow", data=..., flow_data=...)` / `update_agent(flow_data=...)` 를 호출한다. 레포 관리 작업이면 `vox doctor` 또는 `vox agent doctor` 후 `validate/diff/push`를 사용하고, MCP/API one-off 전송 후에는 `get_agent` 로 다시 읽어 보낸 field 가 silently drop 되지 않았는지 확인한다.

### Per-node fallback (narrow case 만)

`flow-data` 가 이미 모든 node $defs 를 포함하므로 일반 케이스에서는 per-node 호출이 필요 없다. 다음 좁은 경우에만 보조로 사용한다.

- flow 가 매우 큼 (15+ 노드, 다양한 type) + LLM context 가 빡빡해 minimal envelope 도 부담스러울 때
- 같은 flow 를 반복 patch 하면서 envelope 은 캐시하고 한 노드 type 의 detail 만 standard 로 다시 보고 싶을 때

```text
list_schemas(namespace="flow-schema", category="flow-node")          # 카탈로그 metadata only (schema body 없음)
get_schema(namespace="flow-schema", schema_type="node-{type}")       # 그 type 의 data shape만
```

### 절대 하지 말 것

- `get_schema(flow-data)` + `get_schema(node-{type})` 동시 호출 — flow-data 가 이미 그 node 의 $def 를 포함하므로 토큰 중복.
- `detail="standard"` 를 default 로 사용 — 항상 minimal 로 시작.

## Dry-run before create / update

`flow_data` 를 `create_agent` / `update_agent` 로 보내기 직전 호출 절차와 응답 처리는 SKILL.md 의 Core Operating Rules 와 [Response Handling](../SKILL.md#response-handling) 을 따른다. 핵심만 짚으면: dry-run 응답의 `errors` 가 비었을 때만 보내고, dry-run `warnings` 와 create / update 200 응답의 `result.message` 자동 보정 안내는 사용자에게 전달한다. dry-run 의 `errors` 에 결정론적으로 고칠 수 있는 항목이 섞여 있으면 손으로 고치지 말고 `autofix_flow_data(flow_data=...)` 로 보정한 뒤 다시 dry-run 한다.

## Incremental edit before full replace

기존 flow 의 노드/엣지 몇 개만 바꾸는 경우는 `update_agent` 의 전체 `flow_data` 교체 대신 `update_agent_partial(agent_id, operations[], validate_only?)` 의 ordered ops (atomic) 를 쓴다. 전면 재설계 수준일 때만 full 교체. 자세한 판단 기준은 SKILL.md [Incremental Editing](../SKILL.md#incremental-editing).

## Node selection guide

아래는 설계 판단용 요약이다. 정확한 JSON shape 는 schema endpoint 결과를 따른다.

| Node | 선택 기준 |
|---|---|
| `begin` | flow 시작점. 보통 첫 실행 node 로 연결한다. |
| `conversation` | 고객 발화를 듣고 LLM 이 응답하거나 exit 조건을 판단해야 하는 대화 단계. |
| `condition` | 이미 추출된 변수나 API 응답 값을 deterministic logic 으로 분기할 때. 고객 발화를 직접 해석하는 용도가 아니다. |
| `extraction` | 이전 대화 컨텍스트에서 이름, 주문번호, 의사 여부 같은 변수를 추출할 때. |
| `api` | 외부 HTTP API 호출과 응답 변수 추출이 필요할 때. |
| `tool` | vox.ai 에 등록된 custom tool 을 실행할 때. built-in tool 설정은 agent `data` schema 를 별도로 확인한다. |
| `transferCall` | 외부 전화번호나 SIP 대상으로 통화를 전환할 때. |
| `transferAgent` | 같은 조직 내 다른 vox.ai agent 로 대화를 넘길 때. |
| `sendSms` | 통화 중 SMS/LMS/MMS 를 발송할 때. |
| `endCall` | 종료 발화 후 통화를 끝내거나 즉시 종료할 때. |
| `note` | editor 설명용 메모. runtime 실행 흐름에는 넣지 않는다. |

## Edge and transition rules

- 현재 v3 저장 surface 에서는 분기를 source node 의 `data.transitions[]` / `data.logicalTransitions[]` 로 표현한다. edge 는 `sourceHandle` 로 그 transition row id 를 가리킨다.
- 모든 edge 는 `id`, `source`, `target`, `type:"custom"`, `sourceHandle`, `targetHandle` 을 포함한다.
- begin node 에서 나가는 edge 의 `sourceHandle` 은 transition id 가 아니라 web editor 고정 handle 인 `{beginNodeId}-source` 다. 일반적인 시작 노드 id 가 `begin` 이면 `begin-source`.
- begin 이 아닌 node 에서 나가는 edge 의 `sourceHandle` 은 source node 의 `data.transitions[].id` 또는 `data.logicalTransitions[].id` 중 하나와 정확히 일치해야 한다.
- `targetHandle` 은 `{targetNodeId}-target` 로 둔다.
- fallback 은 자동으로 생긴다고 가정하지 않는다. JSON 을 보낼 때 필요한 fallback transition row 와 edge 를 모두 명시한다.
- 기존 flow 수정 시 fallback transition 을 "더 좋은 이름"으로 정리하지 않는다. 기존 `id`, label/`condition`, `isFallback`, edge `sourceHandle` 을 보존하고, `Else` 같은 기존 editor 라벨도 사용자 요청 없이는 변경하지 않는다.
- **transition `condition` 은 항상 의미 있는 한국어 문장으로 채운다 (LLM 이 라우팅 근거로 사용 + 에디터 분기 라벨로 그대로 노출).**
  - 빈 문자열, 공백, `null`, 또는 `condition` 필드 누락 금지. 백엔드는 통과시키지만 에디터에서 빈 칸으로 보이고, runtime priority evaluator 는 이 문장을 보고 분기를 선택하기 때문에 의미를 잃는다.
  - **`isFallback: true` 는 canonical 한국어 문구를 명시한다** (생략 금지):
    - `api`, `function`, `tool`, `sendSms` → `condition: "요청 실패 시"`
    - `transferAgent`, `transferCall` → `condition: "에러 발생 시"`
  - `isSkipUserResponse: true` 는 extraction 처럼 이미 확보된 대화 컨텍스트를 바로 처리해야 하는 skip transition 에만 쓴다. static conversation 이 endCall 로 이어지는 row, 또는 api / sendSms / tool / transferCall / transferAgent 의 fallback row 에 붙이지 않는다. editor 가 skip row 를 숨겨 edge 가 끊긴 것처럼 보일 수 있다.
  - 그 외 모든 transition 은 노드 컨텍스트에 맞는 구체적 문장을 작성한다. 예: `"주문 번호를 받았을 때"`, `"고객이 환불을 요청한 경우"`, `"API 응답이 200 OK 일 때"`, `"payment_status 값이 '결제완료' 인 경우"`. 단순한 `"성공"` / `"실패"` 보다 어떤 조건에서 분기하는지를 풀어 쓴다.
- `position` 은 모든 노드에서 필수다. 픽셀 좌표 `{x: number, y: number}` 를 보내지 않으면 백엔드가 `NODE_POSITION_REQUIRED` 로 거절한다. 기본은 **가로 정렬** — `x` 를 320 step 으로 늘려가며 좌→우로 흐르게 두고, 분기 경로만 `y ± 240` 으로 위/아래 분리한다.
- `viewport`, `animated`, `selected`, `measured` 같은 나머지 editor field 는 schema endpoint 와 round-trip 결과로만 판단한다.

## High-risk nodes

아래 node 는 과거 데이터 형태와 현재 v3 surface 가 자주 섞인다. 작성 전 schema endpoint 결과를 반드시 대조한다.

- `transferAgent`: 과거 flat `agentId` 표현을 그대로 쓰지 않는다. 현재 schema 결과의 nested `agent.{agent_id, agent_version}` shape 를 따른다. **`agent.agent_id` 누락 시 dry-run 차단**.
- `transferCall`: 실제 전화번호/SIP target 이 없으면 쓰지 않는다. placeholder 번호로 통과시키지 말고, fallback 안내나 callback 요청 flow 로 바꾼다.
- `sendSms`: message object 와 섞지 않는다. SMS node 전용 field shape 를 schema 결과에서 확인한다.
- `sendSms`: 발신번호/첨부 key 같은 운영 fixture 는 임의로 만들지 않는다. schema default 로 충분한 값은 비워 둔다.
- `sendSms` 실패: 앞선 업무 API 가 성공했다면 fallback 은 "업무는 완료, 문자만 실패"를 말하는 endCall 로 보낸다. generic failure endCall 로 보내면 성공한 예약/등록/접수를 실패처럼 뒤집는다.
- `endCall`: 종료 멘트가 필요한 경우 node data 의 종료 응답 필드를 schema 로 확인한다. 최종 one-shot 안내만 남았다면 별도 static conversation 대신 endCall 종료 멘트에 넣는 편이 반복을 줄인다.
- `api`: 지원 HTTP method, auth, body, response variable shape 를 schema 결과에서 확인한다. 임의로 `PATCH` 등을 추가하지 않는다.
- `api` / `sendSms`: `responseMode: "fire_and_forget"` (응답 비대기) 은 `responseVariables`·결과 기반 transition 과 조합하면 저장이 거부된다. 결과를 쓰지 않는 발송 전용 노드에만 쓴다.
- `tool`: built-in tool 과 custom tool 을 섞지 않는다. custom tool 실행 node 와 agent `data.builtInTools` 설정은 별도 schema surface 다. **`tool_id` 누락 시 dry-run 차단**.
- `tool`: `responseMode` 는 노드에 없다 — 참조한 custom tool 의 `response_mode` 설정을 그대로 상속하며, fire 도구는 결과 기반 transition 과 조합할 수 없다.
- `tool`: `tool_id` 는 `list_tools` 결과에서 확인한 실제 id 만 사용한다. 임의 UUID 를 만들지 않는다.
- `condition`: deterministic 분기는 `data.logicalTransitions[]`, fallback 은 `data.transitions[]` 에 둔다 (v3 저장 surface 는 `edge.condition` 을 사용하지 않는다).

## Review checklist

1. `get_schema(namespace="flow-schema", schema_type="flow-data", detail="minimal")` 를 호출했는가? (per-node 호출은 narrow case 가 아니면 생략)
2. schema 결과에 없는 field 를 과거 문서나 UI 기억만으로 넣지 않았는가?
3. fallback, failure, else path 를 필요한 `edges` 로 명시했는가?
4. CLI 경로면 `vox doctor` 또는 `vox agent doctor` / `vox agent validate` / `vox agent diff` 절차를 거쳤는가? MCP/API 경로면 `validate_flow_data` → `errors === []` 확인 → `warnings` 사용자 전달, create / update 후 `result.message` 전달을 했는가? 자세한 응답 처리 룰은 SKILL.md [Response Handling](../SKILL.md#response-handling).
5. CLI 경로면 `vox agent diff/status`, MCP/API 경로면 `get_agent` 로 round-trip 확인했는가? 응답에서 사라진 field 가 있다면 schema 결과 기준으로 다시 작성했는가?
