# vox-mcp-public-tools.json

vox MCP가 외부에 노출하는 public tool 이름의 스냅샷. `scripts/check-skill-mcp-conformance.sh`가
이 manifest를 기준으로 skills/ 안의 도구 참조가 실제 존재하는 도구인지 검사한다(phantom tool 가드).

소스: vox-mcp 서버의 `PUBLIC_TOOL_NAMES` 상수. 이 파일은 그 값을 vendoring한 사본이라,
MCP에서 도구를 추가/삭제하면 여기도 같이 갱신해야 한다.

## 갱신 방법

vox-mcp의 `PUBLIC_TOOL_NAMES`가 바뀌면 그 배열을 이 파일에 그대로 옮긴다(JSON 문자열 배열, 정렬 무관).
바꾼 뒤 `bash scripts/check-skill-mcp-conformance.sh`로 검증한다.
