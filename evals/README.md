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

결과는 레포에 커밋하지 않는다. 기준선 측정값은 해당 PR 본문에 남긴다. description을 바꾸는 PR은 바꾼 스킬과 형제 스킬을 다시 측정한다.

functional eval(산출물 채점)은 아직 없다. 넣을 때는 "MCP를 호출하지 말고 보낼 JSON을 파일로 써라"로 고정해 프로덕션에 닿지 않게 한다.
