# Execution node markdown

이 문서는 conversation 외 노드의 **설계 markdown** 작성법을 다룬다. MCP/API `flow_data` JSON field 는 항상 `get_schema(namespace="flow-schema", schema_type="flow-data", detail="minimal")` 결과를 따른다. api / transferCall / transferAgent / sendSms / tool 처럼 prose 가 load-bearing 인 무거운 노드는 SKILL.md [Schema Fetching](../SKILL.md#schema-fetching) 에 따라 그 type 만 standard 모드로 보강한다.

## Shared rules

- 실패, else, fallback path 가 필요하면 markdown 에 의도를 쓰고 JSON 변환 시 `edges` 로 명시한다.
- 과거 field 이름(`agentId`, `promptType`, `staticSentence`, node 내부 `transitions[]`)을 JSON field 로 복사하지 않는다.
- 각 노드는 `## name / ## content / ## transition conditions` 구조를 유지한다.
- nested config default 채우기 / dry-run 호출 / 응답 처리는 SKILL.md 의 Core Operating Rules #9~#10 과 [Response Handling](../SKILL.md#response-handling) 을 따른다 — 식별자 (`url`, `agent.agent_id`, `tool_id`) 만 책임지고 채우고 나머지 nested 필드는 백엔드 보충을 신뢰한다.

## extraction

대화 컨텍스트에서 값을 추출한다. 고객에게 새 질문을 하지 않는다.

```md
## name
[노드 이름]

## content
### 목적
1. [추출 소스]에서 [추출 대상]을 추출한다.

### 추출 변수
- [variable_name] ([type]): [추출 소스] + [추출 대상 설명] + [포맷 규칙]
  ex) [기대 출력 예시]

## transition conditions
(조건 없이 다음 노드로 진행. JSON 변환 시 현재 schema 의 skip/edge field 를 확인하고 edge 를 명시.)
```

작성 규칙:
- 추출 소스를 명시한다: 직전 대화, DTMF 입력, API 응답 설명 등.
- 전화번호, 주문번호처럼 형식이 있는 값은 포맷을 적는다.
- 변수명은 snake_case 로 쓴다.
- 여러 값을 추출해야 하면 각 변수의 기대 출력 예시를 둔다.

## condition

이미 만들어진 변수 값을 deterministic logic 으로 분기한다. 고객 발화를 직접 해석하지 않는다.

```md
## name
[노드 이름]

## content
### 목적
1. [분기 판단 목적]

### 분기 조건
- {{variable_name}} == "값A" → [결과 라벨]
- {{variable_name}} == "값B" → [결과 라벨]
- default → [결과 라벨]

## transition conditions
(변수 기반 분기. JSON 변환 시 edge condition union 과 operator enum 을 schema endpoint 로 확인한다.)
```

작성 규칙:
- 앞선 extraction/api 에서 만든 변수만 소비한다.
- else/default 분기를 둔다.
- 실제 JSON operator 이름은 schema endpoint 결과를 따른다.

## api

외부 HTTP API를 호출하고 응답 변수 추출 의도를 정의한다.

```md
## name
[노드 이름]

## content
### 목적
1. [API 호출 목적]

### 호출 전 발화
- 발화 모드: [none/static/generated]
- 대기 멘트: "[필요할 때만]"

### API 설정
- method: [schema endpoint enum 확인]
- url: [요청 URL. {{variable_name}} 사용 가능]
- body: [필요 시]
- auth: [필요 시]

### 응답 변수
- [variable_name]: [JSONPath 표현식] — [설명]

## transition conditions
- 성공: API 응답 정상 수신 시 다음 노드로 진행. ai-edge 또는 logic-edge — 응답 변수 (`{{response_var}}`) 가 채워졌는지 기준으로 판단.
- 실패: API 호출 실패 시 [실패 안내 노드]로 진행. fallback edge. **endCall 직행 금지** — 사용자에게 사정 안내 후 재시도 또는 정중한 마무리.
```

작성 규칙:
- 성공 분기와 **명시적 실패 분기** 를 항상 한 쌍으로 설계한다. api 노드는 timeout, 5xx, 응답 형식 오류 등 실패 가능성이 일상이므로 silent termination(=fallback → endCall) 으로 처리하면 사용자가 갑자기 끊긴 듯한 경험을 한다.
- 실패 분기는 보통 conversation 노드(예: "지금 시스템이 잠시 어렵네요, 다시 안내드릴게요")로 받아서 양해 멘트 → 마무리 흐름으로 흡수한다.

**Anti-pattern (피하기):**

```json
{ "source": "node_api", "target": "node_end",
  "condition": { "type": "fallback" }, "skip_user_response": false }
```

→ 호출 실패 시 안내 한마디 없이 endCall. 사용자는 갑자기 끊긴 인상을 받는다.

**권장 패턴:**

```json
{ "source": "node_api", "target": "node_api_failure_apology",
  "condition": { "type": "fallback" }, "skip_user_response": false }
```

`node_api_failure_apology` 는 짧은 사과/안내 conversation 노드 — "조회가 어려워서 확인 후 다시 안내드릴게요" 정도. 최종 종료만 남았다면 별도 static conversation 을 만들지 말고 endCall 종료 멘트에 복구 안내를 넣어도 된다. 중요한 것은 사용자가 빈 종료처럼 느끼지 않게 하는 것이다.

### Post-success SMS fallback

업무 처리 API 가 이미 성공한 뒤 `sendSms` 가 실패하면, 실패 안내는 **업무 결과를 보존**해야 한다. SMS 실패를 전체 처리 실패처럼 말하면 안 된다.

권장:

- 성공 endCall: "접수가 완료되었습니다. 접수번호는 {{request_id}}입니다. 확인 문자를 보내드렸습니다. 감사합니다."
- SMS 실패 endCall: "접수는 완료되었습니다. 다만 문자 발송만 지금 어렵습니다. 접수번호는 {{request_id}}이고, 필요하면 데스크에서 이 번호로 확인해 주세요. 감사합니다."

피하기:

- "시스템 처리나 문자 발송을 완료하지 못했습니다."
- "담당 부서에서 순차 처리 예정입니다."
- API 성공 변수(`{{request_id}}`, `{{booking_id}}`, `{{processed}}`)를 무시하고 generic failure 로 종료.

### JSON shape (api 노드)

api 노드의 `data` 는 모두 camelCase 다. `headers` 는 **객체** (`{ "X-Foo": "bar" }`) 이지 배열이 아니다. body 가 있으면 `bodyEnabled: true`, headers 가 있으면 `headersEnabled: true` 를 같이 둔다 (없는 키는 보내지 않는다).

```json
{
  "id": "api_lookup",
  "type": "api",
  "position": {"x": 640, "y": 0},
  "data": {
    "name": "주문 조회",
    "apiConfiguration": {
      "method": "POST",
      "url": "https://api.example.com/orders/lookup",
      "headersEnabled": true,
      "headers": {"Content-Type": "application/json"},
      "bodyEnabled": true,
      "body": "{\"order_last4\":\"{{order_last4}}\"}",
      "timeoutSeconds": 10
    },
    "responseVariables": [
      {"variableName": "order_id", "jsonPath": "$.order_id"},
      {"variableName": "order_found", "jsonPath": "$.found"}
    ],
    "logicalTransitions": [
      {"id": "lt_found", "condition": {
        "logicalOperator": "and",
        "conditions": [{"variable": "order_found", "operator": "equals", "value": "true"}]
      }}
    ],
    "transitions": [
      {"id": "tr_lookup_fail", "condition": "요청 실패 시", "isFallback": true}
    ]
  }
}
```

흔한 실수:
- `api_configuration`, `response_variables`, `logical_transitions` (snake_case) 로 보내면 v3 가 거절한다.
- `headers: [{"key": "...", "value": "..."}]` (배열) 로 보내면 거절된다 — 객체 매핑이다.
- 응답 변수의 jsonPath 는 `$.found` 같은 mock 친화 키만 쓴다. 도메인 키 (`$.data.order_id`) 는 scenario_test mock 에 없어서 logical transition 이 항상 false 로 평가된다.

## endCall

통화를 종료한다. 종료 직전 발화를 할 수도 있고 즉시 종료할 수도 있다.

최종 안내만 남은 경우에는 endCall 의 종료 멘트를 적극 사용한다. 별도 static conversation node 로 "안내 → endCall" 을 만들면 사용자 응답을 기다리며 같은 문구가 반복될 수 있다.

```md
## name
[노드 이름]

## content
### 목적
1. [종료 목적]

### 종료 멘트
- message mode: [static/generated/none]
- 멘트: "[필요할 때만]"

### Global Node 설정
- global enter condition: "[언제든 이 종료로 진입해야 하는 조건. 필요할 때만]"

## transition conditions
(통화 종료. 전환 없음.)
```

## transferCall

외부 전화번호 또는 SIP 대상으로 통화를 전환한다.

```md
## name
[노드 이름]

## content
### 목적
1. [전환 이유]

### 전환 전 발화
- 발화 모드: [none/static/generated]
- 멘트: "[필요할 때만]"

### 전환 설정
- transfer type: [cold/warm]
- transfer target: [전화번호 또는 SIP URI]
- displayed caller id: [agent/user]

### warm transfer 설정
- transfer message mode: [static/generated]
- 멘트/프롬프트: "[상담원에게 전달할 브리핑]"

## transition conditions
- 성공: 전환 성공 시 에이전트 퇴장.
- 실패: 전환 실패 시 fallback edge로 진행. (JSON 변환 시 edge 명시)
```

JSON 변환 시 `data.transferConfiguration.transferTo` 는 필수다. 이 값은 시나리오/운영자가 제공한 실제 전화번호 또는 SIP URI 여야 한다. 테스트 편의를 위해 임의 번호를 만들지 말고, 실제 target 이 없으면 transferCall 대신 endCall 안내나 callback 요청 flow 로 설계한다. 실패 row 는 `{"condition":"에러 발생 시","isFallback":true}` 로 만들고 `isSkipUserResponse` 를 붙이지 않는다. fallback row 에 skip flag 를 붙이면 editor 에서 source handle 이 숨겨져 선이 끊긴 것처럼 보일 수 있다.

## transferAgent

같은 조직 내 다른 vox.ai 에이전트로 대화를 넘긴다.

```md
## name
[노드 이름]

## content
### 목적
1. [전환 이유]

### 전환 설정
- target agent: [전환 대상 에이전트 ID/버전. JSON shape 는 schema endpoint 확인]
- preserve chat context: [true/false]

## transition conditions
- 성공: 에이전트 전환 성공 시 현재 에이전트 퇴장.
- 실패: 전환 실패 시 fallback edge로 진행. (JSON 변환 시 edge 명시)
```

JSON 변환 시 실패 row 는 `{"condition":"에러 발생 시","isFallback":true}` 로 만들고 `isSkipUserResponse` 를 붙이지 않는다.

작성 규칙:
- **`agent.agent_id` (UUID) 는 필수** — 누락 시 dry-run 이 차단한다. `agent_version` 도 함께 명시 권장: 미지정 시 latest 가 어떤 버전인지 알기 어려워 운영 추적이 힘들다.
- 실제 대상 agent UUID 가 없으면 transferAgent 노드를 만들지 않는다. 임의 UUID 또는 숫자 placeholder 를 넣지 말고, `list_agents` / 기존 `get_agent` 컨텍스트 / 사용자 제공 값에서 확인된 agent 만 사용한다.
- 과거 flat `agentId` 표현은 사용하지 않는다. 현재 schema 의 nested `agent.{agent_id, agent_version}` shape 를 따른다.

## sendSms

통화 중 SMS/LMS/MMS 를 발송한다.

```md
## name
[노드 이름]

## content
### 목적
1. [SMS 발송 이유]

### SMS 내용
- SMS mode: [static/dynamic]
- 멘트: "[SMS 내용 또는 생성 프롬프트]"

### 발신 설정
- sender: [기본값 사용 또는 발신 가능 번호. JSON shape 는 schema endpoint 확인]

## transition conditions
- 성공: SMS 발송 성공 시 다음 노드로 진행.
- 실패: SMS 발송 실패 시 fallback edge로 진행. (JSON 변환 시 edge 명시)
```

작성 규칙:
- 업무 API 성공 후의 SMS 실패 fallback 은 "업무는 완료, 문자만 실패" endCall 로 보낸다.
- SMS 실패 fallback 에서 이미 성공한 예약/등록/접수 결과를 실패로 뒤집지 않는다.
- scenario_test 에서는 SMS 가 지원되지 않아 실패할 수 있으므로, fallback 멘트는 본 통화 안에서 접수번호/콜백 시간/확인 방법을 직접 안내하도록 쓴다.
- 발신번호, 첨부 file key, 특정 템플릿 id 같은 운영 fixture 는 임의로 만들지 않는다. schema default 로 충분한 값은 비워 두고, 실제 값이 필요한 환경이면 사용자/운영자에게 받아서 넣는다.

## tool

custom tool 실행 node 와 agent `data.builtInTools` 설정은 schema surface 가 다르다. JSON 변환 전 schema endpoint 로 현재 shape 를 확인한다.

```md
## name
[노드 이름]

## content
### 목적
1. [도구 실행 이유]

### 발화 모드
- 발화 모드: [none/static/generated]
- 멘트: "[필요할 때만]"

### 도구 설정
- tool: [custom tool 또는 built-in tool 여부를 명시]
- 입력: [필요 시]

## transition conditions
- 성공: 도구 실행 성공 시 다음 노드로 진행.
- 실패: 도구 실행 실패 시 fallback edge로 진행. (JSON 변환 시 edge 명시)
```

작성 규칙:
- **`tool_id` 는 필수** — 누락 시 dry-run 이 차단한다. 등록되지 않은 custom tool 을 가리키지 않도록 `list_tools` 결과의 ID 를 사용한다.
- 임의 UUID 를 tool id 로 만들지 않는다. 필요한 custom tool 이 없으면 tool 노드가 아니라 api / conversation / endCall 로 설계를 바꾼다.
- built-in tool (end_call, transfer_call, transfer_agent, send_sms, send_dtmf) 설정은 agent `data.builtInTools` schema surface 다 — tool 노드 안에 직접 넣지 않는다.

## Global node

통화 종료 요청, 상담원 연결 요청처럼 어디서든 발생할 수 있는 예외는 global node 후보가 될 수 있다.

작성 규칙:
- 보통 conversation 또는 endCall 에 설계한다. 정확한 허용 shape 는 schema endpoint 결과를 따른다.
- global enter condition 은 고객 발화 기반으로 쓴다.
- 2-3개 이내로 제한한다. 너무 많으면 전환 충돌 위험이 커진다.
