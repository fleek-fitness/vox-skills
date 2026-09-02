# evals

스킬이 맞는 요청에 켜지고, 형제 스킬의 요청에는 켜지지 않는지 재는 trigger eval 세트다. 스킬당 20문항이고 절반은 형제 스킬 near-miss(예: condition 노드 질문은 `vox-flow`에서 발동, `vox-agents`에서는 비발동)이다. 라우터 `using-vox-skills`의 negative만 vox.ai 밖 요청이다.

## 형식

`evals/<skill>/trigger_eval.json`

```json
[
  {"query": "사용자 요청 원문", "should_trigger": true},
  {"query": "형제 스킬 요청", "should_trigger": false}
]
```

## 실행

Anthropic skill-creator의 `scripts/run_eval.py`(`claude -p` 기반, 문항당 3회 실행, 발동률 0.5 이상이면 발동)를 쓴다. 같은 `{query, should_trigger}` 배열을 읽는 러너면 무엇이든 된다.

```bash
cd <skill-creator 디렉터리>
python -m scripts.run_eval \
  --eval-set <vox-skills>/evals/vox-flow/trigger_eval.json \
  --skill-path <vox-skills>/skills/vox-flow \
  --runs-per-query 3 --verbose
```

러너를 쓸 때 주의할 것:

- `--num-workers 1`로 돌린다. 워커가 여럿이면 같은 description의 사본이 `.claude/commands/`에 동시에 보여 각 사본의 발동률이 1/N로 떨어진다. 병렬화가 필요하면 스킬별로 프로젝트 디렉터리를 따로 만든다.
- Claude Code 세션 안에서 돌리면 자식 `claude -p`가 `CLAUDE_CODE_SESSION_ID`를 물려받아 부모 대화를 이어간다. `CLAUDE*` 환경변수를 지운 셸에서 돌린다.
- 사용자 스킬·MCP가 섞이지 않게 빈 디렉터리에서 `--setting-sources project --strict-mcp-config`를 붙인다. 러너가 인자를 넘기지 않으므로 PATH 앞에 `claude` shim을 둔다.
- 스킬을 하나씩 재므로 형제 near-miss는 실제보다 높게 오발동한다. 6개를 함께 스테이징하면 `using-vox-skills`가 먼저 잡는다.

결과는 레포에 커밋하지 않는다. 기준선 측정값은 해당 PR 본문에 남긴다. description을 바꾸는 PR은 바꾼 스킬과 형제 스킬을 다시 측정한다.

functional eval(산출물 채점)은 아직 없다. 넣을 때는 "MCP를 호출하지 말고 보낼 JSON을 파일로 써라"로 고정해 프로덕션에 닿지 않게 한다.
