# 도구 관리 가이드

vox.ai 에이전트에 도구를 조회/생성/장착/해제하는 방법을 다룹니다. 조회와 빠른 one-off 작업은 MCP가 적합하고, 레포에 남길 변경은 `vox` CLI의 tools-as-code / agent-as-code 루프를 우선합니다.

## 개요

vox.ai 에이전트는 두 종류의 도구를 사용합니다.

| 구분 | 빌트인 도구 | 커스텀 도구 |
|------|------------|------------|
| 종류 | `end_call`, `transfer_call`, `transfer_agent`, `send_sms`, `send_dtmf` | HTTP/API |
| 범위 | 플랫폼 전체 공통 | 조직(organization) 단위 |
| 생성 | 불가 (플랫폼 제공) | `create_tool()` |
| 에이전트 연결 | `update_agent(builtInTools=[...])` | `update_agent(toolIds=[...])` |

- **빌트인 도구**: 플랫폼이 제공하는 기본 도구. 별도 생성/연결 엔드포인트 없이 `data.builtInTools[]` 배열로 에이전트에 직접 설정(파라미터)을 지정하여 장착합니다.
  - 상세: See [mcp-built-in-tools.md](mcp-built-in-tools.md)
- **커스텀 도구**: 조직이 직접 만드는 HTTP 엔드포인트 호출 도구. `create_tool()`로 만들고 `data.toolIds[]`로 연결합니다.
  - 상세: See [mcp-custom-tools.md](mcp-custom-tools.md)
- **에이전트 설정 데이터**(`agent.data`): `vox-agents` 스킬의 `references/agent-data-reference.md` 참조

## End-to-end 워크플로우

### CLI-first durable workflow

사용자가 레포, diff, 리뷰, PR, 롤백, CI, 커밋, agent-as-code를 언급하거나 코딩 에이전트가 유지보수할 변경이면 이 경로를 사용합니다.

```bash
vox tool init check_order --url https://api.example.com/orders --method GET
# edit tools/check_order/tool.json
vox tool validate check_order
vox tool diff check_order --json
vox tool push check_order

vox agent pull <agent-id> --agent support
vox agent attach tool support check_order --node lookup_order
vox agent validate --agent support --json
vox agent status --all --offline --json
vox agent diff --agent support --json
vox agent push --agent support
# 프로덕션 승격까지 요청받은 경우에만:
vox agent version save --agent support --description "reviewed release"
vox agent promote v1 --agent support --yes
```

기존 remote tool을 레포로 가져올 때:

```bash
vox tool pull <tool-id> --tool check_order
vox tool status check_order --json
```

CLI source에는 raw token/API key를 쓰지 말고 `${env:NAME}` 또는 `${secret:name}` 형태의 reference를 사용합니다. `vox tool validate`가 literal secret과 placeholder tool/parameter description을 잡고, `vox tool push`는 push 시점에만 secret reference를 해석합니다.

빌트인 도구는 별도 tool resource가 아니라 agent data / flow node 설정입니다. durable 변경에서는 `vox agent pull` 후 `agents/<name>/agent.json`을 편집하고 `vox doctor` 또는 `vox agent doctor` 후 `vox agent validate/diff/push`로 반영합니다. 프로덕션 승격은 리뷰/승인이 끝난 뒤 `vox agent version save`와 `vox agent promote --yes`로 분리해 실행합니다.

### MCP direct workflow

에이전트에 빌트인 + 커스텀 도구를 모두 장착하는 전체 흐름입니다.

### 1. 빌트인 도구 payload 스키마 확인

```
get_schema(namespace="tool-schema", category="built_in")
```

### 2. 에이전트 생성

```
create_agent(name="CS 상담 에이전트", prompt="당신은 CS 상담 에이전트입니다...")
```

### 3. 빌트인 도구 장착

```
update_agent(
  agent_id="agent-uuid",
  builtInTools=[
    {"toolType": "end_call", "name": "end_call", "description": "통화를 종료합니다."},
    {
      "toolType": "transfer_call", "name": "transfer_to_human",
      "transferConfiguration": [{"transferType": "phone", "transferTo": "010-1234-5678"}],
      "transferType": "cold"
    }
  ]
)
```

`builtInTools`는 **교체(replace)** 방식입니다.
- 일부만 바꾸려면 `get_agent()`로 현재 `data.builtInTools`를 읽고
- 원하는 항목을 추가/제거한 전체 배열을 다시 `update_agent(builtInTools=[...])`로 저장하세요.

### 4. 커스텀 도구 생성 & 연결

```
create_tool(
  name="check_order",
  input_schema={"type": "object", "properties": {"order_id": {"type": "string"}}, "required": ["order_id"]},
  api_configuration={
    "url": "https://api.example.com/orders",
    "method": "GET",
    "timeout_seconds": 10
  },
  description="주문 상태 조회"
)

update_agent(agent_id="agent-uuid", toolIds=["tool-uuid"])
```

### 5. 확인

```
get_agent(agent_id="agent-uuid")
```

`data.builtInTools`와 `data.toolIds`를 확인.

## 주의사항

### name 규칙

- 영문/숫자/`_`/`-`만 허용, 1-64자
- 정규식: `^[A-Za-z0-9_-]{1,64}$`
- 에이전트 내 name 중복 금지 (중복 시 에러)

### 예약어

도구 이름으로 사용 불가: `extract_variables`, `request_api`, `retrieve_knowledge`, `determine_transition`

### 도구 장착 순서

`update_agent`의 도구 관련 입력은 `builtInTools`, `toolIds`이며 모두 **교체(replace)** 방식입니다.
- 단건 추가/해제도 `현재 목록 조회 -> 목록 수정 -> 전체 목록 저장` 순서로 처리하세요.

### 커스텀 도구 삭제

커스텀 도구 삭제: `delete_tool(tool_id="uuid")` — 상세는 [mcp-custom-tools.md](mcp-custom-tools.md) 참조.
