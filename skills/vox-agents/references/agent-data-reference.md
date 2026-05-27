# agent.data Reference

MCP `create_agent` / `update_agent` 사용 시 `agent.data`의 동작 규칙을 정리한 레퍼런스.

정확한 field, enum, required 여부는 MCP schema endpoint 가 authoritative 하다. 이 파일은 실수하기 쉬운 운영 규칙만 요약한다.

```text
get_schema(namespace="agent-schema", schema_type="agent-data-create")
get_schema(namespace="agent-schema", schema_type="agent-data-update")
```

[default-agent-data.json](default-agent-data.json)은 기본 payload 예시와 seed 로만 사용한다. schema source 로 간주하지 않는다.

## Root 필수 필드

schema endpoint 결과를 따른다. 현재 기본 payload 에서는 `prompt`, `stt`, `llm`, `voice`, `postCall`, `toolIds`를 핵심 root 로 다룬다.
나머지(`builtInTools`, `speech`, `callSettings`, `security`, `knowledge`, `webhookSettings`, `presetDynamicVariables`)는 schema 결과에 맞춰 선택적으로 보낸다.

## 필드별 핵심 규칙

스키마 전체는 `get_schema` 결과를 참조한다. 여기는 **LLM이 실수하기 쉬운 규칙만** 정리한다.

### prompt

- `firstLineType` enum: `userFirst` | `aiFirstDynamic` | `aiFirstStatic`
- `firstLine`: `aiFirstStatic`일 때만 사용 — 매 통화 동일한 첫 인사. `aiFirstDynamic`이면 LLM이 생성하므로 빈 문자열로 두면 된다.
- `pauseBeforeSpeakingSeconds`: `0.0 ~ 5.0` — 인바운드에서 수신 후 첫 발화까지 대기 시간.
- `isFirstMessageInterruptible`: 첫 인사 중간에 사용자가 끊고 말할 수 있는지. 긴 인사말이면 `true` 권장.

### llm

- `model` 필수. 기본값 `z-ai/glm-4.7`.

### stt

- `languages` 필수. `string[]` 형태 (예: `["ko"]`, `["ko", "en"]`).
- `speed`: 단일 언어면 `"high"` | `"medium"` | `"low"`, 다국어(`languages.length >= 2`)면 `null`.
- 한국어 단일 언어 STT 는 `["ko"]` 를 사용한다. `["ko-KR"]` 는 STT language 가 아니라 voice locale 과 혼동한 값이므로 쓰지 않는다.

### voice

- `provider`, `id` 필수.
- `speed`: 발화 속도 (0.5~2.0). 기본 0.95.
- `temperature`: 음성 변이. 기본 0.9.

### postCall

- `actions[]` 각 항목에 `type`, `name` 필수.
- `type` enum: `string` | `enum` | `boolean` | `number`
- `type="enum"`이면 `enumOptions` 필수 — 없으면 런타임에 빈 선택지가 되어 추출 실패.

### callSettings

- `callTimeoutInSeconds`: 최대 통화 시간. 기본 900초(15분). 짧은 CS콜이면 300초 권장.
- `silenceCallTimeoutInSeconds`: 양쪽 무음 시 자동 종료. 기본 30초.
- `backgroundMusic` enum: `none` | `cafe` | `office` | `call_center` | `library` | `dial_tone`
- `noiseCancellation` enum: `none` | `nc` | `bvc` (기본 `bvc`)
- `dtmfTerminationEnabled` / `dtmfTerminationKey` / `dtmfTimeoutSeconds`: DTMF 입력 종료 설정.

### speech

- `isAllowInterruption`: 사용자가 에이전트 발화 중 끊을 수 있는지. 기본 `true`.
- `isAllowTurnDetection`: 턴 감지 활성화. 기본 `true`.
- `responsiveness`: 0.0~2.0. 높을수록 빠르게 응답 시작. 기본 1.0.
- `responsiveness` 는 latency 에 직접 영향을 주는 production default 다. 사용자 요구나 기존 agent 설정이 없으면 `1.0` 을 유지하고, 자연스러움/안정성 개선을 추측해 `0.8` / `0.9` 로 낮추지 않는다.
- `boostedKeywords`: `string[]` — STT가 더 잘 인식해야 할 키워드 (브랜드명, 전문용어).

### security

- `optOutSensitiveDataStorage`: `true`면 통화 데이터 저장 안함.

### builtInTools

`builtInTools[]`는 tool schema surface 를 따른다. tool type 별 required field 를 이 문서에 복사하지 말고, MCP schema endpoint 에서 현재 built-in tool schema 를 조회한다.

```text
list_schemas(namespace="tool-schema", category="built_in")
get_schema(namespace="tool-schema", schema_type="<built-in-tool-schema>")
```

## MCP 동작 규칙

### create_agent

- 현재 MCP 입력은 `name`, `type`, `data`, `flow_data` 기준이다.
- `type`: `"single_prompt"` | `"flow"` (기본 `"single_prompt"`).
- top-level `prompt`, `agent_type`, `llm`, `voice` shortcut 을 가정하지 않는다. 설정은 `data` object 안에 넣는다.
- `flow` agent 를 실사용 가능한 상태로 만들 때는 `flow_data` 를 함께 보낸다. 단순 shell agent 생성 여부는 API/MCP contract 를 확인한다.
- `data` 를 작성하기 전에 `get_schema(namespace="agent-schema", schema_type="agent-data-create")` 를 호출한다.

### update_agent

현재 MCP 입력은 `agent_id`, `name`, `data`, `flow_data` 기준이다. agent 설정 변경은 top-level shortcut 이 아니라 `data` 안의 sub-schema 로 보낸다.

동작:
1. 기존 `agent.data`를 읽음
2. 변경할 sub-schema 의 현재 값을 보존해야 하면 전체 subtree 를 다시 구성
3. `get_schema(namespace="agent-schema", schema_type="agent-data-update")` 로 update shape 확인
4. `update_agent(agent_id=..., data=...)` 호출
5. `get_agent()`로 round-trip 확인

**sub-schema replacement semantics가 핵심이다** — `builtInTools`에 `end_call` 하나만 넣으면 기존 도구가 전부 사라질 수 있다. 반드시 `get_agent()`로 현재 값을 읽고, 수정 후 보존할 sibling 값을 함께 다시 보내라.

## 실전 예시

### 최소 create_agent

```text
create_agent(
  name="CS 상담 에이전트",
  type="single_prompt",
  data={
    "prompt": {
      "prompt": "당신은 CS 상담 에이전트입니다..."
    }
  }
)
```

생략한 top-level agent data 는 서버 기본값으로 채워질 수 있지만, 정확한 required/default 동작은 `agent-data-create` schema 결과를 따른다.

### update_agent — 프롬프트 + LLM 변경

```text
update_agent(
  agent_id="agent-uuid",
  data={
    "prompt": {"prompt": "수정된 프롬프트..."},
    "llm": {"model": "gpt-4o-mini", "temperature": 0.2}
  }
)
```

### update_agent — builtInTools 추가 (replace 주의)

```text
# 1. 현재 설정 조회
get_agent(agent_id="agent-uuid")
# → data.builtInTools: [{"toolType": "end_call", "name": "end_call"}]

# 2. list_schemas/get_schema 로 built-in tool schema 확인

# 3. 기존 + 신규를 합쳐서 전체를 보냄
update_agent(
  agent_id="agent-uuid",
  data={
    "builtInTools": [
      {"toolType": "end_call", "name": "end_call"},
      {"...": "schema endpoint 결과에 맞춘 신규 built-in tool payload"}
    ]
  }
)
```

### 확인

```text
get_agent(agent_id="agent-uuid")
```

반영 후 반드시 확인. unknown key가 strip되었거나 검증 에러가 발생할 수 있다.
