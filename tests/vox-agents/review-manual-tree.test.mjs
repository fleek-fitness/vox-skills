import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { reviewManualTree } from "../../skills/vox-agents/scripts/review-manual-tree.mjs";

function makeWorkspace() {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "vox-manual-review-"));
  fs.mkdirSync(path.join(workspace, "agents", "demo"), { recursive: true });
  fs.mkdirSync(path.join(workspace, "manuals"), { recursive: true });
  fs.mkdirSync(path.join(workspace, ".vox"), { recursive: true });
  fs.writeFileSync(path.join(workspace, ".vox", "project.json"), JSON.stringify({ manual_bindings: {}, tool_bindings: {} }));
  return workspace;
}

function writeAgent(workspace, refs) {
  fs.writeFileSync(
    path.join(workspace, "agents", "demo", "agent.json"),
    JSON.stringify({ agent: { name: "demo", type: "single_prompt", data: { manualRefs: refs } } }),
  );
}

function writeManual(workspace, localName, { content, trigger, sound = "typing", builtInTools = [] }) {
  const dir = path.join(workspace, "manuals", localName);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    path.join(dir, "manual.json"),
    JSON.stringify({
      manual: {
        name: localName,
        trigger: trigger ?? "에이전트가 정보를 물어봐야 할 때, 고객이 정보를 먼저 말하기 시작했을 때, 또는 기존 값을 확인·정정할 때",
        content,
        built_in_tools: builtInTools,
        config: { tool_call_sound: sound },
      },
    }),
  );
}

const validContent = `## 규칙

- 확인된 사실만 사용한다.

## 진행 절차

### 시작

1. 고객이 정보를 말했으면 '확인'으로 이동한다.

### 확인

1. 고객이 동의하면 '완료'로 이동한다.

### 완료

1. 말씀하신 내용을 확인했다고 안내한다.
2. Manual 시작 전에 진행하던 원래 요청을 이어서 처리한다.
`;

test("reviews direct and linked Manuals recursively", () => {
  const workspace = makeWorkspace();
  writeAgent(workspace, ["root"]);
  writeManual(workspace, "root", {
    content: validContent.replace("### 완료", "### linked\n\n1. @manual:child 절차로 이동한다.\n\n### 완료"),
  });
  writeManual(workspace, "child", { content: validContent });

  const result = reviewManualTree({ workspace, agent: "demo" });
  assert.equal(result.summary.direct_manual_count, 1);
  assert.equal(result.summary.linked_manual_count, 1);
  assert.equal(result.summary.total_manual_count, 2);
  assert.equal(result.summary.critical, 0);
});

test("reports a linked Manual that was not pulled", () => {
  const workspace = makeWorkspace();
  writeAgent(workspace, ["root"]);
  writeManual(workspace, "root", { content: `${validContent}\n@manual:missing` });

  const result = reviewManualTree({ workspace, agent: "demo" });
  assert.equal(result.valid, false);
  assert.ok(result.findings.some((finding) => finding.code === "LINKED_MANUAL_NOT_PULLED"));
});

test("detects a linked Manual cycle", () => {
  const workspace = makeWorkspace();
  writeAgent(workspace, ["a"]);
  writeManual(workspace, "a", { content: `${validContent}\n@manual:b` });
  writeManual(workspace, "b", { content: `${validContent}\n@manual:a` });

  const result = reviewManualTree({ workspace, agent: "demo" });
  assert.equal(result.valid, false);
  assert.ok(result.findings.some((finding) => finding.code === "MANUAL_CYCLE"));
});

test("reports structure, sound, raw state, and unsupported Side-effect claims", () => {
  const workspace = makeWorkspace();
  writeAgent(workspace, ["bad"]);
  writeManual(workspace, "bad", {
    sound: "none",
    content: `## 규칙

- result=accepted로 기록한다.
- recommended_action이 single_confirm_top_candidate이면 이동한다.

## 진행 절차

### 시작

1. 예약을 접수하겠습니다.
`,
  });

  const result = reviewManualTree({ workspace, agent: "demo" });
  const codes = new Set(result.findings.map((finding) => finding.code));
  assert.ok(codes.has("MANUAL_COMPLETE_SECTION_MISSING"));
  assert.ok(codes.has("MANUAL_TYPING_SOUND_MISSING"));
  assert.ok(codes.has("CODE_STATE_ASSIGNMENT"));
  assert.ok(codes.has("RAW_TOOL_STATE_TOKEN"));
  assert.ok(codes.has("SIDE_EFFECT_WITHOUT_TOOL"));
});

test("accepts a Manual-owned built-in Tool reference", () => {
  const workspace = makeWorkspace();
  writeAgent(workspace, ["address"]);
  writeManual(workspace, "address", {
    content: `${validContent}\n@tool:search_address`,
    builtInTools: [{ toolType: "search_address", name: "search_address" }],
  });

  const result = reviewManualTree({ workspace, agent: "demo" });
  assert.ok(!result.findings.some((finding) => finding.code === "MANUAL_TOOL_UNRESOLVED"));
});
