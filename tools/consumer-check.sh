#!/usr/bin/env bash
# consumer-check.sh —— **消费者视角**：从 `moon package` 打出来的 **zip** 出发，走一遍"拿到包的人"要做的三步
# （解压成项目里的包 / 装那唯一的 npm 依赖 / 编一次 CLI），然后用**包里的启动器**跑 `check` 与 `gen-file`。
#
#   bash tools/consumer-check.sh          # 不需要 SKILLPRESS_CORPUS：它自带夹具
#
# ── 为什么必须有它（R6 的尾巴 + 发布清单第 7 条的预演）────────────────────────────
# "本地工作区形态能跑"**不构成证据**：工作区里有 `tools/`、有 `node_modules`、有 `_build`，
# 而包里一样都没有（`.moonignore` 钉着）。这个仓库里"发布包 ≠ 工作区"是有前科的。
# 所以这里只用 **zip 里的东西 + 使用者自己装的那一个 npm 依赖**，而且：
#
#   · 先证明 **`check` 在没有那个 npm 依赖时也能跑**（门与高亮没有任何依赖关系）；
#   · 再装上依赖，证明 `gen-file` 的产物与**本地引擎**在同一份夹具上**逐字节一致**；
#   · 两个反证：夹具里放个死路径 ⇒ `check` 必须红；放个认不出的构造 ⇒ `gen-file` 必须退 2 且不吐产物。
#
# ⚠️ **前置断言**：`node -e 'import("web-tree-sitter")'` 在消费者目录里必须**解析不到**，
#    否则这次"没装依赖"的读数就是假的（实测踩过：用户主目录里有一个误装的 `node_modules`，
#    临时目录向上解析就命中了它 ⇒ 那一轮读数全不作数）。所以先自己证明前提，再往下跑。
set -u
cd "$(dirname "$0")/.."
PROG=$(pwd -W)

fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; fail=1; }

# 消费者目录放**仓库的隔壁**（不是 $TMPDIR）：$TMPDIR 在用户主目录下，而上层可能正好有个
# 误装的 node_modules（本机就有一个）⇒ 前置断言会失败。隔壁那棵树沿途干净。
BASE="$(dirname "$PROG")/.skillpress-consumer-check-$$"
rm -rf "$BASE"
mkdir -p "$BASE/proj/.mooncakes/XiLaiTL/skillpress"
cleanup() { rm -rf "$BASE"; }
trap cleanup EXIT

PKG="$BASE/proj/.mooncakes/XiLaiTL/skillpress"

echo "① 打 zip 并解压成『装在项目里的包』"
moon package > "$BASE/pkg.log" 2>&1 || { echo "✗ moon package 失败"; tail -5 "$BASE/pkg.log"; exit 1; }
ZIP=$(grep -oE "Package to .*\.zip" "$BASE/pkg.log" | tail -1 | sed 's/Package to //' | tr -d '\r')
[ -f "$ZIP" ] || { echo "✗ 找不到 zip：$ZIP"; exit 1; }
unzip -q "$ZIP" -d "$PKG" || { echo "✗ 解压失败"; exit 1; }
[ -f "$PKG/launcher/skillpress.mjs" ] &&
  ok "包里有启动器（$(cd "$PKG" && ls | wc -l | tr -d ' ') 个顶层条目）" ||
  bad "包里没有 launcher/skillpress.mjs —— 拿到包的人没有入口"

echo "② 前置断言：此刻**解析不到** web-tree-sitter（否则这轮读数不算数）"
if (cd "$BASE/proj" && node -e 'import("web-tree-sitter").then(() => process.exit(1)).catch(() => process.exit(0))'); then
  ok "干净：$BASE/proj 往上找不到 web-tree-sitter"
else
  bad "消费者目录里已能解析到 web-tree-sitter ⇒『没装依赖』这句话证不了（别把这一轮当证据）"
fi

echo "③ 编一次 CLI（\`moon -C <包>\`，不 cd）"
moon -C "$PKG" build cmd/skillpress --target js > "$BASE/build.log" 2>&1 &&
  ok "包自己编得过（消费者不需要它的源码，只要这份产物）" ||
  { bad "编不过"; tail -5 "$BASE/build.log" | sed 's/^/      /'; }

# ── 夹具：两份 skill + 一个首页源 ────────────────────────────────────────────────
FIX="$BASE/corpus"
mkdir -p "$FIX/alpha" "$FIX/skillpress"
printf -- '---\nname: alpha\ndescription: 夹具里的 alpha\nwhenToUse: 测试\n---\n\n# alpha\n\n## 一栏\n\n正文，带一个代码块：\n\n```bash\nls -la\n```\n' > "$FIX/alpha/SKILL.md"
printf -- '---\nname: skillpress\ndescription: 首页那份\nwhenToUse: 测试\n---\n\n# 站名\n\n引言。\n\n## 一栏\n\n正文。\n' > "$FIX/skillpress/SKILL.md"

echo "④ 没装 npm 依赖时：\`check\` 必须能跑（门不碰高亮）"
node "$PKG/launcher/skillpress.mjs" check --repo "$BASE/proj" --skills "$FIX" > "$BASE/check1.txt" 2>&1
r1=$?
if [ "$r1" = 0 ] && grep -q '全部通过（2 个 skill）' "$BASE/check1.txt"; then
  ok "check 在没有 web-tree-sitter 时照样全过（退出码 0）"
else
  bad "check 退出码 $r1 —— 门不该依赖高亮那边的东西"
  tail -4 "$BASE/check1.txt" | sed 's/^/      /'
fi

echo "⑤ 没装 npm 依赖时：\`gen-file\` 必须**说清缺什么**并退 2（不是崩栈、更不是吐半份产物）"
node "$PKG/launcher/skillpress.mjs" gen-file "$FIX" > "$BASE/gen1.txt" 2> "$BASE/gen1.err"
r2=$?
[ "$r2" = 2 ] && grep -q 'npm i web-tree-sitter' "$BASE/gen1.err" && [ ! -s "$BASE/gen1.txt" ] &&
  ok "缺依赖时：退 2 + 指名要装什么 + stdout 空" ||
  { bad "缺依赖时表现不对（退出码 $r2）"; head -3 "$BASE/gen1.err" | sed 's/^/      /'; }

echo "⑥ 装上那唯一的依赖（装在**项目根**：Node 从包里往上一层层找得到）"
( cd "$BASE/proj" && npm i --silent --no-audit --no-fund web-tree-sitter > "$BASE/npm.log" 2>&1 ) &&
  ok "npm i web-tree-sitter 完成" || { bad "npm i 失败"; tail -3 "$BASE/npm.log" | sed 's/^/      /'; }

echo "⑦ \`gen-file\` 在包里跑出的产物 == 本地引擎的产物（逐字节）"
node "$PKG/launcher/skillpress.mjs" gen-file "$FIX" > "$BASE/gen-pkg.mbt" 2> "$BASE/gen-pkg.err"
r3=$?
node tools/run-js.mjs gen-file "$FIX" > "$BASE/gen-local.mbt" 2> /dev/null
r4=$?
if [ "$r3" = 0 ] && [ "$r4" = 0 ] && cmp -s "$BASE/gen-pkg.mbt" "$BASE/gen-local.mbt"; then
  ok "两边的 content.generated.mbt **逐字节一致**（$(wc -l < "$BASE/gen-pkg.mbt" | tr -d ' ') 行）"
else
  bad "包里的产物与本地不一致（rc $r3 / $r4）"
  diff "$BASE/gen-local.mbt" "$BASE/gen-pkg.mbt" | head -6 | sed 's/^/      /'
fi

echo "⑧ 反证：坏内容在包里也必须红"
printf -- '---\nname: alpha\ndescription: 夹具\nwhenToUse: 测试\n---\n\n# alpha\n\n## 一栏\n\n见 `docs/没有这份文档.md`。\n' > "$FIX/alpha/SKILL.md"
node "$PKG/launcher/skillpress.mjs" check --repo "$BASE/proj" --skills "$FIX" > "$BASE/check2.txt" 2>&1
r5=$?
[ "$r5" = 1 ] && grep -q 'G3 路径不存在：docs/没有这份文档.md' "$BASE/check2.txt" &&
  ok "死路径被门点名、退出码 1" || bad "坏内容没被门抓住（退出码 $r5）"
printf -- '---\nname: alpha\ndescription: 夹具\nwhenToUse: 测试\n---\n\n# alpha\n\n## 一栏\n\n![图](x.png)\n' > "$FIX/alpha/SKILL.md"
node "$PKG/launcher/skillpress.mjs" gen-file "$FIX" > "$BASE/gen2.txt" 2> "$BASE/gen2.err"
r6=$?
[ "$r6" = 2 ] && [ ! -s "$BASE/gen2.txt" ] && grep -q '不支持的构造（图片）' "$BASE/gen2.err" &&
  ok "认不出的构造：退 2 + 点名 + 不吐产物（不许把坏产物落盘）" ||
  { bad "坏内容时表现不对（退出码 $r6）"; head -3 "$BASE/gen2.err" | sed 's/^/      /'; }

echo
if [ "$fail" = 0 ]; then
  echo "✓ 消费者视角全过：包里那份**自己就能编、就能跑 check 与 gen-file**，产物与本地引擎逐字节一致"
else
  echo "✗ 消费者视角有红 —— 上面每一条都是「拿到包的人」会撞到的第一面墙"
  exit 1
fi
