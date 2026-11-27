#!/usr/bin/env bash
# SessionStart: PROGRESS.md와 git 요약을 컨텍스트에 넣는다.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
echo "=== PROGRESS.md (작업 진행판 — 이어서 작업하기 전에 확인) ==="
if [ -f PROGRESS.md ]; then cat PROGRESS.md; else echo "(PROGRESS.md 없음 — 새로 만들 것)"; fi
echo
echo "=== git ==="
echo "브랜치: $(git branch --show-current 2>/dev/null)  |  커밋 안 된 변경: $(git status --porcelain 2>/dev/null | wc -l)개"
git log --oneline -3 2>/dev/null
exit 0
