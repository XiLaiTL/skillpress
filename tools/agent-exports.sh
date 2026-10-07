#!/usr/bin/env bash
# agent-exports.sh —— **Agent 出口的判据**：`llms.txt` + 每页原文（`md/**`）。
#
#   bash tools/agent-exports.sh
#
# 为什么要有它（"新产物 = 新判据"）：这两件是**人机共读**那条线的出口，坏法全是安静的：
#   · 内容改了、`llms.txt` 没重跑 ⇒ Agent 拿到一份过期的索引（看着完全正常）；
#   · 产物生成在实例根、**没拷进 `dist/`** ⇒ 浏览器永远拿不到（"做完了"与"拿得到"是两件事）；
#   · 索引里漏了一份 skill ⇒ Agent 少读一份，没人会报错。
# 所以这里逐条钉死：**同源**（索引与内容包对得上）、**数量**（原文份数 = 索引里点名的份数）、
# **可达**（真的用静态服务取一次，拿 200）。
set -u
cd "$(dirname "$0")/.."
APP="${SKILLPRESS_APP:-skills/skillpress/scripts/.skillpress}"
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

echo "① 生成物与内容源一致（\`press --check\` 覆盖三件产物）"
if node tools/press.mjs --check --app "$APP" > /tmp/agent-exports.log 2>&1; then
  ok "$(grep -c '✓ 一致' /tmp/agent-exports.log) 处一致（内容包 / llms.txt / md 原文）"
else
  bad "press --check 有红的"; tail -3 /tmp/agent-exports.log | sed 's/^/      /'
fi

echo "② 同源：内容包里每个中文 title 都在索引里"
MBT="$APP/content/content.generated.mbt"
LLMS="$APP/llms.txt"
[ -f "$LLMS" ] || { bad "没有 $LLMS（先跑 press）"; echo; echo "agent-exports：$fail 条不过"; exit 1; }
miss=0
while IFS= read -r t; do
  grep -qF -- "$t" "$LLMS" || grep -qF -- "$(printf %s "$t" | tr -d '\\')" "$LLMS" || { bad "索引里漏了 title：$t"; miss=1; }
done < <(sed -n 's/^ *title: "\(.*\)",$/\1/p' "$MBT" | tr -d '\\')
[ "$miss" = 0 ] && ok "内容包里的 title 一条不漏"

echo "③ 数量：原文产物份数 = 索引里点名的份数"
want=$(grep -cE '(原文: |：)skills/' "$LLMS")
have=$(find "$APP/md" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$want" = "$have" ] && ok "索引点名 $want 份，产物里有 $have 份" || bad "索引点名 $want 份，产物里 $have 份（对不上）"

echo "④ 可达：静态服务真的取得回来（拿 200 才算数）"
if [ -d "$APP/dist" ]; then
  if node tools/agent-http.mjs --app "$APP" > /tmp/agent-http.log 2>&1; then
    ok "$(grep -c '✓' /tmp/agent-http.log) 个地址 200（/llms.txt + 两份原文）"
  else
    bad "有地址取不回来"; sed -n '1,4p' /tmp/agent-http.log | sed 's/^/      /'
  fi
else
  echo "  · 跳过：还没有 dist/（先 \`npm run build\`）"
fi

echo
[ "$fail" = 0 ] && echo "agent-exports：全部通过" || echo "agent-exports：$fail 组不过"
exit $fail
