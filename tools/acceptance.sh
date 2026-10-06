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

# ── 证伪：判据**自己**也要被证明会红、也会绿 ──────────────────────────────────
# A2 那三条要在"合规实例"上全绿、在"不合规实例"上全红 —— 不然它可能是一条**永远红**（或永远绿）的判据。
# 只对 A2 做：A1 要编译本模块（读数受"有没有人在改"影响），A3 要真站点，都不适合造假的对照。
if [ "${1:-}" = "--selftest" ]; then
  W=./_build/accept-selftest
  rm -rf "$W"; mkdir -p "$W/good" "$W/bad/shell"
  printf 'pub fn app() {\n  @skillpress.shell.site()\n}\n' > "$W/good/app.mbt"
  printf 'name = "x"\n\nimport {\n  "XiLaiTL/skillpress@0.1.0",\n}\n' > "$W/good/moon.mod"
  for _ in $(seq 1 100); do echo "// 界面代码" >> "$W/bad/app.mbt"; done
  printf 'name = "x"\n' > "$W/bad/moon.mod"
  a2() { SKILLPRESS_INSTANCE="$(pwd -W)/_build/accept-selftest/$1" bash "$0" 2>&1 | sed -n '/^A2/,/^A3/p' | grep -c '✓'; }
  good=$(a2 good)
  bad=$(a2 bad)
  rm -rf "$W"
  if [ "$good" = 3 ] && [ "$bad" = 0 ]; then
    echo "✓ 证伪通过：合规实例 A2 全绿（$good/3），不合规实例 A2 全红（$bad/3）"
    exit 0
  fi
  echo "✗ 证伪失败：合规=$good/3（应为 3）｜不合规=$bad/3（应为 0）—— A2 那几条有问题"
  exit 1
fi
GENERATED="$INSTANCE/content/content.generated.mbt"
DO_BUILD="${1:-}"

pass=0
fail=0
ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1"; fail=$((fail + 1)); }

# ── A1：包存在、装得上 ───────────────────────────────────────────────────────
echo "A1 包存在、装得上"
LIST=$(mktemp)
LIST_RAW=$(mktemp)
# ⚠️ Windows 上 `moon package --list` 打的是**反斜杠**（`engine\content\blocks.mbt`），
#    而下面的清单按**正斜杠**写 ⇒ 不做这一步，A1 会报四条**假红**（"包里缺 engine/content/"），
#    而包里其实有（实测：`moon package --list | sed 's#\\#/#g'` 一条不少）。
#    假红和假绿一样有害 —— 它会训练人忽略这条判据。所以只归一化**取值的形式**，不动判据的意图。
if timeout 300 moon package --list > "$LIST_RAW" 2>&1; then
  sed 's#\\#/#g' "$LIST_RAW" > "$LIST"
  # ⚠️ `engine/gates/` 必须在清单里：目标 ② 的原话是"**引擎（内容管线 + 通用门）**与站点界面（shell）
  #    都在这个包里"。原先这条判据只查了 highlight/content/shell —— 通用门**不在证据里**（
  #    `tools/package-check.sh` 那边查得到，但验收自己不该留这个洞）。
  for need in "moon.mod" "engine/highlight/" "engine/content/" "engine/gates/" "skills/skillpress-user/SKILL.md"; do
    if grep -q -- "$need" "$LIST"; then ok "包里含 $need"; else bad "包里**缺** $need"; fi
  done
  # shell 包是 A2 的前提（P6 已抽完，这条现在应当是绿的）
  if grep -q "^shell/" "$LIST"; then ok "包里含 shell/（界面已抽包）"; else bad "包里缺 shell/（界面没抽成包）"; fi
  zip=$(grep -oE "Package to .*\.zip" "$LIST" | tail -1 | sed 's/Package to //')
  if [ -n "$zip" ] && [ -f "$zip" ]; then ok "打出了 zip：$(basename "$zip" | tr -d '\r')"; else bad "没打出 zip"; fi
else
  bad "moon package --list 跑失败"; tail -5 "$LIST_RAW" | sed 's/^/      /'
fi
rm -f "$LIST" "$LIST_RAW"

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
echo "  ·  ⚠️ 注册表那条（\`moon add\` 装已发布的版本）**必须真发布**才能证 —— 发布要凭据"

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
# ① 真相还在：**旧引擎**（lib/gen-content.mjs）仍然能从当前内容源印出 `tools/baseline/` 里那份。
#    这一条同时是"基线不是手抄的、也不是新引擎覆盖过的"的**现场**证据（形状判据只是旁证）。
if SKILLPRESS_APP_DIR="$(pwd -W)/tools/baseline" node bin/skillpress.mjs press --check > /tmp/acc-press.log 2>&1; then
  ok "旧引擎对基线：press --check 一致（真相仍是 lib/gen-content.mjs 印的那份）"
else
  bad "旧引擎与基线不一致（有意改了内容源？按 tools/baseline/README.md 刷基线）"; tail -3 /tmp/acc-press.log | sed 's/^/      /'
fi
# ② 新引擎（包里的 `cmd/skillpress`）印出来的那份与基线**归一化后逐字节一致**，
#    并且**实例里那份就是新引擎现跑的产物** —— 这是 P6 起 `press --check` 对应的口径
#    （形状搬进包了，所以先归一化；见 tools/normalize-gen.mjs 的文件头）。
if bash tools/file-parity.sh > /tmp/acc-fileparity.log 2>&1; then
  ok "整份文件对账通过（基线 + 实例两份都绿）"
else
  bad "整份文件对账红了"; grep '^✗' /tmp/acc-fileparity.log | head -3 | sed 's/^/      /'
fi
if node bin/skillpress.mjs check > /tmp/acc-check.log 2>&1; then ok "check 全绿（$(tail -1 /tmp/acc-check.log | tr -d '\r')）"; else bad "check 红了"; tail -3 /tmp/acc-check.log | sed 's/^/      /'; fi
if [ "$DO_BUILD" = "--build" ]; then
  if (cd "$INSTANCE" && timeout 900 npm run build > /tmp/acc-build.log 2>&1); then ok "实例 build 通过"; else bad "实例 build 失败"; tail -5 /tmp/acc-build.log | sed 's/^/      /'; fi
else
  echo "  ·  实例 build 没跑（加 --build 跑，慢）"
fi
# ⚠️ **新鲜度**：`dist/bundle.js` 必须**比源新**，否则 verify 是在**悄悄测旧代码** ——
#    表现是"两次跑出来一模一样"，最容易骗过自己（moobile 的 AGENTS.md 里记着同款事故）。
#    ⚠️ 界面现在住在**程序仓**的 `shell/` 里 ⇒ 它也必须算进"源"里：只比实例自己的文件，
#    会漏掉"改了 shell 却没重建"这一整类。
if [ -f "$INSTANCE/dist/bundle.js" ]; then
  stale=$(find "$INSTANCE/app.mbt" "$INSTANCE/content" "$(pwd)/shell" -newer "$INSTANCE/dist/bundle.js" 2>/dev/null | head -3)
  if [ -n "$stale" ]; then
    bad "dist/bundle.js 比源还旧 ⇒ verify 会测**旧代码**（先 cd 实例 && npm run build）："
    printf '%s\n' "$stale" | sed 's/^/      /'
  elif node bin/skillpress.mjs verify > /tmp/acc-verify.log 2>&1; then
    ok "verify 判据全过（$(grep -oE '全部通过（[0-9]+ 条）' /tmp/acc-verify.log | tail -1)）"
  elif grep -q '等不到：Chrome 的调试端口' /tmp/acc-verify.log; then
    # ⚠️ **真浏览器判据天生会抖**（实测：同一份代码，一次"等不到 Chrome 的调试端口"、紧接着单独重跑
    #    22/22 全过）。这种"基础设施没起来"的红必须处理 —— 但**不许无声重试**（那会把判据变成摆设，
    #    也会训练人忽略它）。所以三条同时成立才重试：① 只认**这一种**错误（断言失败一律不重试）；
    #    ② 重试**打出来**给人看；③ **断言一条都不放宽**（重试后仍要 22 条全过）。
    echo "      ·  Chrome 调试端口第一次没起来（环境抖动，不是断言失败）⇒ 明着重试一次"
    if node bin/skillpress.mjs verify > /tmp/acc-verify.log 2>&1; then
      ok "verify 判据全过（重试一次后：$(grep -oE '全部通过（[0-9]+ 条）' /tmp/acc-verify.log | tail -1)）"
    else
      bad "verify 重试后仍有红的（两次红 ≈ 真问题）"; tail -3 /tmp/acc-verify.log | sed 's/^/      /'
    fi
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
