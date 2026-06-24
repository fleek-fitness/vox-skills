---
name: vox-tools
description: "Use whenever the user asks about vox.ai tool management — adding or removing built-in tools (end_call, transfer_call, transfer_agent, send_sms, send_dtmf), creating custom HTTP/API tools, tool attachment/detachment workflow, or any question about managing tools on a vox agent. Trigger on 'end_call 추가해줘', 'custom tool 만들어줘', '도구 연결 어떻게 해', '빌트인 도구 목록', or any vox tool question."
---

# vox-tools

vox.ai 에이전트의 도구 관리를 다루는 domain skill. 빌트인 도구와 커스텀 도구의 조회/생성/장착/해제를 안내한다.

## References

- **mcp-tool-management.md** — 도구 관리 전체 워크플로우. **도구 장착/해제 작업 시 읽기.** See [references/mcp-tool-management.md](references/mcp-tool-management.md)
- **mcp-built-in-tools.md** — 빌트인 도구 파라미터 상세 (end_call, transfer_call, transfer_agent, send_dtmf, send_sms). **빌트인 도구 설정 시 읽기.** See [references/mcp-built-in-tools.md](references/mcp-built-in-tools.md)
- **mcp-custom-tools.md** — 커스텀 도구(HTTP/API) 생성/연결/삭제. **커스텀 도구 작업 시 읽기.** See [references/mcp-custom-tools.md](references/mcp-custom-tools.md)

MCP 서버 연결 설정(Claude, Cursor, ChatGPT 등)은 `vox-onboarding` 스킬이 담당한다.

## Core Operating Rules

- 작업 유형에 맞는 reference를 먼저 열고 그 규칙을 적용한다.
- vox 플랫폼의 도구명/필드/엔드포인트는 **확인된 목록**이 없으면 만들어내지 않는다 — 존재하지 않는 도구를 안내하면 고객이 디버깅에 시간을 낭비한다.
- 변경 표면을 먼저 고른다. 레포에 남길 변경, diff/review/rollback/CI가 필요한 변경, coding-agent가 유지보수할 변경은 `vox` CLI의 `tool`/`agent` 루프로 처리한다. 조회·스키마 확인·one-off 원격 변경은 MCP를 사용한다.
- MCP로 실제 업데이트는 유저가 "적용/업데이트"를 명시했을 때만 실행한다 — `builtInTools`와 `toolIds`는 전체 교체(replace) 방식이라 실수로 실행하면 기존 도구가 전부 지워진다. durable 변경에서는 MCP `update_agent` 대신 CLI 파일 편집과 `vox agent push`를 사용한다.
- 도구 이름 규칙: 영문/숫자/`_`/`-`만 허용, 1-64자, 에이전트 내 중복 금지.

## Ownership Boundary

| Owns | Does Not Own |
|------|--------------|
| built-in tools (end_call, transfer_call, transfer_agent, send_sms, send_dtmf) | prompt authoring |
| custom tools (HTTP/API) | pricing |
| tool management workflow | flow design |
| tool naming rules | MCP server connection setup (→ vox-onboarding) |

## Related Resources

### MCP Tools (vox)
- `list_tools` — 커스텀 도구 목록
- `create_tool` — 커스텀 도구(HTTP/API) 생성
- `get_tool` — 커스텀 도구 상세
- `update_tool` — 커스텀 도구 수정
- `delete_tool` — 커스텀 도구 삭제
- `list_schemas`, `get_schema` — 빌트인 도구 payload 스키마 조회
- `get_agent`, `update_agent` — 도구 장착/해제 시 사용 (`data.builtInTools[]`, `data.toolIds[]`)

### CLI Commands (vox)
- `vox tool init` / `vox tool pull` — custom HTTP tool source 생성/가져오기
- `vox tool validate` / `vox tool explain` / `vox tool diff` / `vox tool status` / `vox tool push` — tools-as-code 변경 루프. `tool explain`은 JSON Pointer field의 의미와 관련 검증 명령을 보여주고, `tool push`는 placeholder 설명/URL과 `fire_and_forget` 도구의 결과 기반 flow transition 사용을 원격 저장 전에 거부한다.
- `vox agent attach tool <agent> <tool> --node <tool-node-id>` — flow tool node에 local `toolRef` 기록
- `vox agent validate` / `vox agent diff` / `vox agent push` — tool ref를 실제 remote tool ID로 컴파일해 agent 반영

### Docs (vox-docs)
- `https://docs.tryvox.co/docs/build/tools` — 도구 관리 개요

### App URLs
- `https://www.tryvox.co/agent/{agentId}` — 에이전트 상세 (Tools 탭)
