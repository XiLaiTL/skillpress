#!/usr/bin/env bash
# consumer-check.sh —— **消费者视角**：从 `moon package` 打出来的 **zip** 出发，走一遍"拿到包的人"要做的两步
# （解压成项目里的包 / 编一次 CLI），然后用**包里的启动器**跑 `check` 与 `gen-file`。
#
#   bash tools/consumer-check.sh          # 不需要 SKILLPRESS_CORPUS：它自带夹具
#
# ── 为什么必须有它（R6 的尾巴 + 发布清单第 7 条的预演）────────────────────────────
# "本地工作区形态能跑"**不构成证据**：工作区里有 `tools/`、有 `node_modules`、有 `_build`，
# 而包里一样都没有（`.moonignore` 钉着）。这个仓库里"发布包 ≠ 工作区"是有前科的。
# 所以这里只用 **zip 里的东西**，而且**一个 npm 依赖都不装**：
#
#   · 先证明 `check` 在没有 node_modules 的干净目录里能跑（门与高亮没有任何依赖关系）；
#   · 再证明 `gen-file` 也能跑 —— **运行时（`vendor/web-tree-sitter`）随包发**，这就是"0 npm"的判据；
#   · 包里的产物与**本地引擎**在同一份夹具上**逐字节一致**（两边都没有 npm）；
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

echo "④ 拿到包的人**第一次**跑门：如实告诉他「还没有你的锁」（而不是偷偷用开发者本机的锁）"
# ⚠️ 这一条是修完"程序根默认"之后才看得见的真实体验：消费者刚拿到包时**没有**属于自己的
#    `skills.lock.json`（锁里记的是**内容根**的指纹，因人而异）⇒ 门应当退 1 并说清怎么落锁。
#    （第一版判据在这里"过"了，是因为它偷偷用了**开发者本机那份程序根**的锁 —— 测试自己被环境
#     喂饱了。修完默认值它就红给你看，这才是对的读数。）
node "$PKG/launcher/skillpress.mjs" check --repo "$BASE/proj" --skills "$FIX" --program "$BASE/proj" \
  > "$BASE/check0.txt" 2>&1
r0=$?
if [ "$r0" = 1 ] && grep -q 'G8 没有 skills.lock.json' "$BASE/check0.txt"; then
  ok "没锁时退 1 并指名怎么落锁（消费者第一次跑的真实读数）"
else
  bad "没锁时的表现不对（退出码 $r0）—— 它要么静默放过，要么说得不清"
  tail -4 "$BASE/check0.txt" | sed 's/^/      /'
fi

echo "⑤ 落锁（锁落在**消费者自己的目录**里）⇒ 再跑：没装 npm 依赖也必须全过"
node "$PKG/launcher/skillpress.mjs" check --repo "$BASE/proj" --skills "$FIX" --program "$BASE/proj" \
  --update-lock > "$BASE/lock.txt" 2>&1
[ -f "$BASE/proj/skills.lock.json" ] &&
  ok "锁落在消费者的程序根里（$(head -1 "$BASE/lock.txt")）" || bad "锁没落在消费者目录里"
node "$PKG/launcher/skillpress.mjs" check --repo "$BASE/proj" --skills "$FIX" --program "$BASE/proj" \
  > "$BASE/check1.txt" 2>&1
r1=$?
if [ "$r1" = 0 ] && grep -q '全部通过（2 个 skill）' "$BASE/check1.txt"; then
  ok "check 在没有 web-tree-sitter 时照样全过（退出码 0）"
else
  bad "check 退出码 $r1 —— 门不该依赖高亮那边的东西"
  tail -4 "$BASE/check1.txt" | sed 's/^/      /'
fi

echo "⑥ 没装任何 npm 依赖时：\`gen-file\` 也必须**跑通**（运行时随包 vendor，见 vendor/web-tree-sitter）"
# ⚠️ 这一段 2026-10-06 之前是"必须退 2 并指名 npm i web-tree-sitter" —— 那是**当时的**代价。
#    运行时（MIT、两个文件）现在随包发 ⇒ 这条路不再需要 npm。**这条断言就是"0 npm"的判据。**
node "$PKG/launcher/skillpress.mjs" gen-file "$FIX" > "$BASE/gen-pkg.mbt" 2> "$BASE/gen-pkg.err"
r6=$?
if [ "$r6" = 0 ] && [ -s "$BASE/gen-pkg.mbt" ]; then
  ok "没有 npm 依赖也能出产物（$(wc -l < "$BASE/gen-pkg.mbt" | tr -d ' ') 行）"
else
  bad "没有 npm 依赖时 gen-file 跑不通（退出码 $r6）—— 运行时没随包发？"
  head -3 "$BASE/gen-pkg.err" | sed 's/^/      /'
fi

echo "⑦ 包里的产物 == 本地引擎的产物（逐字节；两边都**没有** npm）"
node tools/run-js.mjs gen-file "$FIX" > "$BASE/gen-local.mbt" 2> /dev/null
r7=$?
if [ "$r6" = 0 ] && [ "$r7" = 0 ] && cmp -s "$BASE/gen-pkg.mbt" "$BASE/gen-local.mbt"; then
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
