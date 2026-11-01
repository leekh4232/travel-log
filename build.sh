#!/usr/bin/env bash
# 여행 폴더마다 slides.md 를 빌드해 dist/<폴더 이름>/ 에 두고, 루트에 여행 목록 index.html 을 만든다.
set -euo pipefail
cd "$(dirname "$0")"

OUT="$PWD/dist"  # slidev 는 --out 을 md 파일 기준으로 풀기 때문에 절대 경로로 준다
rm -rf "$OUT" && mkdir -p "$OUT"

urlenc() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
htmlesc() { python3 -c 'import sys, html; print(html.escape(sys.argv[1]))' "$1"; }

items=""
for deck in */slides.md; do
  trip="${deck%/slides.md}"
  # 하위 경로로 배포하므로 --base 를 폴더 이름으로 준다(안 주면 자원 경로가 깨져 빈 화면)
  npx -y -p @slidev/cli -p @slidev/theme-default slidev build "$deck" --base "/$trip/" --out "$OUT/$trip"
  title=$(sed -n '2,20{s/^title:[[:space:]]*//p;}' "$deck" | head -1)
  items="$items<li><a href=\"/$(urlenc "$trip")/\"><b>$(htmlesc "$trip")</b><span>$(htmlesc "${title:-}")</span></a></li>"$'\n'
done

cat > "$OUT/index.html" <<EOF
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Travel Log</title>
<style>
  body { font-family: "Pretendard Variable", Pretendard, system-ui, sans-serif; max-width: 720px; margin: 48px auto; padding: 0 20px; color: #222; }
  h1 { font-size: 28px; }
  ul { list-style: none; padding: 0; }
  li a { display: block; padding: 14px 16px; margin-bottom: 10px; border: 1px solid #ddd; border-top: 4px solid #7c5cff; color: inherit; text-decoration: none; }
  li a:hover { background: #f6f4ff; }
  li span { display: block; margin-top: 4px; color: #666; font-size: 14px; }
</style>
</head>
<body>
<h1>Travel Log</h1>
<ul>
$items</ul>
</body>
</html>
EOF

# GitHub Pages 는 루트의 404.html 만 쓴다 → 슬라이드 쪽 주소(/여행/3)로 새로고침하면 그 여행 첫 쪽으로 보낸다
cat > "$OUT/404.html" <<'EOF'
<!DOCTYPE html>
<meta charset="utf-8">
<script>
  var seg = location.pathname.split('/')[1];
  location.replace(seg ? '/' + seg + '/' : '/');
</script>
EOF

echo travel-log.hossam.kr > "$OUT/CNAME"
touch "$OUT/.nojekyll"
