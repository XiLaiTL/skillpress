#!/usr/bin/env bash
# acceptance.sh —— **目标的验收判据**（PLAN §6 的 A1/A2/A3）落到一条命令上。
#
#   SKILLPRESS_CORPUS=<内容仓>/skills bash tools/acceptance.sh
#   SKILLPRESS_CORPUS=... bash tools/acceptance.sh --build   # 顺带把实例重建一遍（慢）
#
# 为什么要有它：目标原话是"每条判据都要能被命令证明"。散着跑容易自欺（"我记得验过了"），
# 而一条命令的读数**现在就可以是红的** —— 红在哪，就是还差什么。
#
# ⚠️ **读数只在"本模块没人在改"的时候可信**：A1 那几条跑的是 `moon package` / 消费者 `moon check`
#    （都要编译本模块）。如果有别的进程/子代理正在改这里，你会看到"20 个错误"这种**别人的半成品**
#    读数 —— 实测踩过。要读数就先确认工作区是你要的那一版（`git status` 干净，或明确知道在改什么）。
set -u
cd "$(dirname "$0")/.."

: "${SKILLPRESS_CORPUS:?用 SKILLPRESS_CORPUS=<内容根> 指定内容仓（例：../moobile/skills）}"
INSTANCE="${SKILLPRESS_INSTANCE:-$SKILLPRESS_CORPUS/skillpress/scripts/.skillpress}"
GENERATED="$INSTANCE/content/content.generated.mbt"
DO_BUILD="${1:-}"

pass=0
fail=0
ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

# ── A1：包存在、装得上 ───────────────────────────────────────────────────────
echo "A1 包存在、装得上"
LIST=$(mktemp)
if timeout 300 moon package --list > "$LIST" 2>&1; then
  for need in "moon.mod" "engine/highlight/" "engine/content/" "skills/skillpress-user/SKILL.md"; do
    if grep -q -- "$need" "$LIST"; then ok "包里含 $need"; else bad "包里**缺** $need"; fi
  done
  # shell 包是 A2 的前提，现在应该还没有 ⇒ 红在这里是"还没做到"，不是"坏了"
  if grep -q "^shell/" "$LIST"; then ok "包里含 shell/（界面已抽包）"; else bad "包里缺 shell/（界面还没抽成包 —— 见 PLAN 的 P6）"; fi
  zip=$(grep -oE "Package to .*\.zip" "$LIST" | tail -1 | sed 's/Package to //')
  if [ -n "$zip" ] && [ -f "$zip" ]; then ok "打出了 zip：$(basename "$zip" | tr -d '\r')"; else bad "没打出 zip"; fi
else
  bad "moon package --list 跑失败"; tail -5 "$LIST" | sed 's/^/      /'
fi
rm -f "$LIST"

# A1b：别的工程能不能**本地**装上（注册表那条要发布，见下）
# ⚠️ 工作区成员路径必须是 **Windows 形式**：Git Bash 的 `pwd` 给 `/d/ai_project/...`，
#    moon 会报「系统找不到指定的路径」（实测踩过）；`pwd -W` 才是 `D:/...`。
HERE_WIN=$(pwd -W 2>/dev/null || pwd)
W=$(mktemp -d)
mkdir -p "$W/use"
cat > "$W/moon.work" <<EOF
members = [
  ".",
  "$HERE_WIN",
]
EOF
cat > "$W/moon.mod" <<'EOF'
name = "XiLaiTL/acceptance-consumer"
version = "0.1.0"
license = "Apache-2.0"
preferred_target = "js"

import {
  "XiLaiTL/skillpress@0.1.0",
}
EOF
cat > "$W/moon.pkg" <<'EOF'
import {
  "XiLaiTL/skillpress/engine/highlight" @hl,
}

supported_targets = "+js"
EOF
cat > "$W/use.mbt" <<'EOF'
///|
/// 消费者探针：只调一个纯函数，证明"依赖解析 + 编译"成立。
pub fn color_of_keyword() -> Int {
  let (idx, _) = @hl.palette_of("keyword")
  idx
}
EOF
if (cd "$W" && timeout 300 moon check --target js > "$W/log" 2>&1); then
  ok "别的工程声明依赖后能编过（**本地工作区**形态）"
else
  bad "消费者编不过"; tail -5 "$W/log" | sed 's/^/      /'
fi
rm -rf "$W"
echo "  ·  ⚠️ 注册表那条（`moon add` 装已发布的版本）**必须真发布**才能证 —— 发布要凭据"

# ── A2：站点直接依赖包，而不是抄界面 ─────────────────────────────────────────
echo "A2 站点直接依赖包（而不是抄界面）"
if [ -f "$INSTANCE/app.mbt" ]; then
  n=$(wc -l < "$INSTANCE/app.mbt" | tr -d ' ')
  if [ "$n" -le 20 ]; then ok "实例 app.mbt 只有 $n 行（≤20）"; else bad "实例 app.mbt 还有 $n 行（要 ≤20：界面得搬进包的 shell/）"; fi
else
  bad "找不到实例 app.mbt：$INSTANCE/app.mbt"
fi
if grep -q "XiLaiTL/skillpress" "$INSTANCE/moon.mod" 2>/dev/null; then
  ok "实例 moon.mod 里直接依赖 XiLaiTL/skillpress"
else
  bad "实例 moon.mod 里没有依赖 XiLaiTL/skillpress"
fi
if [ -d "$INSTANCE/shell" ]; then bad "实例里还有一份 shell/（界面副本必须不存在）"; else ok "实例里没有界面副本（没有 shell/ 目录）"; fi

# ── A3：自家的 skills 真能印成一个站点 ──────────────────────────────────────
echo "A3 自家的 skills 能印成站点"
if node bin/skillpress.mjs press --check > /tmp/acc-press.log 2>&1; then ok "press --check 一致"; else bad "press --check 不一致"; tail -3 /tmp/acc-press.log | sed 's/^/      /'; fi
if node bin/skillpress.mjs check > /tmp/acc-check.log 2>&1; then ok "check 全绿（$(tail -1 /tmp/acc-check.log | tr -d '\r')）"; else bad "check 红了"; tail -3 /tmp/acc-check.log | sed 's/^/      /'; fi
if [ "$DO_BUILD" = "--build" ]; then
  if (cd "$INSTANCE" && timeout 900 npm run build > /tmp/acc-build.log 2>&1); then ok "实例 build 通过"; else bad "实例 build 失败"; tail -5 /tmp/acc-build.log | sed 's/^/      /'; fi
else
  echo "  ·  实例 build 没跑（加 --build 跑，慢）"
fi
if [ -f "$INSTANCE/dist/bundle.js" ]; then
  if node bin/skillpress.mjs verify > /tmp/acc-verify.log 2>&1; then
    ok "verify 判据全过（$(grep -oE '全部通过（[0-9]+ 条）' /tmp/acc-verify.log | tail -1)）"
  else
    bad "verify 有红的"; tail -3 /tmp/acc-verify.log | sed 's/^/      /'
  fi
else
  bad "实例还没 build 过（没有 dist/bundle.js）⇒ verify 跑不了"
fi

echo
echo "—— 验收：$pass 条过 ／ $fail 条没到 ——"
[ "$fail" -eq 0 ] || echo "（红的就是还差什么；PLAN §6 有每一条的说明）"
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
