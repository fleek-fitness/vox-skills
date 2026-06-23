---
name: vox-agents
description: "Use whenever the user is building a vox.ai voice agent — writing or revising a system prompt, diagnosing agent behavior, or working with agent.data schema via MCP (create_agent / update_agent). This is the default agent skill for prompt-based agents. For flow agent design (multi-node), use vox-flow instead. Trigger on '프롬프트 작성해줘', '프롬프트 고쳐줘', '에이전트가 이상하게 답해', '음성 에이전트', or any vox prompt agent authoring question."
---

# vox-agents

vox.ai 프롬프트 에이전트(single prompt)를 설계하는 domain skill. 공통 음성 UX 규칙과 에이전트 생성/수정/진단/리팩터링을 담당한다.

Flow 에이전트(multi-node)가 필요한 경우 → `vox-flow` 스킬로 handoff. 사용자가 flow node, node prompt, condition_node, transition, fallback 을 언급하면 single prompt 를 작성하지 말고 `vox-flow` 로 handoff한다.

## Agent Type 판단 기준

| 기준 | Single Prompt | Flow |
|------|---------------|------|
| 대화 복잡도 | 단순 Q&A, 1~2 분기 | 3개 이상 분기, 복잡한 시나리오 |
| 결정적 흐름 제어 | prompt에 의존 | node 단위로 보장 |
| 조건부 분기 | 어려움 | condition node로 정확히 제어 |
| 외부 API 연동 | tool로 가능 | api node로 응답 변수 추출까지 |
| 변수 추적 | 어려움 | extraction → condition 체인 |
| 유지보수 | prompt 하나 수정 | node 단위 독립 수정 |

사용자가 유형을 명시하지 않으면 위 기준으로 판단하여 제안한다. Flow가 적합하면 `vox-flow`로 handoff.

## References

- **voice-ai-playbook.md** — 음성 UX 핵심 규칙, 트레이드오프 우선순위. **새 에이전트 설계 시 가장 먼저 읽기.** See [references/voice-ai-playbook.md](references/voice-ai-playbook.md)
- **default-agent-data.json** + **agent-data-reference.md** — agent.data root 구조 예시(JSON, 복사용 기본값 아님) + MCP 동작 규칙(md). **MCP로 에이전트를 생성·수정할 때 둘 다 읽기.** See [references/default-agent-data.json](references/default-agent-data.json), [references/agent-data-reference.md](references/agent-data-reference.md)
- **ivr-navigation-best-practice.md** — IVR 메뉴 탐색, DTMF 전략, send_dtmf 프롬프팅. **에이전트가 ARS/IVR을 통과해야 하는 시나리오에서 읽기.** See [references/ivr-navigation-best-practice.md](references/ivr-navigation-best-practice.md)
- **voice-ai-prompt-template.md** — 한국어 프롬프트 템플릿. **신규 프롬프트 작성 시 복사해 사용.** See [references/voice-ai-prompt-template.md](references/voice-ai-prompt-template.md)
- **voice-ai-prompt-diagnosis.md** — 실패 사례 원인 진단. **에이전트가 이상하게 동작할 때 읽기.** See [references/voice-ai-prompt-diagnosis.md](references/voice-ai-prompt-diagnosis.md)
- **voice-ai-prompt-revision.md** — 진단 기반 리팩터링. **diagnosis 산출물의 change_requests를 반영할 때 읽기.** See [references/voice-ai-prompt-revision.md](references/voice-ai-prompt-revision.md)
- **variable-system.md** — 변수 카테고리(system/dynamic/extraction), naming, 렌더링 위치. **변수 설계 시 읽기.** See [references/variable-system.md](references/variable-system.md)
- **voice-emotive-speech.md** — Cartesia Sonic-3 기반 감정/속도/웃음 표현력 prompting 가이드 (SSML `<emotion>`, `<speed>`, `[laughter]`). **유저가 "자연스럽게", "웃게", "속도 조절", "감정 표현"을 요청할 때 읽기.** See [references/voice-emotive-speech.md](references/voice-emotive-speech.md)

## Core Operating Rules

1. **작업 유형에 맞는 reference를 먼저 열고** 그 규칙을 적용한다.
2. **사실성 우선** — vox 플랫폼/도구/모델 관련 사실은 확인된 목록이 없으면 만들어내지 않는다. 잘못된 사실은 고객 신뢰를 손상시키고 실제 장애로 이어진다.
   - 목록이 없으면: (1) 확인 질문 1개, 또는 (2) `[[...]]` placeholder로 남긴다.
3. **트레이드오프 우선순위**: 사실성/정확성 > 음성 UX > 친절함/설명량
4. **런타임 발화 vs 개발 산출물 구분** — "기본 1–2문장" 같은 장문 방지 규칙은 에이전트의 **런타임 발화**에만 적용된다. 개발 산출물(시스템 프롬프트, 진단 YAML, 패치 노트)은 필요한 만큼 길어도 된다. 이 구분이 없으면 LLM이 voice UX 규칙을 개발 output에까지 적용해서, 프롬프트의 가드레일/도구 섹션을 지나치게 축약하는 실패가 발생한다.
5. **최소 변경 리팩터링** — 기존 프롬프트의 필수 섹션/도구 계약/변수/에러처리를 삭제하면 런타임 장애가 발생한다.
6. **진단 → 리팩터링 핸드오프**: diagnosis에 `failure_modes`와 `change_requests`가 반드시 포함, revision은 `change_requests`를 근거로만 변경한다 — 근거 없는 재설계는 기존 동작을 깨뜨린다.
7. **변경 표면 선택** — 조회·스키마 확인·one-off 생성은 MCP가 적합하다. 그러나 사용자가 레포, 코드, diff, 리뷰, PR, 롤백, CI, 커밋, 또는 "agent-as-code" 맥락을 언급하면 `vox` CLI 루프로 변경한다. 코딩 에이전트가 durable 변경을 해야 할 때 기본 경로는 `vox agent pull/init/add/import -> agent explain/agent set 또는 edit agents/<name>/agent.json -> agent test init/list/show/validate(테스트 의도를 레포에 남길 때) -> vox doctor 또는 agent doctor -> validate -> diff/status -> push` 이다. 프로덕션 승격은 push 이후 별도 승인 단계로 `agent version save -> agent promote --yes`를 사용한다.
8. **MCP 실행 주의** — 유저가 "적용/업데이트"를 명시했을 때만 실행. builtInTools/toolIds가 전체 교체 방식이라 실수로 실행하면 기존 설정이 날아간다. `agent-data-reference.md` 참조. durable 변경에서는 MCP `update_agent` 대신 CLI 파일 편집과 `vox agent push`를 사용한다.
9. **기본값은 서버가 채운다** — 기본값의 SSOT 는 api-server 이고, get_schema 는 shape 만 주고 기본 *값* 은 주지 않는다. 의도적으로 override 하지 않는 sub-schema(특히 `llm`, `voice`)는 보내지 말고 OMIT 해 서버 기본값을 적용한다. override 할 때만 허용 값을 `list_llm_models` / `list_voice_models` 로 조회하고 shape 는 `get_schema(namespace="agent-schema", schema_type="agent-data-create" | "agent-data-update", detail="minimal")` 로 확인한다. 한국어 STT 는 `stt.languages:["ko"]` 를 사용하고 `ko-KR` 은 `voice.language` 에만 쓴다. `speech.responsiveness` 는 사용자 요구나 기존 agent 설정이 없으면 `1.0` 을 유지하며, "자연스러움" 명목으로 `0.8` / `0.9` 로 낮추지 않는다.

## Workflow

신규 작성:
1. `voice-ai-playbook.md` 읽기 → 규칙 숙지
2. `voice-ai-prompt-template.md` 복사 → 요구사항 반영
3. 변경 표면 선택:
   - 빠른 one-off/온보딩이면 agent.data 스키마를 확인하고 MCP로 생성
   - 레포에 남겨야 하면 `vox agent init`, `vox agent add`, 또는 dashboard export 파일의 `vox agent import`로 source 생성 후 `vox agent set` 또는 `agents/<name>/agent.json` 편집으로 설정을 바꾸고, 테스트 의도를 남겨야 하면 `vox agent test init/list/show/validate`로 `agents/<name>/tests/*.json`을 만들고 리뷰한다. 이후 `vox doctor` 또는 `vox agent doctor` 후 `vox agent validate/diff/push` 실행. 프로덕션 승격은 사용자가 승인한 경우에만 `vox agent version save`와 `vox agent promote --yes`로 이어간다.

디버깅/개선:
1. `voice-ai-prompt-diagnosis.md` 읽기 → 실패 원인 진단
2. `voice-ai-prompt-revision.md` 읽기 → change_requests 기반 리팩터링
3. remote agent 수정이 필요하고 레포 맥락이면:
   ```bash
   vox agent pull <agent-id> --agent <local-name>
   # dashboard export JSON에서 시작하면:
   # vox agent import dashboard-export.json --agent <local-name>
   # prompt/variables/call/webhook 같은 agent.data 변경:
   # vox agent explain /agent/data/prompt/prompt --agent <local-name> --json
   # vox agent set --agent <local-name> --data prompt.prompt=@prompts/support.md
   # 그 외 specialized field는 agents/<local-name>/agent.json 직접 편집
   # runtime 실행이 아니라 test intent를 레포에 남기는 단계
   vox agent test init greeting_smoke --agent <local-name> --input "안녕하세요" --response-contains "안내"
   vox agent test list --agent <local-name> --json
   vox agent test show greeting_smoke --agent <local-name> --json
   vox agent test validate greeting_smoke --agent <local-name> --json
   vox doctor --json
   vox agent doctor --agent <local-name> --json
   vox agent validate --agent <local-name> --json
   vox agent diff --agent <local-name> --json
   vox agent push --agent <local-name>
   # 프로덕션 승격까지 요청받은 경우에만:
   vox agent version save --agent <local-name> --description "reviewed release"
   vox agent promote v1 --agent <local-name> --yes
   ```

## Prompt Composition (Default + Opt-in 모듈)

템플릿(`voice-ai-prompt-template.md`)은 공통 뼈대 + 조건부 모듈로 구성한다.

| 모듈 | 상태 | 주입 위치 | 소스 |
|------|------|----------|------|
| 턴테이킹 (인터럽션 복구 포함) | **Default** — 항상 포함 | `# 턴테이킹` 섹션의 `[[turn_taking_rules]]` | `voice-ai-playbook.md` § 턴테이킹 전체 |
| 표현력 (감정/속도/웃음) | **Opt-in** — 요청 시만 | 새 `# 표현력` 섹션의 `[[expressivity_rules]]` (템플릿에 주석 처리된 상태로 존재) | `voice-emotive-speech.md` |

**Opt-in 트리거 (표현력)** — 유저가 "자연스럽게", "감정 발화", "웃게", "톤", "속도 조절", "감정 enabled" 같은 표현을 쓰면 해당 모듈을 포함한다. 미언급 시 템플릿의 `# 표현력` 주석 블록을 **그대로 삭제**한다.

**Opt-in 전제 조건** — 표현력 모듈은 voice가 **Cartesia** 제공자일 때만 의미가 있다. 다른 제공자(ElevenLabs 등)면 포함하지 말고 사용자에게 voice 변경을 제안(`vox-web-app` 가이드)한 뒤 결정.

**기존 프롬프트 수정** — 이미 배포된 프롬프트에 opt-in 모듈을 **추가/제거**하라는 요청은 `voice-ai-prompt-revision.md`의 change_requests 흐름으로 처리한다.

## Ownership Boundary

| Owns | Does Not Own |
|------|--------------|
| prompt authoring / diagnosis / revision | flow design (→ vox-flow) |
| agent.data schema | tool management (→ vox-tools) |
| voice AI playbook rules (공통) | pricing / billing |
| IVR/DTMF best practice (공통) | phone number management |
| agent type 판단 + flow handoff | web app UI guide (→ vox-web-app) |

## Related Resources

### MCP Tools (vox)
- `create_agent` — 에이전트 생성 (prompt + agent.data)
- `update_agent` — 에이전트 수정 (prompt/llm/stt/voice/postCall/tools 등 개별 필드)
- `get_agent` — 에이전트 상세 조회 (현재 prompt, 설정 확인)
- `list_agents` — 에이전트 목록
- `get_call` — 통화 로그 조회 (진단 시 transcript 확인)
- `list_llm_models` — `llm.model` 허용 값 조회 (override 시)
- `list_voice_models` — `voice.id` / `voice.provider` / `voice.model` 허용 값 조회 (override 시)
- `get_schema(namespace='agent-schema', schema_type='agent-data-create')` — `create_agent.data` shape 확인
- `get_schema(namespace='agent-schema', schema_type='agent-data-update')` — `update_agent.data` shape 확인
- `get_schema(namespace='flow-schema', schema_type='flow-data')` — flow agent graph shape 확인 (필요 시 `vox-flow`로 handoff)

### CLI Commands (vox)
- `vox agent init` / `vox agent add` — 새 local agent source 생성
- `vox agent import <file> --agent <local-name>` — dashboard export/CLI source JSON을 committed local source로 변환
- `vox agent pull <agent-id>` — remote agent를 `agents/<name>/agent.json`으로 가져오기
- `vox agent set --data <path=value>` — committed `agent.data` 아래 prompt/변수/call/webhook 등 dashboard-style 설정을 dot-path로 수정 (`@file` prompt body 지원)
- `vox agent explain <json-pointer>` — committed agent source의 특정 JSON Pointer 값과 권장 편집 helper를 설명
- `vox agent test init` / `vox agent test list` / `vox agent test show` / `vox agent test validate` — runtime 실행 없이 `agents/<name>/tests/*.json` 테스트 의도와 assertion을 로컬 source로 관리하고 리뷰
- `vox doctor` — project 전체 source와 unreferenced tool/knowledge 파일까지 network 없이 authoring 위험 점검
- `vox agent doctor` — 특정 agent 중심 authoring 위험 점검
- `vox agent validate` — local + server-backed 검증
- `vox agent diff` / `vox agent status` — 리뷰 가능한 변경/드리프트 확인
- `vox agent push` — 검증된 source를 remote에 반영

### Docs (vox-docs search)
- `https://docs.tryvox.co/docs/build/overview` — 에이전트 빌드 개요
- `https://docs.tryvox.co/docs/build/single-prompt/prompt-writing` — 프롬프트 작성 가이드
- `https://docs.tryvox.co/docs/build/voice/voice-select` — 음성/LLM 선택
- `https://docs.tryvox.co/docs/build/knowledge/overview` — 지식 베이스
- `https://docs.tryvox.co/docs/build/variables/system-variables` — 시스템 변수
- `https://docs.tryvox.co/docs/build/variables/dynamic-variables` — 동적 변수

### App URLs
- `https://www.tryvox.co/dashboard/{organizationId}/agents` — 에이전트 목록
- `https://www.tryvox.co/agent/{agentId}` — 에이전트 상세/프롬프트 편집
