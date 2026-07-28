#!/usr/bin/env bash
# =============================================================
#  직원용 툴 모음 – GitHub Pages 원클릭 배포 스크립트
# -------------------------------------------------------------
#  사용법 (이 폴더 안에서 실행):
#     ./deploy.sh <저장소이름> [public|private]
#
#  예)  ./deploy.sh employee-tools            # 공개(기본)
#       ./deploy.sh employee-tools private    # 사내 비공개
#
#  필요조건: GitHub CLI(gh)가 설치·로그인돼 있어야 합니다.
#     설치: https://cli.github.com   로그인: gh auth login
# =============================================================
set -euo pipefail

REPO_NAME="${1:-employee-tools}"
VISIBILITY="${2:-public}"   # public | private

# --- 사전 점검 -------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI(gh)가 없습니다. https://cli.github.com 에서 설치 후 다시 실행하세요."
  echo "   (또는 README의 '방법 B. 손으로'를 따라 하세요.)"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "❌ gh 로그인이 안 돼 있습니다. 먼저 실행:  gh auth login"
  exit 1
fi
if [ "$VISIBILITY" != "public" ] && [ "$VISIBILITY" != "private" ]; then
  echo "❌ 두 번째 인자는 public 또는 private 여야 합니다."
  exit 1
fi

OWNER="$(gh api user --jq .login)"
echo "▶ 계정: $OWNER  /  저장소: $REPO_NAME  /  공개설정: $VISIBILITY"

# --- git 초기화(이미 돼 있으면 건너뜀) --------------------------
if [ ! -d .git ]; then
  git init -q
fi
git add -A
if git diff --cached --quiet 2>/dev/null && git rev-parse HEAD >/dev/null 2>&1; then
  echo "▶ 새로 커밋할 변경 없음 (기존 커밋 사용)"
else
  git commit -q -m "직원용 툴 모음 배포" || true
fi
git branch -M main

# --- 원격 저장소 생성 + 푸시 -----------------------------------
if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "▶ 저장소가 이미 있습니다. 원격 연결 후 푸시합니다."
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  git push -u origin main
else
  echo "▶ 저장소를 새로 만들고 푸시합니다."
  gh repo create "$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin --push
fi

# --- GitHub Pages 활성화 (main / root) -------------------------
echo "▶ GitHub Pages 활성화 중..."
gh api -X POST "repos/$OWNER/$REPO_NAME/pages" \
  -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$OWNER/$REPO_NAME/pages" \
       -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || echo "  (Pages 자동 설정 실패 – 저장소 Settings → Pages에서 main/(root)로 직접 지정해주세요.)"

URL="https://$OWNER.github.io/$REPO_NAME/"
echo ""
echo "✅ 완료! 1~2분 뒤 아래 주소가 열립니다:"
echo "   $URL"
echo ""
echo "   직원들에게 이 링크를 공유하세요."
