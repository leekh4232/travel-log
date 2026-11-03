#!/usr/bin/env bash
# adopted/(채택)·candidates/(후보) 아래 여행 폴더마다 slides.md 를 빌드해 dist/<폴더 이름>/ 에 두고, 루트에 두 묶음으로 나눈 여행 목록 index.html 을 만든다.
# 배포 주소에는 채택/후보를 넣지 않는다 → 후보를 채택으로 옮겨도 링크가 그대로 산다.
set -euo pipefail
cd "$(dirname "$0")"

OUT="$PWD/dist"  # slidev 는 --out 을 md 파일 기준으로 풀기 때문에 절대 경로로 준다
rm -rf "$OUT" && mkdir -p "$OUT"

urlenc() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }
htmlesc() { python3 -c 'import sys, html; print(html.escape(sys.argv[1]))' "$1"; }

# 묶음 폴더 하나를 빌드하고 카드 HTML 을 cards 변수에 담는다(slidev 로그가 섞이지 않게 $(...) 로 받지 않는다)
build_group() {
cards=""
for deck in "$1"/*/slides.md; do
  [[ -e "$deck" ]] || continue
  trip="${deck%/slides.md}"; trip="${trip#*/}"
  # 하위 경로로 배포하므로 --base 를 폴더 이름으로 준다(안 주면 자원 경로가 깨져 빈 화면)
  npx -y -p @slidev/cli -p @slidev/theme-default slidev build "$deck" --base "/$trip/" --out "$OUT/$trip"
  # slidev 는 lang="en" 으로 내보내 크롬이 번역을 자꾸 묻는다 → 한국어로 표시하고 번역 제안을 끈다
  sed -i 's|<html lang="en">|<html lang="ko" translate="no">|; s|<meta charset="utf-8">|&\n<meta name="google" content="notranslate">|' "$OUT/$trip/index.html"

  # 폴더 이름 "YYMMDD 여행 제목" → 날짜와 제목
  ymd="${trip%% *}"; name="${trip#* }"
  if [[ "$ymd" =~ ^[0-9]{6}$ ]]; then date="20${ymd:0:2}.${ymd:2:2}.${ymd:4:2}"; else date=""; name="$trip"; fi

  url="/$(urlenc "$trip")/"
  img=""
  cover=$(ls "$1/$trip"/cover.* 2>/dev/null | head -1 || true)
  if [[ -n "$cover" ]]; then
    cp "$cover" "$OUT/$trip/"
    img="<img src=\"${url}$(urlenc "$(basename "$cover")")\" alt=\"\" loading=\"lazy\">"
  fi
  card="<a class=\"card\" href=\"$url\" target=\"_blank\">$img<div class=\"meta\"><time>$date</time><h2>$(htmlesc "$name")</h2></div></a>"
  # 폴더 이름이 날짜로 시작하므로 앞에 붙여 최신 여행이 먼저 오게 한다
  cards="$card"$'\n'"$cards"
done
}

build_group adopted; adopted="$cards"
build_group candidates; candidates="$cards"

cat > "$OUT/index.html" <<EOF
<!DOCTYPE html>
<html lang="ko" translate="no">
<head>
<meta charset="utf-8">
<meta name="google" content="notranslate">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Travel Log</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable.min.css">
<style>
  * { box-sizing: border-box; }
  body { margin: 0; padding: 40px 20px 60px; background: #f4f2ee; color: #222; font-family: "Pretendard Variable", Pretendard, system-ui, sans-serif; }
  header { max-width: 1200px; margin: 0 auto 28px; }
  header h1 { margin: 0; font-size: 32px; letter-spacing: -0.02em; }
  /* 벽돌 배치: 카드를 열마다 번갈아 넣어(아래 스크립트) 왼쪽→오른쪽 최신순으로 읽히게 한다. 카드 높이는 표지 그림 비율을 따른다 */
  section { max-width: 1200px; margin: 0 auto 36px; }
  section h2.group { margin: 0 0 14px; font-size: 20px; letter-spacing: -0.01em; }
  section h2.group small { margin-left: 8px; font-size: 14px; font-weight: 500; color: #888; }
  .grid { display: flex; gap: 16px; align-items: flex-start; }
  .col { flex: 1; min-width: 0; }
  .card { position: relative; display: block; margin-bottom: 16px; border-radius: 14px; overflow: hidden; color: #fff; text-decoration: none; background: linear-gradient(135deg, #7c5cff, #ff3d9a); min-height: 180px; box-shadow: 0 2px 8px rgba(0,0,0,.08); transition: transform .2s, box-shadow .2s; }
  .card:hover { transform: translateY(-4px); box-shadow: 0 10px 24px rgba(0,0,0,.18); }
  .card img { display: block; width: 100%; height: auto; }
  .meta { position: absolute; inset: auto 0 0 0; padding: 48px 18px 16px; background: linear-gradient(transparent, rgba(0,0,0,.72)); }
  .meta time { font-size: 13px; opacity: .85; letter-spacing: .04em; }
  .meta h2 { margin: 4px 0 0; font-size: 20px; line-height: 1.3; }
</style>
</head>
<body>
<header><h1>Travel Log</h1></header>
<main>
<section><h2 class="group">채택된 계획<small>확정해서 갈 여행</small></h2><div class="grid">
$adopted</div></section>
<section><h2 class="group">후보 계획<small>아직 고르는 중</small></h2><div class="grid">
$candidates</div></section>
</main>
<script>
  // 묶음(채택·후보)마다 따로 벽돌 배치한다
  document.querySelectorAll('.grid').forEach(function (grid) {
    var cards = Array.prototype.slice.call(grid.children), cur = 0;
    function layout() {
      var n = Math.max(1, Math.min(4, Math.floor((grid.clientWidth + 16) / 276)));
      if (n === cur) return;
      cur = n; grid.innerHTML = '';
      var cols = [];
      for (var i = 0; i < n; i++) { cols.push(grid.appendChild(document.createElement('div'))); cols[i].className = 'col'; }
      cards.forEach(function (c, i) { cols[i % n].appendChild(c); });
    }
    layout(); addEventListener('resize', layout);
  });

  // 카드를 누르면 슬라이드를 팝업 창으로 연다. 팝업이 막히면 링크의 target=_blank 로 새 탭에서 열린다
  document.querySelectorAll('.card').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var w = Math.min(1280, screen.availWidth), h = Math.min(760, screen.availHeight);
      var left = (screen.availWidth - w) / 2, top = (screen.availHeight - h) / 2;
      var win = window.open(a.href, '_blank', 'popup,width=' + w + ',height=' + h + ',left=' + left + ',top=' + top);
      if (win) e.preventDefault();
    });
  });
</script>
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
