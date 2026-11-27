#!/usr/bin/env bash
# Stop: PROGRESS.md보다 최근에 바뀐 파일이 있으면 한 번만 갱신을 요청한다.
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
[ -f PROGRESS.md ] || exit 0

stamp=.claude/.progress-checked
ref=PROGRESS.md
[ -f "$stamp" ] && [ "$stamp" -nt PROGRESS.md ] && ref="$stamp"

changed=$(find . \( -path ./.git -o -path ./.dart_tool -o -path ./.idea -o -path '*/build' \
  -o -path '*/.dart_tool' -o -path '*/.gradle' -o -path ./.claude/.progress-checked \) -prune \
  -o -type f -newer "$ref" ! -name PROGRESS.md -print 2>/dev/null | head -5)
[ -z "$changed" ] && exit 0

touch "$stamp"   # 같은 변경으로 다시 묻지 않기
list=$(printf '%s' "$changed" | sed 's|^\./||' | paste -sd ',' - | sed 's/,/, /g')
reason="PROGRESS.md 갱신 확인: 마지막 갱신 뒤로 파일이 바뀌었다 (예: $list). 의미 있는 진행이면 PROGRESS.md의 현재 상태·진행 중·다음 할 일·세션 로그를 갱신하고, 사소한 변경이면 그대로 마쳐도 된다."
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
